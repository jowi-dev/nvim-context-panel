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
  
  -- LSP completions (if available)
  if vim.lsp.get_active_clients()[1] then
    local lsp_completions = M.get_lsp_completions(word)
    for _, comp in ipairs(lsp_completions) do
      table.insert(completions, comp)
    end
  end
  
  -- Buffer word completions
  local buffer_completions = M.get_buffer_completions(word)
  for _, comp in ipairs(buffer_completions) do
    table.insert(completions, comp)
  end
  
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

-- Get LSP completions
function M.get_lsp_completions(word)
  local completions = {}
  
  -- This is a simplified version - in a real implementation,
  -- we would make an async LSP request
  -- For now, return empty to focus on the architecture
  
  return completions
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
  
  -- Get current line and cursor position
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local text_before_cursor = line:sub(1, col)
  local text_after_cursor = line:sub(col + 1)
  
  -- Find the word being completed
  local word_start = text_before_cursor:find('[%w_]*$')
  if word_start then
    local prefix = text_before_cursor:sub(1, word_start - 1)
    local new_line = prefix .. completion.label .. text_after_cursor
    
    -- Replace the line
    vim.api.nvim_set_current_line(new_line)
    
    -- Move cursor to end of completion
    local new_col = #prefix + #completion.label
    vim.api.nvim_win_set_cursor(0, {vim.api.nvim_win_get_cursor(0)[1], new_col})
  end
  
  -- Clear completions after selection
  M.clear_completions()
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
function M.show_preview()
  if #state.completions == 0 or state.active_completion_idx == 0 then
    return
  end
  
  local completion = state.completions[state.active_completion_idx]
  if not completion or not completion.detail then
    return
  end
  
  -- Create preview buffer if needed
  if not state.preview_buf or not vim.api.nvim_buf_is_valid(state.preview_buf) then
    state.preview_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.preview_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.preview_buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(state.preview_buf, 'bufhidden', 'wipe')
  end
  
  -- Set preview content
  local lines = vim.split(completion.detail or '', '\n')
  vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, lines)
  
  -- Calculate preview window position (to the left of main panel)
  local main_panel = require('context-panel')
  local panel_config = main_panel.get_panel_config()
  
  if panel_config then
    local preview_width = 60
    local preview_height = math.min(#lines + 2, 10)
    local preview_col = panel_config.col - preview_width - 2
    
    if preview_col >= 0 then
      local win_config = {
        relative = 'editor',
        width = preview_width,
        height = preview_height,
        col = preview_col,
        row = panel_config.row,
        style = 'minimal',
        border = 'rounded',
      }
      
      state.preview_win = vim.api.nvim_open_win(state.preview_buf, false, win_config)
    end
  end
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