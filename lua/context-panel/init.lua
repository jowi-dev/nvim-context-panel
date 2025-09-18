local M = {}

-- Default configuration
local default_config = {
  panel = {
    width = 40,
    position = 'right', -- 'right' or 'left'
    auto_show = true,
  },
  modules = {
    tag_stack = {
      enabled = true,
      height_ratio = 0.6,
      show_line_numbers = true,
      show_arity = true,
      max_stack_depth = 20,
      show_file_path = 'relative', -- 'relative', 'absolute', or 'filename'
      show_module_path = true,
    },
    completions = {
      enabled = true,
      height_ratio = 0.4,
      max_items = 12,
      show_preview = true,
      preview_position = 'left',
      quick_select_keys = '123456789abcdef',
      min_chars = 2,
      auto_preview = false,
      preview_delay = 300,
      sources = {'lsp', 'buffer', 'snippet'},
    }
  }
}

-- Plugin state
local state = {
  config = {},
  panel_win = nil,
  panel_buf = nil,
  is_visible = false,
  update_timer = nil,
  last_update_time = 0,
  modules = {
    tag_stack = nil,
    completion = nil,
  }
}

-- Setup function
function M.setup(opts)
  state.config = vim.tbl_deep_extend('force', default_config, opts or {})
  
  -- Mark setup as called
  vim.g.context_panel_setup_called = true
  
  -- Initialize modules
  if state.config.modules.tag_stack.enabled then
    state.modules.tag_stack = require('context-panel.tag_stack')
    state.modules.tag_stack.setup(state.config.modules.tag_stack)
  end
  
  if state.config.modules.completions.enabled then
    state.modules.completion = require('context-panel.completion')
    state.modules.completion.setup(state.config.modules.completions)
  end
  
  -- Create user commands
  M.create_commands()
  
  -- Set up global autocommands
  local augroup = vim.api.nvim_create_augroup('ContextPanel', { clear = true })
  
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

-- Create user commands
function M.create_commands()
  -- Main panel commands
  vim.api.nvim_create_user_command('ContextPanelToggle', M.toggle, {})
  vim.api.nvim_create_user_command('ContextPanelShow', M.show, {})
  vim.api.nvim_create_user_command('ContextPanelHide', M.hide, {})
  
  -- Module-specific commands
  if state.config.modules.tag_stack.enabled then
    vim.api.nvim_create_user_command('TagStackToggle', function()
      M.toggle_module('tag_stack')
    end, {})
    vim.api.nvim_create_user_command('TagStackClear', M.clear_tag_stack, {})
    vim.api.nvim_create_user_command('TagStackNew', function()
      if state.modules.tag_stack then
        state.modules.tag_stack.new_stack()
        M.request_update()
      end
    end, {})
    vim.api.nvim_create_user_command('TagStackNext', function()
      if state.modules.tag_stack then
        state.modules.tag_stack.next_stack()
        M.request_update()
      end
    end, {})
    vim.api.nvim_create_user_command('TagStackPrev', function()
      if state.modules.tag_stack then
        state.modules.tag_stack.prev_stack()
        M.request_update()
      end
    end, {})
  end
  
  if state.config.modules.completions.enabled then
    vim.api.nvim_create_user_command('CompletionToggle', function()
      M.toggle_module('completion')
    end, {})
    vim.api.nvim_create_user_command('CompletionPreview', function()
      if state.modules.completion then
        state.modules.completion.toggle_preview()
      end
    end, {})
  end
  
  -- Legacy commands for backwards compatibility
  vim.api.nvim_create_user_command('TagStackShow', M.show, {})
  vim.api.nvim_create_user_command('TagStackHide', M.hide, {})
end

-- Show the context panel
function M.show()
  if state.is_visible then
    return
  end
  
  M.create_panel()
  M.update_display()
  state.is_visible = true
end

-- Hide the context panel
function M.hide()
  if not state.is_visible then
    return
  end
  
  if state.panel_win and vim.api.nvim_win_is_valid(state.panel_win) then
    vim.api.nvim_win_close(state.panel_win, true)
  end
  
  -- Also hide any module-specific windows
  if state.modules.completion then
    state.modules.completion.hide_preview()
  end
  
  state.panel_win = nil
  state.is_visible = false
end

-- Toggle the context panel
function M.toggle()
  if state.is_visible then
    M.hide()
  else
    M.show()
  end
end

-- Toggle a specific module
function M.toggle_module(module_name)
  if module_name == 'tag_stack' then
    state.config.modules.tag_stack.enabled = not state.config.modules.tag_stack.enabled
  elseif module_name == 'completion' then
    state.config.modules.completions.enabled = not state.config.modules.completions.enabled
  end
  
  if state.is_visible then
    M.update_display()
  end
end

-- Clear tag stack (legacy function)
function M.clear_tag_stack()
  if state.modules.tag_stack then
    state.modules.tag_stack.clear()
    M.request_update()
  end
end

-- Request display update (called by modules)
function M.request_update()
  M.debounced_update()
end

-- Debounced update function
function M.debounced_update(delay)
  delay = delay or 50 -- Default 50ms delay
  
  -- Cancel existing timer
  if state.update_timer then
    vim.fn.timer_stop(state.update_timer)
  end
  
  -- Schedule new update
  state.update_timer = vim.fn.timer_start(delay, function()
    state.update_timer = nil
    if state.is_visible then
      M.update_display()
    elseif state.config.panel.auto_show and M.should_auto_show() then
      M.show()
    end
  end)
end

-- Check if panel should auto-show
function M.should_auto_show()
  -- Auto-show if tag stack has content
  if state.modules.tag_stack then
    return state.modules.tag_stack.has_tag_stack()
  end
  return false
end

-- Resize panel on window resize
function M.resize_panel()
  if not state.panel_win or not vim.api.nvim_win_is_valid(state.panel_win) then
    return
  end
  
  local config = M.calculate_panel_config()
  vim.api.nvim_win_set_config(state.panel_win, config)
end

-- Calculate panel window configuration
function M.calculate_panel_config()
  local width = state.config.panel.width
  local height = vim.api.nvim_get_option('lines') - vim.api.nvim_get_option('cmdheight') - 2
  local col = state.config.panel.position == 'right' and vim.api.nvim_get_option('columns') - width or 0
  
  return {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = 0,
    style = 'minimal',
    border = 'rounded',
  }
end

-- Get panel config (for modules that need positioning info)
function M.get_panel_config()
  if not state.panel_win or not vim.api.nvim_win_is_valid(state.panel_win) then
    return nil
  end
  
  return vim.api.nvim_win_get_config(state.panel_win)
end

-- Create the side panel
function M.create_panel()
  -- Create buffer if it doesn't exist
  if not state.panel_buf or not vim.api.nvim_buf_is_valid(state.panel_buf) then
    state.panel_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(state.panel_buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(state.panel_buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(state.panel_buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(state.panel_buf, 'filetype', 'context-panel')
    vim.api.nvim_buf_set_name(state.panel_buf, 'Context Panel')
  end
  
  -- Create window
  local win_config = M.calculate_panel_config()
  state.panel_win = vim.api.nvim_open_win(state.panel_buf, false, win_config)
  
  -- Set window options
  vim.api.nvim_win_set_option(state.panel_win, 'wrap', false)
  vim.api.nvim_win_set_option(state.panel_win, 'cursorline', true)
end

-- Update the display with content from all enabled modules
function M.update_display()
  if not state.panel_buf or not vim.api.nvim_buf_is_valid(state.panel_buf) then
    return
  end
  
  local all_lines = {}
  local all_highlights = {}
  local current_line = 0
  
  -- Get enabled modules in display order
  local enabled_modules = M.get_enabled_modules()
  
  if #enabled_modules == 0 then
    all_lines = {"No modules enabled"}
  else
    -- Calculate height ratios
    local total_height = vim.api.nvim_win_get_height(state.panel_win)
    local available_height = total_height - 2 -- Account for borders
    
    for i, module_info in ipairs(enabled_modules) do
      local module_name = module_info.name
      local module = module_info.module
      local config = module_info.config
      
      -- Get module display content
      local lines, highlights = module.format_display(config)
      
      -- Calculate section height
      local section_height = math.floor(available_height * config.height_ratio)
      
      -- Add separator between modules (except for first)
      if i > 1 then
        table.insert(all_lines, "")
        table.insert(all_lines, string.rep("─", state.config.panel.width - 4))
        table.insert(all_lines, "")
        current_line = current_line + 3
      end
      
      -- Add module content
      for _, line in ipairs(lines) do
        table.insert(all_lines, line)
      end
      
      -- Adjust highlight line numbers
      for _, hl in ipairs(highlights) do
        table.insert(all_highlights, {
          group = hl.group,
          line = current_line + hl.line,
          col_start = hl.col_start,
          col_end = hl.col_end
        })
      end
      
      current_line = current_line + #lines
      
      -- Pad or truncate to section height if needed
      while #all_lines - (i == 1 and 0 or 3) < section_height and i < #enabled_modules do
        table.insert(all_lines, "")
        current_line = current_line + 1
      end
    end
  end
  
  -- Update buffer content
  vim.api.nvim_buf_set_option(state.panel_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.panel_buf, 0, -1, false, all_lines)
  vim.api.nvim_buf_set_option(state.panel_buf, 'modifiable', false)
  
  -- Apply syntax highlighting
  M.apply_highlights(all_highlights)
end

-- Get enabled modules in display order
function M.get_enabled_modules()
  local modules = {}
  
  -- Completions first (top of panel)
  if state.config.modules.completions.enabled and state.modules.completion then
    table.insert(modules, {
      name = 'completion',
      module = state.modules.completion,
      config = state.config.modules.completions
    })
  end
  
  -- Tag stack second (bottom of panel)
  if state.config.modules.tag_stack.enabled and state.modules.tag_stack then
    table.insert(modules, {
      name = 'tag_stack',
      module = state.modules.tag_stack,
      config = state.config.modules.tag_stack
    })
  end
  
  return modules
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

-- Legacy function aliases for backwards compatibility
M.clear = M.clear_tag_stack

return M