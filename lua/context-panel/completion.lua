local M = {}

-- Completion module state
local state = {
  completions = {},
  active_completion_idx = 0,
  last_completion_request = 0,
  cached_display = nil,
  preview_win = nil,
  preview_buf = nil,
}

-- Initialize completion module
function M.setup(config)
  -- Set up autocommands for completion events
  local augroup = vim.api.nvim_create_augroup('ContextPanelCompletion', { clear = true })
  
  -- Update completions on insert mode changes
  if config.enabled then
    vim.api.nvim_create_autocmd({'TextChangedI', 'InsertEnter'}, {
      group = augroup,
      callback = function()
        M.update_completions(config)
      end,
    })
    
    vim.api.nvim_create_autocmd({'InsertLeave'}, {
      group = augroup,
      callback = function()
        M.clear_completions()
      end,
    })
  end
  
  -- Set up quick selection keybindings
  if config.enabled then
    M.setup_keybindings(config)
  end
end

-- Set up completion keybindings
function M.setup_keybindings(config)
  local keys = config.quick_select_keys or '123456789abcdef'
  
  for i = 1, #keys do
    local key = keys:sub(i, i)
    local keymap = '<C-' .. key .. '>'
    
    vim.keymap.set('i', keymap, function()
      M.select_completion(i)
    end, { silent = true, desc = 'Select completion ' .. i })
  end
  
  -- Preview toggle
  vim.keymap.set('i', '<C-p>', function()
    M.toggle_preview()
  end, { silent = true, desc = 'Toggle completion preview' })
  
  -- Preview specific completion on Alt+number
  for i = 1, math.min(#keys, 10) do
    local key = keys:sub(i, i)
    local alt_keymap = '<A-' .. key .. '>'
    
    vim.keymap.set('i', alt_keymap, function()
      M.show_preview(i)
    end, { silent = true, desc = 'Preview completion ' .. i })
  end
end

-- Update completions based on current context
function M.update_completions(config)
  local current_time = vim.loop.hrtime()
  
  -- Debounce completion requests
  if current_time - state.last_completion_request < 100000000 then -- 100ms in nanoseconds
    return
  end
  
  state.last_completion_request = current_time
  
  -- Get current cursor position and text
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local text_before_cursor = line:sub(1, col)
  
  -- Extract word being typed
  local word_start = text_before_cursor:find('[%w_]*$')
  local word = word_start and text_before_cursor:sub(word_start) or ""
  
  -- Don't show completions for very short words
  if #word < (config.min_chars or 2) then
    state.completions = {}
    state.cached_display = nil
    require('context-panel').request_update()
    return
  end
  
  -- Collect completions from various sources
  local completions = {}
  local pending_sources = 0
  local completed_sources = 0
  
  -- Function to finalize completions once all sources are done
  local function finalize_completions()
    completed_sources = completed_sources + 1
    if completed_sources >= pending_sources then
      -- Sort completions by source priority (LSP first, then buffer)
      table.sort(completions, function(a, b)
        local priority = { lsp = 1, buffer = 2, snippet = 3, file = 4 }
        local a_pri = priority[a.source] or 99
        local b_pri = priority[b.source] or 99
        
        if a_pri ~= b_pri then
          return a_pri < b_pri
        end
        
        return a.label < b.label
      end)
      
      -- Limit completions to max_items
      local max_items = config.max_items or 12
      if #completions > max_items then
        completions = vim.list_slice(completions, 1, max_items)
      end
      
      state.completions = completions
      state.active_completion_idx = 0
      state.cached_display = nil
      
      -- Notify main panel to update
      require('context-panel').request_update()
    end
  end
  
  -- LSP completions (async)
  if vim.lsp.get_active_clients({ bufnr = 0 })[1] then
    pending_sources = pending_sources + 1
    M.get_lsp_completions(word, function(lsp_completions)
      for _, comp in ipairs(lsp_completions) do
        table.insert(completions, comp)
      end
      finalize_completions()
    end)
  end
  
  -- Snippet completions (sync)
  if vim.tbl_contains(config.sources or {'lsp', 'buffer', 'snippet'}, 'snippet') then
    pending_sources = pending_sources + 1
    local snippet_completions = M.get_snippet_completions(word)
    for _, comp in ipairs(snippet_completions) do
      table.insert(completions, comp)
    end
    finalize_completions()
  end
  
  -- Buffer word completions (sync)
  if vim.tbl_contains(config.sources or {'lsp', 'buffer', 'snippet'}, 'buffer') then
    pending_sources = pending_sources + 1
    local buffer_completions = M.get_buffer_completions(word)
    for _, comp in ipairs(buffer_completions) do
      table.insert(completions, comp)
    end
    finalize_completions()
  end
  
  -- File path completions (sync)
  if vim.tbl_contains(config.sources or {'lsp', 'buffer', 'snippet'}, 'file') then
    pending_sources = pending_sources + 1
    local file_completions = M.get_file_path_completions(word)
    for _, comp in ipairs(file_completions) do
      table.insert(completions, comp)
    end
    finalize_completions()
  end
  
  -- If no sources are pending, finalize immediately
  if pending_sources == 0 then
    state.completions = {}
    state.cached_display = nil
    require('context-panel').request_update()
  end
end

-- Get LSP completions (async)
function M.get_lsp_completions(word, callback)
  local completions = {}
  
  -- Get active LSP clients
  local clients = vim.lsp.get_active_clients({ bufnr = 0 })
  if not clients or #clients == 0 then
    callback(completions)
    return
  end
  
  -- Use the first available client
  local client = clients[1]
  if not client.server_capabilities.completionProvider then
    callback(completions)
    return
  end
  
  -- Get current cursor position
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = pos[1] - 1  -- LSP uses 0-based indexing
  local col = pos[2]
  
  -- Create completion params
  local params = vim.lsp.util.make_position_params(0)
  params.context = {
    triggerKind = 1, -- Invoked
  }
  
  -- Make async LSP request
  client.request('textDocument/completion', params, function(err, result, ctx)
    if err or not result then
      callback(completions)
      return
    end
    
    -- Handle both CompletionList and CompletionItem[] responses
    local items = result.items or result
    if not items then
      callback(completions)
      return
    end
    
    -- Convert LSP completion items to our format
    for _, item in ipairs(items) do
      if item.label and item.label:lower():find(word:lower(), 1, true) then
        local completion = {
          label = item.label,
          kind = M.lsp_kind_to_string(item.kind),
          source = 'lsp',
          detail = item.detail or '',
          documentation = item.documentation,
          insertText = item.insertText or item.label,
          sortText = item.sortText,
          filterText = item.filterText,
          textEdit = item.textEdit,
          additionalTextEdits = item.additionalTextEdits,
        }
        
        table.insert(completions, completion)
      end
    end
    
    -- Sort by LSP's sortText if available, otherwise by label
    table.sort(completions, function(a, b)
      if a.sortText and b.sortText then
        return a.sortText < b.sortText
      end
      return a.label < b.label
    end)
    
    callback(completions)
  end, 0)
end

-- Convert LSP CompletionItemKind to string
function M.lsp_kind_to_string(kind)
  local kinds = {
    [1] = 'Text',
    [2] = 'Method',
    [3] = 'Function',
    [4] = 'Constructor',
    [5] = 'Field',
    [6] = 'Variable',
    [7] = 'Class',
    [8] = 'Interface',
    [9] = 'Module',
    [10] = 'Property',
    [11] = 'Unit',
    [12] = 'Value',
    [13] = 'Enum',
    [14] = 'Keyword',
    [15] = 'Snippet',
    [16] = 'Color',
    [17] = 'File',
    [18] = 'Reference',
    [19] = 'Folder',
    [20] = 'EnumMember',
    [21] = 'Constant',
    [22] = 'Struct',
    [23] = 'Event',
    [24] = 'Operator',
    [25] = 'TypeParameter',
  }
  
  return kinds[kind] or 'Text'
end

-- Get buffer word completions
function M.get_buffer_completions(word)
  local completions = {}
  local seen = {}
  
  -- Get words from all visible buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      for _, line in ipairs(lines) do
        for match_word in line:gmatch('[%w_]+') do
          if match_word:lower():find(word:lower(), 1, true) == 1 and 
             match_word ~= word and 
             #match_word > #word and
             not seen[match_word] then
            seen[match_word] = true
            table.insert(completions, {
              label = match_word,
              kind = 'Text',
              source = 'buffer',
              detail = 'Buffer word'
            })
            
            -- Limit to prevent too many matches
            if #completions >= 20 then
              break
            end
          end
        end
        if #completions >= 20 then
          break
        end
      end
    end
  end
  
  -- Sort by relevance (exact prefix match first, then by length)
  table.sort(completions, function(a, b)
    local a_exact = a.label:lower():find(word:lower()) == 1
    local b_exact = b.label:lower():find(word:lower()) == 1
    
    if a_exact and not b_exact then
      return true
    elseif b_exact and not a_exact then
      return false
    end
    
    return #a.label < #b.label
  end)
  
  return completions
end

-- Get snippet completions
function M.get_snippet_completions(word)
  local completions = {}
  
  -- Common Elixir snippets
  local elixir_snippets = {
    {
      prefix = "def",
      label = "def function",
      body = "def ${1:name} do\n  ${2:# body}\nend",
      description = "Define a function"
    },
    {
      prefix = "defp",
      label = "defp private function",
      body = "defp ${1:name} do\n  ${2:# body}\nend",
      description = "Define a private function"
    },
    {
      prefix = "defmodule",
      label = "defmodule module",
      body = "defmodule ${1:ModuleName} do\n  ${2:# module body}\nend",
      description = "Define a module"
    },
    {
      prefix = "case",
      label = "case statement",
      body = "case ${1:expr} do\n  ${2:pattern} -> ${3:result}\nend",
      description = "Case statement"
    },
    {
      prefix = "with",
      label = "with statement", 
      body = "with ${1:pattern} <- ${2:expr} do\n  ${3:body}\nend",
      description = "With statement"
    },
    {
      prefix = "if",
      label = "if statement",
      body = "if ${1:condition} do\n  ${2:body}\nend",
      description = "If statement"
    },
    {
      prefix = "unless",
      label = "unless statement",
      body = "unless ${1:condition} do\n  ${2:body}\nend",
      description = "Unless statement"
    },
    {
      prefix = "cond",
      label = "cond statement",
      body = "cond do\n  ${1:condition} -> ${2:result}\nend",
      description = "Cond statement"
    },
    {
      prefix = "try",
      label = "try-rescue",
      body = "try do\n  ${1:body}\nrescue\n  ${2:pattern} -> ${3:handler}\nend",
      description = "Try-rescue block"
    },
    {
      prefix = "receive",
      label = "receive block",
      body = "receive do\n  ${1:pattern} -> ${2:handler}\nend",
      description = "Receive block for message passing"
    },
    {
      prefix = "genserver",
      label = "GenServer template",
      body = "use GenServer\n\ndef start_link(opts) do\n  GenServer.start_link(__MODULE__, opts, name: __MODULE__)\nend\n\n@impl true\ndef init(_opts) do\n  {:ok, %{}}\nend\n\n@impl true\ndef handle_call(${1:msg}, _from, state) do\n  {:reply, ${2:reply}, state}\nend",
      description = "GenServer boilerplate"
    }
  }
  
  -- Common programming snippets
  local general_snippets = {
    {
      prefix = "for",
      label = "for comprehension",
      body = "for ${1:item} <- ${2:enumerable} do\n  ${3:body}\nend",
      description = "For comprehension"
    },
    {
      prefix = "fn",
      label = "anonymous function",
      body = "fn ${1:args} -> ${2:body} end",
      description = "Anonymous function"
    },
    {
      prefix = "pipe",
      label = "pipe operator",
      body = "${1:value}\n|> ${2:function}()",
      description = "Pipe operator chain"
    }
  }
  
  -- Combine all snippets
  local all_snippets = {}
  vim.list_extend(all_snippets, elixir_snippets)
  vim.list_extend(all_snippets, general_snippets)
  
  -- Filter snippets by word
  for _, snippet in ipairs(all_snippets) do
    if snippet.prefix:lower():find(word:lower(), 1, true) == 1 then
      table.insert(completions, {
        label = snippet.prefix,
        kind = 'Snippet',
        source = 'snippet',
        detail = snippet.description or 'Snippet',
        insertText = snippet.body,
        documentation = snippet.description
      })
    end
  end
  
  return completions
end

-- Get file path completions
function M.get_file_path_completions(word)
  local completions = {}
  
  -- Only provide file completions if it looks like we're typing a path
  if not word:match('[/\\.]') then
    return completions
  end
  
  -- Get the directory part
  local dir_part = word:match('(.*/)')
  local file_part = word:match('.*/(.*)') or word
  
  -- Default to current directory if no path specified
  local search_dir = dir_part or './'
  
  -- Expand relative paths
  search_dir = vim.fn.expand(search_dir)
  
  -- Try to list directory contents
  local ok, entries = pcall(vim.fn.readdir, search_dir)
  if not ok or not entries then
    return completions
  end
  
  -- Filter entries by file part
  for _, entry in ipairs(entries) do
    if entry:lower():find(file_part:lower(), 1, true) == 1 then
      local full_path = dir_part and (dir_part .. entry) or entry
      local is_dir = vim.fn.isdirectory(search_dir .. '/' .. entry) == 1
      
      table.insert(completions, {
        label = full_path .. (is_dir and '/' or ''),
        kind = is_dir and 'Folder' or 'File',
        source = 'file',
        detail = is_dir and 'Directory' or 'File',
        insertText = full_path .. (is_dir and '/' or '')
      })
      
      -- Limit to prevent too many file completions
      if #completions >= 10 then
        break
      end
    end
  end
  
  -- Sort directories first, then files
  table.sort(completions, function(a, b)
    if a.kind ~= b.kind then
      return a.kind == 'Folder'
    end
    return a.label < b.label
  end)
  
  return completions
end

-- Clear completions
function M.clear_completions()
  state.completions = {}
  state.active_completion_idx = 0
  state.cached_display = nil
  M.hide_preview()
  require('context-panel').request_update()
end

-- Select a completion by index
function M.select_completion(index)
  if index > #state.completions then
    return
  end
  
  local completion = state.completions[index]
  if not completion then
    return
  end
  
  -- Handle LSP textEdit if available
  if completion.textEdit then
    M.apply_text_edit(completion.textEdit)
    
    -- Apply additional text edits if available
    if completion.additionalTextEdits then
      for _, edit in ipairs(completion.additionalTextEdits) do
        M.apply_text_edit(edit)
      end
    end
  else
    -- Fallback to simple text replacement
    M.apply_simple_completion(completion)
  end
  
  -- Clear completions after selection
  M.clear_completions()
end

-- Apply LSP TextEdit
function M.apply_text_edit(text_edit)
  local range = text_edit.range
  local new_text = text_edit.newText
  
  -- Convert LSP range (0-based) to Neovim range (0-based for API)
  local start_line = range.start.line
  local start_col = range.start.character
  local end_line = range['end'].line
  local end_col = range['end'].character
  
  -- Apply the text edit
  vim.api.nvim_buf_set_text(0, start_line, start_col, end_line, end_col, vim.split(new_text, '\n'))
  
  -- Position cursor at end of new text
  local lines = vim.split(new_text, '\n')
  if #lines == 1 then
    vim.api.nvim_win_set_cursor(0, {start_line + 1, start_col + #new_text})
  else
    vim.api.nvim_win_set_cursor(0, {start_line + #lines, #lines[#lines]})
  end
end

-- Apply simple completion (fallback)
function M.apply_simple_completion(completion)
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local text_before_cursor = line:sub(1, col)
  local text_after_cursor = line:sub(col + 1)
  
  -- Find the word being completed
  local word_start = text_before_cursor:find('[%w_]*$')
  if word_start then
    local prefix = text_before_cursor:sub(1, word_start - 1)
    local insert_text = completion.insertText or completion.label
    
    -- Handle snippet expansion for snippet completions
    if completion.kind == 'Snippet' then
      M.expand_snippet(prefix, insert_text, text_after_cursor)
    else
      local new_line = prefix .. insert_text .. text_after_cursor
      
      -- Replace the line
      vim.api.nvim_set_current_line(new_line)
      
      -- Move cursor to end of completion
      local new_col = #prefix + #insert_text
      vim.api.nvim_win_set_cursor(0, {vim.api.nvim_win_get_cursor(0)[1], new_col})
    end
  end
end

-- Expand snippet with basic placeholder support
function M.expand_snippet(prefix, snippet_text, suffix)
  -- Simple snippet expansion - replace placeholders with default values
  local expanded = snippet_text
  
  -- Replace ${n:default} with default value
  expanded = expanded:gsub('%${%d+:([^}]*)}', '%1')
  
  -- Replace ${n} with empty string (simple tabstops)
  expanded = expanded:gsub('%${%d+}', '')
  
  -- Split into lines
  local lines = vim.split(expanded, '\n')
  
  -- Get current position
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  
  if #lines == 1 then
    -- Single line snippet
    local new_line = prefix .. lines[1] .. suffix
    vim.api.nvim_set_current_line(new_line)
    
    -- Position cursor at end of snippet
    vim.api.nvim_win_set_cursor(0, {current_line, #prefix + #lines[1]})
  else
    -- Multi-line snippet
    -- Replace current line with first line of snippet
    lines[1] = prefix .. lines[1]
    lines[#lines] = lines[#lines] .. suffix
    
    -- Replace current line and insert additional lines
    vim.api.nvim_buf_set_lines(0, current_line - 1, current_line, false, lines)
    
    -- Position cursor at end of snippet
    local final_line = current_line + #lines - 1
    local final_col = #lines[#lines] - #suffix
    vim.api.nvim_win_set_cursor(0, {final_line, final_col})
  end
end

-- Toggle preview window
function M.toggle_preview()
  if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
    M.hide_preview()
  else
    M.show_preview()
  end
end

-- Show preview window
function M.show_preview(completion_index)
  -- Use provided index or find first completion with documentation
  local completion = nil
  if completion_index then
    completion = state.completions[completion_index]
  else
    -- Find first completion with documentation
    for i, comp in ipairs(state.completions) do
      if comp.detail or comp.documentation then
        completion = comp
        state.active_completion_idx = i
        break
      end
    end
  end
  
  if not completion then
    return
  end
  
  -- Create preview buffer if needed
  if not state.preview_buf or not vim.api.nvim_buf_is_valid(state.preview_buf) then
    state.preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.preview_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.preview_buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(state.preview_buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(state.preview_buf, 'filetype', 'markdown')
  end
  
  -- Build preview content
  local content = M.build_preview_content(completion)
  if not content or #content == 0 then
    return
  end
  
  -- Set preview content
  vim.api.nvim_buf_set_option(state.preview_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, content)
  vim.api.nvim_buf_set_option(state.preview_buf, 'modifiable', false)
  
  -- Calculate preview window position (to the left of main panel)
  local main_panel = require('context-panel')
  local panel_config = main_panel.get_panel_config()
  
  if panel_config then
    local preview_width = math.min(80, math.max(40, panel_config.col - 5))
    local preview_height = math.min(20, math.max(5, #content + 2))
    local preview_col = math.max(0, panel_config.col - preview_width - 2)
    
    -- Adjust row to align with completions section
    local preview_row = panel_config.row
    
    local win_config = {
      relative = 'editor',
      width = preview_width,
      height = preview_height,
      col = preview_col,
      row = preview_row,
      style = 'minimal',
      border = 'rounded',
      title = completion.label .. ' [' .. completion.source .. ']',
      title_pos = 'center',
    }
    
    if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
      vim.api.nvim_win_set_config(state.preview_win, win_config)
    else
      state.preview_win = vim.api.nvim_open_win(state.preview_buf, false, win_config)
      
      -- Set window options
      vim.api.nvim_win_set_option(state.preview_win, 'wrap', true)
      vim.api.nvim_win_set_option(state.preview_win, 'cursorline', false)
    end
  end
end

-- Build preview content from completion
function M.build_preview_content(completion)
  local lines = {}
  
  -- Add completion label and kind
  table.insert(lines, "## " .. completion.label)
  table.insert(lines, "*" .. completion.kind .. "* from " .. completion.source)
  table.insert(lines, "")
  
  -- Add detail if available
  if completion.detail and completion.detail ~= "" then
    table.insert(lines, "**Details:**")
    local detail_lines = vim.split(completion.detail, '\n')
    for _, line in ipairs(detail_lines) do
      table.insert(lines, line)
    end
    table.insert(lines, "")
  end
  
  -- Add documentation if available
  local doc = completion.documentation
  if doc then
    -- Handle different documentation formats
    local doc_text = ""
    if type(doc) == "string" then
      doc_text = doc
    elseif type(doc) == "table" then
      if doc.kind == "markdown" then
        doc_text = doc.value or ""
      else
        doc_text = doc.value or tostring(doc)
      end
    end
    
    if doc_text ~= "" then
      table.insert(lines, "**Documentation:**")
      local doc_lines = vim.split(doc_text, '\n')
      for _, line in ipairs(doc_lines) do
        table.insert(lines, line)
      end
      table.insert(lines, "")
    end
  end
  
  -- Add insertText preview for snippets
  if completion.kind == 'Snippet' and completion.insertText then
    table.insert(lines, "**Preview:**")
    table.insert(lines, "```" .. (vim.bo.filetype or ""))
    local snippet_lines = vim.split(completion.insertText, '\n')
    for _, line in ipairs(snippet_lines) do
      table.insert(lines, line)
    end
    table.insert(lines, "```")
  end
  
  return lines
end

-- Hide preview window
function M.hide_preview()
  if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
    vim.api.nvim_win_close(state.preview_win, true)
  end
  state.preview_win = nil
end

-- Format completion display
function M.format_display(config)
  if state.cached_display then
    return state.cached_display.lines, state.cached_display.highlights
  end
  
  local lines = {}
  local highlights = {}
  local line_num = 0
  
  -- Header
  table.insert(lines, "🔍 Completions:")
  line_num = line_num + 1
  
  if #state.completions == 0 then
    table.insert(lines, "  (type to see completions)")
    state.cached_display = { lines = lines, highlights = highlights }
    return lines, highlights
  end
  
  -- Show completions with quick select keys
  local keys = config.quick_select_keys or '123456789abcdef'
  
  for i, completion in ipairs(state.completions) do
    if i > #keys then
      break
    end
    
    local key = keys:sub(i, i)
    local kind_icon = M.get_completion_kind_icon(completion.kind)
    local line = string.format("  %s. %s %s", key, kind_icon, completion.label)
    
    -- Add source info if available
    if completion.source then
      line = line .. " [" .. completion.source .. "]"
    end
    
    table.insert(lines, line)
    
    -- Highlight the key
    table.insert(highlights, {
      group = 'Number',
      line = line_num,
      col_start = 2,
      col_end = 4
    })
    
    -- Highlight the completion text
    table.insert(highlights, {
      group = 'Function',
      line = line_num,
      col_start = 6 + #kind_icon,
      col_end = 6 + #kind_icon + #completion.label
    })
    
    line_num = line_num + 1
  end
  
  -- Add help text
  table.insert(lines, "")
  table.insert(lines, "  Press Ctrl+key to select")
  line_num = line_num + 2
  
  -- Cache the formatted display
  state.cached_display = { lines = lines, highlights = highlights }
  return lines, highlights
end

-- Get icon for completion kind
function M.get_completion_kind_icon(kind)
  local icons = {
    Text = "📝",
    Method = "🔧",
    Function = "⚡",
    Constructor = "🏗️",
    Field = "🔗",
    Variable = "📦",
    Class = "🏛️",
    Interface = "🔌",
    Module = "📚",
    Property = "🎛️",
    Unit = "📏",
    Value = "💎",
    Enum = "📋",
    Keyword = "🔑",
    Snippet = "✂️",
    Color = "🎨",
    File = "📄",
    Reference = "🔗",
    Folder = "📁",
    EnumMember = "📋",
    Constant = "🔒",
    Struct = "🏗️",
    Event = "⚡",
    Operator = "⚖️",
    TypeParameter = "🏷️",
  }
  
  return icons[kind] or "❓"
end

return M