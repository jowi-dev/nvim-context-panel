local M = {}

-- Default configuration
local default_config = {
  width = 40,
  position = 'right', -- 'right' or 'left'
  auto_show = true,
  show_line_numbers = true,
  show_file_path = 'relative', -- 'relative', 'absolute', or 'filename'
  max_stack_depth = 20,
  show_arity = true,
  show_module_path = true,
}

-- Plugin state
local state = {
  config = {},
  panel_win = nil,
  panel_buf = nil,
  is_visible = false,
  stacks = {}, -- Multiple named stacks: { stack_id = { name, items, current_idx } }
  active_stack_id = nil,
  next_stack_id = 1,
}

-- Setup function
function M.setup(opts)
  state.config = vim.tbl_deep_extend('force', default_config, opts or {})
  
  -- Create user commands
  vim.api.nvim_create_user_command('TagStackShow', M.show, {})
  vim.api.nvim_create_user_command('TagStackHide', M.hide, {})
  vim.api.nvim_create_user_command('TagStackToggle', M.toggle, {})
  vim.api.nvim_create_user_command('TagStackClear', M.clear, {})
  vim.api.nvim_create_user_command('TagStackNew', M.new_stack, {})
  vim.api.nvim_create_user_command('TagStackNext', M.next_stack, {})
  vim.api.nvim_create_user_command('TagStackPrev', M.prev_stack, {})
  
  -- Set up autocommands for tag navigation events
  local augroup = vim.api.nvim_create_augroup('TagStack', { clear = true })
  
  -- Handle initial file opening to create root stack
  vim.api.nvim_create_autocmd({'VimEnter', 'BufReadPost'}, {
    group = augroup,
    callback = function()
      -- Only create initial stack if we don't have one and the buffer has a real file
      local bufname = vim.api.nvim_buf_get_name(0)
      if not state.active_stack_id and bufname and bufname ~= "" and vim.fn.filereadable(bufname) == 1 then
        M.new_stack()
        if state.config.auto_show then
          M.show()
        end
      end
    end,
  })
  
  -- Listen for tag jumps and updates
  vim.api.nvim_create_autocmd({'BufEnter', 'CursorHold'}, {
    group = augroup,
    callback = function()
      M.detect_stack_changes()
      if state.is_visible then
        M.update_display()
      elseif state.config.auto_show and (M.has_tag_stack() or state.active_stack_id) then
        M.show()
      end
    end,
  })
  
  -- Update on window resize
  vim.api.nvim_create_autocmd('VimResized', {
    group = augroup,
    callback = function()
      if state.is_visible then
        M.resize_panel()
      end
    end,
  })
end

-- Show the tag stack panel
function M.show()
  if state.is_visible then
    return
  end
  
  M.create_panel()
  M.update_display()
  state.is_visible = true
end

-- Hide the tag stack panel
function M.hide()
  if not state.is_visible then
    return
  end
  
  if state.panel_win and vim.api.nvim_win_is_valid(state.panel_win) then
    vim.api.nvim_win_close(state.panel_win, true)
  end
  
  state.panel_win = nil
  state.is_visible = false
end

-- Toggle the tag stack panel
function M.toggle()
  if state.is_visible then
    M.hide()
  else
    M.show()
  end
end

-- Clear the current tag stack
function M.clear()
  if state.active_stack_id then
    state.stacks[state.active_stack_id] = nil
    state.active_stack_id = nil
  end
  -- Clear Neovim's tag stack
  vim.fn.settagstack(vim.fn.winnr(), {items = {}, curidx = 1})
  if state.is_visible then
    M.update_display()
  end
end

-- Create a new tag stack
function M.new_stack()
  local stack_id = "stack_" .. state.next_stack_id
  state.next_stack_id = state.next_stack_id + 1
  
  local current_file = vim.api.nvim_buf_get_name(0)
  local root_name = vim.fn.fnamemodify(current_file, ':t:r') or "Stack " .. state.next_stack_id
  
  state.stacks[stack_id] = {
    name = root_name,
    items = {},
    root_file = current_file,
    root_line = vim.api.nvim_win_get_cursor(0)[1],
  }
  
  state.active_stack_id = stack_id
  
  if state.is_visible then
    M.update_display()
  end
end

-- Switch to next stack
function M.next_stack()
  local stack_ids = vim.tbl_keys(state.stacks)
  if #stack_ids <= 1 then return end
  
  local current_idx = 1
  for i, id in ipairs(stack_ids) do
    if id == state.active_stack_id then
      current_idx = i
      break
    end
  end
  
  local next_idx = (current_idx % #stack_ids) + 1
  state.active_stack_id = stack_ids[next_idx]
  
  if state.is_visible then
    M.update_display()
  end
end

-- Switch to previous stack
function M.prev_stack()
  local stack_ids = vim.tbl_keys(state.stacks)
  if #stack_ids <= 1 then return end
  
  local current_idx = 1
  for i, id in ipairs(stack_ids) do
    if id == state.active_stack_id then
      current_idx = i
      break
    end
  end
  
  local prev_idx = current_idx == 1 and #stack_ids or current_idx - 1
  state.active_stack_id = stack_ids[prev_idx]
  
  if state.is_visible then
    M.update_display()
  end
end

-- Detect changes in tag stack and manage multiple stacks
function M.detect_stack_changes()
  local current_tag_stack = vim.fn.gettagstack()
  
  -- If no active stack, create one
  if not state.active_stack_id then
    M.new_stack()
    return
  end
  
  local active_stack = state.stacks[state.active_stack_id]
  if not active_stack then
    M.new_stack()
    return
  end
  
  -- Check if we've returned to root and then jumped to a new path
  if current_tag_stack.curidx == 0 or #current_tag_stack.items == 0 then
    -- Back at root - check if we should start a new stack on next jump
    active_stack.at_root = true
  elseif active_stack.at_root and current_tag_stack.curidx > 0 then
    -- We were at root and now have jumped - this might be a new path
    local current_item = current_tag_stack.items[current_tag_stack.curidx]
    local last_known = active_stack.items[1]
    
    if last_known and current_item and 
       (current_item.tagname ~= last_known.tagname or 
        current_item.from[1] ~= last_known.from[1]) then
      -- Different path - create new stack
      M.new_stack()
      return
    end
    active_stack.at_root = false
  end
  
  -- Update current stack with tag stack data
  active_stack.items = current_tag_stack.items or {}
  active_stack.current_idx = current_tag_stack.curidx or 0
end

-- Check if there's a meaningful tag stack
function M.has_tag_stack()
  local tag_stack = vim.fn.gettagstack()
  return tag_stack and tag_stack.items and #tag_stack.items > 0
end

-- Resize panel on window resize
function M.resize_panel()
  if not state.panel_win or not vim.api.nvim_win_is_valid(state.panel_win) then
    return
  end
  
  local height = vim.api.nvim_get_option('lines') - vim.api.nvim_get_option('cmdheight') - 2
  local col = state.config.position == 'right' and vim.api.nvim_get_option('columns') - state.config.width or 0
  
  vim.api.nvim_win_set_config(state.panel_win, {
    relative = 'editor',
    width = state.config.width,
    height = height,
    col = col,
    row = 0,
  })
end

-- Create the side panel
function M.create_panel()
  -- Create buffer if it doesn't exist
  if not state.panel_buf or not vim.api.nvim_buf_is_valid(state.panel_buf) then
    state.panel_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.panel_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.panel_buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(state.panel_buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(state.panel_buf, 'filetype', 'tagstack')
    vim.api.nvim_buf_set_name(state.panel_buf, 'Tag Stack')
  end
  
  -- Calculate window position and size
  local width = state.config.width
  local height = vim.api.nvim_get_option('lines') - vim.api.nvim_get_option('cmdheight') - 2
  local col = state.config.position == 'right' and vim.api.nvim_get_option('columns') - width or 0
  
  -- Create window
  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = 0,
    style = 'minimal',
    border = 'rounded',
  }
  
  state.panel_win = vim.api.nvim_open_win(state.panel_buf, false, win_config)
  
  -- Set window options
  vim.api.nvim_win_set_option(state.panel_win, 'wrap', false)
  vim.api.nvim_win_set_option(state.panel_win, 'cursorline', true)
end

-- Update the display with current tag stack
function M.update_display()
  if not state.panel_buf or not vim.api.nvim_buf_is_valid(state.panel_buf) then
    return
  end
  
  local lines, highlights = M.format_all_stacks()
  
  -- Update buffer content
  vim.api.nvim_buf_set_option(state.panel_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.panel_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.panel_buf, 'modifiable', false)
  
  -- Apply syntax highlighting
  M.apply_highlights(highlights)
end

-- Apply syntax highlighting
function M.apply_highlights(highlights)
  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(state.panel_buf, 0, 0, -1)
  
  -- Apply new highlights
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(state.panel_buf, 0, hl.group, hl.line, hl.col_start, hl.col_end)
  end
end

-- Format all stacks for display
function M.format_all_stacks()
  local lines = {}
  local highlights = {}
  local line_num = 0
  
  -- Header
  table.insert(lines, "📁 Tag Stacks:")
  line_num = line_num + 1
  
  if vim.tbl_isempty(state.stacks) then
    table.insert(lines, "  (no stacks)")
    return lines, highlights
  end
  
  local stack_count = vim.tbl_count(state.stacks)
  if stack_count > 1 then
    table.insert(lines, string.format("  (%d stacks - use :TagStackNext/:TagStackPrev)", stack_count))
    line_num = line_num + 1
  end
  
  -- Show each stack
  for stack_id, stack in pairs(state.stacks) do
    local is_active = (stack_id == state.active_stack_id)
    
    -- Stack header
    local header = string.format("%s %s", is_active and "▶" or " ", stack.name)
    table.insert(lines, header)
    
    if is_active then
      table.insert(highlights, {
        group = 'String',  -- Green-ish color
        line = line_num,
        col_start = 0,
        col_end = #header
      })
    end
    line_num = line_num + 1
    
    -- Show root - get module name from file
    local root_module = M.extract_module_from_file(stack.root_file)
    local root_line = string.format("  %s (root)", root_module)
    table.insert(lines, root_line)
    line_num = line_num + 1
    
    -- Show stack items
    local items_to_show = math.min(#stack.items, stack.current_idx or 0)
    for i = 1, items_to_show do
      if i > state.config.max_stack_depth then
        table.insert(lines, "  ... (truncated)")
        line_num = line_num + 1
        break
      end
      
      local item = stack.items[i]
      local is_current = is_active and (i == stack.current_idx)
      
      -- Get tag info
      local tag_name = item.tagname or ""
      
      -- Add down arrow
      table.insert(lines, "  ↓")
      line_num = line_num + 1
      
      -- Extract module and function from tag
      local display_name = M.format_elixir_tag_display(tag_name, item)
      
      local line = "  " .. display_name
      
      if is_current then
        line = line .. " ← [current]"
        -- Highlight current item in green
        table.insert(highlights, {
          group = 'String',
          line = line_num,
          col_start = 0,
          col_end = #line
        })
      end
      
      table.insert(lines, line)
      line_num = line_num + 1
    end
    
    -- Add separator between stacks
    if stack_count > 1 then
      table.insert(lines, "")
      line_num = line_num + 1
    end
  end
  
  return lines, highlights
end

-- Format filename according to config
function M.format_filename(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  return M.format_filename_from_path(filepath)
end

-- Format filename from path according to config
function M.format_filename_from_path(filepath)
  if not filepath or filepath == "" then
    return "untitled"
  end
  
  if state.config.show_file_path == 'filename' then
    return vim.fn.fnamemodify(filepath, ':t')
  elseif state.config.show_file_path == 'absolute' then
    return filepath
  else -- 'relative'
    return vim.fn.fnamemodify(filepath, ':~:.')
  end
end

-- Extract module name from Elixir file path
function M.extract_module_from_file(filepath)
  if not filepath or filepath == "" then
    return "Unknown"
  end
  
  local filename = vim.fn.fnamemodify(filepath, ':t:r') -- Get filename without extension
  
  -- Convert snake_case to PascalCase for module name
  local module_name = filename:gsub("_(%w)", function(letter)
    return letter:upper()
  end)
  
  -- Capitalize first letter
  module_name = module_name:sub(1, 1):upper() .. module_name:sub(2)
  
  -- Handle common Elixir file patterns
  if module_name:match("Test$") then
    return module_name
  end
  
  return module_name
end

-- Format tag display as Module.function/arity
function M.format_elixir_tag_display(tag_name, item)
  if not tag_name or tag_name == "" then
    return "Unknown"
  end
  
  -- If tag already looks like Module.function/arity, use it
  if tag_name:match("^[A-Z][%w%.]*%.[%w_]+/?%d*$") then
    return tag_name
  end
  
  -- Try to extract module from the file we're jumping to
  local target_file = ""
  if item.from and #item.from >= 1 then
    target_file = vim.api.nvim_buf_get_name(item.from[1])
  end
  
  local module_name = M.extract_module_from_file(target_file)
  
  -- Handle function definitions with arity (e.g., handle_call/3)
  local func_name, arity = tag_name:match("^([%w_]+)/(%d+)$")
  if func_name and arity then
    return string.format("%s.%s/%s", module_name, func_name, arity)
  end
  
  -- Handle function definitions without arity
  if tag_name:match("^[%w_]+$") then
    return string.format("%s.%s", module_name, tag_name)
  end
  
  -- Handle already module-qualified names (e.g., MyApp.Server)
  if tag_name:match("^[A-Z][%w%.]*$") then
    return tag_name
  end
  
  -- Default: combine module and tag
  return string.format("%s.%s", module_name, tag_name)
end

-- Format Elixir symbols with arity if applicable (legacy function)
function M.format_elixir_symbol(symbol)
  if not symbol or symbol == "" then
    return ""
  end
  
  return symbol
end

return M