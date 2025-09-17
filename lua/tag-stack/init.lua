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
  tag_stack = {},
}

-- Setup function
function M.setup(opts)
  state.config = vim.tbl_deep_extend('force', default_config, opts or {})
  
  -- Create user commands
  vim.api.nvim_create_user_command('TagStackShow', M.show, {})
  vim.api.nvim_create_user_command('TagStackHide', M.hide, {})
  vim.api.nvim_create_user_command('TagStackToggle', M.toggle, {})
  vim.api.nvim_create_user_command('TagStackClear', M.clear, {})
  
  -- Set up autocommands for tag navigation events
  local augroup = vim.api.nvim_create_augroup('TagStack', { clear = true })
  
  -- Listen for tag jumps and updates
  vim.api.nvim_create_autocmd({'BufEnter', 'CursorHold'}, {
    group = augroup,
    callback = function()
      if state.is_visible then
        M.update_display()
      elseif state.config.auto_show and M.has_tag_stack() then
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

-- Clear the tag stack
function M.clear()
  -- Clear Neovim's tag stack
  vim.fn.settagstack(vim.fn.winnr(), {items = {}, curidx = 1})
  if state.is_visible then
    M.update_display()
  end
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
  
  -- Get current tag stack
  local tag_stack = vim.fn.gettagstack()
  local lines = M.format_tag_stack(tag_stack)
  
  -- Update buffer content
  vim.api.nvim_buf_set_option(state.panel_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.panel_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.panel_buf, 'modifiable', false)
end

-- Format the tag stack for display
function M.format_tag_stack(tag_stack)
  local lines = { "📁 Tag Stack:" }
  
  if not tag_stack or not tag_stack.items or #tag_stack.items == 0 then
    table.insert(lines, "  (empty)")
    return lines
  end
  
  local current_index = tag_stack.curidx or 1
  local items_to_show = math.min(#tag_stack.items, current_index)
  
  -- Show the root file (current buffer if no tags jumped yet)
  local current_buf = vim.api.nvim_get_current_buf()
  local current_file = M.format_filename(current_buf)
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  
  table.insert(lines, "└─ " .. current_file .. ":" .. current_line .. " (root)")
  
  -- Show each level of the tag stack
  for i = 1, items_to_show do
    if i > state.config.max_stack_depth then
      table.insert(lines, "  ... (truncated)")
      break
    end
    
    local item = tag_stack.items[i]
    local is_current_level = (i == current_index)
    local indent = string.rep("  ", i)
    
    -- Get tag information
    local tag_name = item.tagname or ""
    local from_file = ""
    local from_line = 0
    
    if item.from and #item.from >= 2 then
      from_file = M.format_filename(item.from[1])
      from_line = item.from[2]
    end
    
    -- Build display line
    local line = indent .. "└─ "
    if from_file ~= "" then
      line = line .. from_file
      if state.config.show_line_numbers and from_line > 0 then
        line = line .. ":" .. from_line
      end
    end
    
    if tag_name ~= "" then
      line = line .. " → " .. M.format_elixir_symbol(tag_name)
    end
    
    if is_current_level then
      line = line .. " ← [current]"
    end
    
    table.insert(lines, line)
  end
  
  return lines
end

-- Format filename according to config
function M.format_filename(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  
  if state.config.show_file_path == 'filename' then
    return vim.fn.fnamemodify(filepath, ':t')
  elseif state.config.show_file_path == 'absolute' then
    return filepath
  else -- 'relative'
    return vim.fn.fnamemodify(filepath, ':~:.')
  end
end

-- Format Elixir symbols with arity if applicable
function M.format_elixir_symbol(symbol)
  if not symbol or symbol == "" then
    return ""
  end
  
  -- Handle Elixir module names (e.g., MyApp.Server)
  if symbol:match("^[A-Z][%w%.]*[A-Z][%w]*$") then
    return symbol .. " (module)"
  end
  
  -- Handle function definitions with arity (e.g., handle_call/3)
  local func_name, arity = symbol:match("^([%w_]+)/(%d+)$")
  if func_name and arity then
    return func_name .. "/" .. arity .. " (function)"
  end
  
  -- Handle function definitions without arity
  if symbol:match("^[%w_]+$") then
    -- Try to detect if this might be a function by context
    local current_buf = vim.api.nvim_get_current_buf()
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    local line_content = vim.api.nvim_buf_get_lines(current_buf, current_line - 1, current_line, false)[1]
    
    if line_content and (line_content:match("def%s+" .. symbol) or line_content:match("defp%s+" .. symbol)) then
      return symbol .. " (function)"
    end
    
    return symbol
  end
  
  -- Handle pipe operators and other Elixir constructs
  if symbol:match("|>") then
    return symbol:gsub("|>", "→")
  end
  
  -- Default: return as-is
  return symbol
end

return M