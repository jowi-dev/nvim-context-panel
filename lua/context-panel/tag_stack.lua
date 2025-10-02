local M = {}

-- Tag stack module state
local state = {
  stacks = {}, -- Multiple named stacks: { stack_id = { name, items, current_idx } }
  active_stack_id = nil,
  next_stack_id = 1,
  -- Performance optimization state
  last_tag_stack = nil,
  cached_display = nil,
  -- Debug state
  debug_enabled = false,
  event_log = {},
  last_event_time = 0,
  defer_delay = 50, -- Configurable delay for testing
}

-- Initialize tag stack module
function M.setup(config)
  -- Set up autocommands for tag navigation events
  local augroup = vim.api.nvim_create_augroup('ContextPanelTagStack', { clear = true })
  
  -- Handle initial file opening to create root stack
  vim.api.nvim_create_autocmd({'VimEnter', 'BufReadPost', 'BufEnter'}, {
    group = augroup,
    callback = function()
      -- Create initial stack for any real file
      local bufname = vim.api.nvim_buf_get_name(0)
      if bufname and bufname ~= "" and vim.fn.filereadable(bufname) == 1 then
        -- Create stack if we don't have one, or if we switched to a different file
        if not state.active_stack_id then
          M.new_stack()
          require('context-panel').request_update()
        else
          -- Check if current file is different from active stack root
          local active_stack = state.stacks[state.active_stack_id]
          if active_stack and active_stack.root_file ~= bufname then
            -- Only create new stack if we're not just navigating within existing stack
            local current_tag_stack = vim.fn.gettagstack()
            if current_tag_stack.curidx == 0 or #current_tag_stack.items == 0 then
              M.new_stack()
              require('context-panel').request_update()
            end
          end
        end
      end
    end,
  })
  
--  -- Listen for tag jumps - use comprehensive events that catch tag navigation
--  vim.api.nvim_create_autocmd({'BufEnter', 'WinEnter', 'BufRead', 'TabEnter'}, {
--    group = augroup,
--    callback = function()
--      M.detect_stack_changes()
--    end,
--  })
  
  -- Test what events actually fire during tag navigation (temporary debug)
  vim.api.nvim_create_autocmd({
    'BufEnter', 'WinEnter', 'BufRead', 'TabEnter', 'BufWinEnter',
    'BufLeave', 'WinLeave', 'BufNew', 'BufReadPost', 'User'
  }, {
    group = augroup,
    callback = function(event_data)
      M.log_event(event_data.event)
      -- Defer stack change detection to allow tag stack to update
      vim.defer_fn(function()
        M.detect_stack_changes()
      end, state.defer_delay)
    end,
  })
  
  -- Create debug commands
  vim.api.nvim_create_user_command('TagStackDebugOn', function()
    state.debug_enabled = true
    state.event_log = {}
    print("Tag stack event debugging enabled")
  end, {})
  
  vim.api.nvim_create_user_command('TagStackDebugOff', function()
    state.debug_enabled = false
    print("Tag stack event debugging disabled")
  end, {})
  
  vim.api.nvim_create_user_command('TagStackDebugShow', function()
    if #state.event_log == 0 then
      print("No events logged")
      return
    end
    print("Recent events (last 20):")
    local start_idx = math.max(1, #state.event_log - 19)
    for i = start_idx, #state.event_log do
      local entry = state.event_log[i]
      print(string.format("%d. [+%dms] %s", i, entry.relative_time, entry.event))
    end
  end, {})
  
  vim.api.nvim_create_user_command('TagStackDebugClear', function()
    state.event_log = {}
    print("Event log cleared")
  end, {})
  
  -- Command to switch to minimal event set
  vim.api.nvim_create_user_command('TagStackUseMinimalEvents', function()
    M.setup_minimal_events(augroup)
    print("Switched to minimal event set: BufEnter only")
  end, {})
  
  -- Command to switch to medium event set
  vim.api.nvim_create_user_command('TagStackUseMediumEvents', function()
    M.setup_medium_events(augroup)
    print("Switched to medium event set: BufEnter, WinEnter")
  end, {})
  
  -- Command to adjust defer delay
  vim.api.nvim_create_user_command('TagStackSetDelay', function(opts)
    local delay = tonumber(opts.args)
    if delay and delay >= 0 and delay <= 1000 then
      state.defer_delay = delay
      print("Set defer delay to " .. delay .. "ms")
    else
      print("Usage: TagStackSetDelay <number> (0-1000ms)")
    end
  end, { nargs = 1 })
  
  -- Debug command to show internal stack state
  vim.api.nvim_create_user_command('TagStackShowState', function()
    if not state.active_stack_id then
      print("No active stack")
      return
    end
    local stack = state.stacks[state.active_stack_id]
    if not stack then
      print("Active stack not found")
      return
    end
    print("=== Stack State ===")
    print("Current idx:", stack.current_idx)
    print("Max depth:", stack.max_depth)
    print("Neovim items:", #stack.items)
    print("Display items:", #stack.display_items)
    for i, item in ipairs(stack.display_items) do
      local current_marker = (i == stack.current_idx) and " ← [current]" or ""
      print(string.format("  %d. %s%s", i, item.tagname or "unknown", current_marker))
    end
  end, {})
  
  -- Fallback with shorter delay for any missed updates
--  vim.api.nvim_create_autocmd({'CursorHold'}, {
--    group = augroup,
--    callback = function()
--      M.detect_stack_changes()
--    end,
--  })
end

-- Log event for debugging
function M.log_event(event_name)
  if not state.debug_enabled then
    return
  end
  
  local current_time = vim.fn.reltimefloat(vim.fn.reltime()) * 1000 -- Convert to ms
  local relative_time = 0
  
  if state.last_event_time > 0 then
    relative_time = math.floor(current_time - state.last_event_time)
  end
  
  table.insert(state.event_log, {
    event = event_name,
    relative_time = relative_time,
    timestamp = current_time
  })
  
  state.last_event_time = current_time
  
  -- Keep only last 50 events to prevent memory bloat
  if #state.event_log > 50 then
    table.remove(state.event_log, 1)
  end
end

-- Clear the current tag stack
function M.clear()
  if state.active_stack_id then
    local stack = state.stacks[state.active_stack_id]
    if stack then
      -- Reset the persistent display items
      stack.display_items = {}
      stack.max_depth = 0
    else
      state.stacks[state.active_stack_id] = nil
      state.active_stack_id = nil
    end
  end
  -- Clear Neovim's tag stack
  vim.fn.settagstack(vim.fn.winnr(), {items = {}, curidx = 1})
  -- Clear cache
  state.cached_display = nil
  state.last_tag_stack = nil
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
    display_items = {}, -- Items to display (includes items beyond current position)
    root_file = current_file,
    root_line = vim.api.nvim_win_get_cursor(0)[1],
    max_depth = 0, -- Track maximum depth reached
  }
  
  state.active_stack_id = stack_id
  state.cached_display = nil
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
  state.cached_display = nil
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
  state.cached_display = nil
end

-- Detect changes in tag stack and manage multiple stacks
function M.detect_stack_changes()
  local current_tag_stack = vim.fn.gettagstack()
  
  -- Debug output only when debugging is enabled
  if state.debug_enabled then
    local debug_msg = string.format("DEBUG: detect_stack_changes() - curidx:%d items:%d", 
                                    current_tag_stack.curidx, #current_tag_stack.items)
    if #current_tag_stack.items > 0 then
      debug_msg = debug_msg .. " top:" .. (current_tag_stack.items[#current_tag_stack.items].tagname or "unknown")
    end
    print(debug_msg)
  end
  
  -- Quick comparison with cached state
  if state.last_tag_stack and 
     current_tag_stack.curidx == state.last_tag_stack.curidx and
     #current_tag_stack.items == #state.last_tag_stack.items then
    if #current_tag_stack.items > 0 then
      local first_same = current_tag_stack.items[1] and state.last_tag_stack.items[1] and
                        current_tag_stack.items[1].tagname == state.last_tag_stack.items[1].tagname
      local last_same = true
      if #current_tag_stack.items > 1 then
        local last_idx = #current_tag_stack.items
        last_same = current_tag_stack.items[last_idx] and state.last_tag_stack.items[last_idx] and
                   current_tag_stack.items[last_idx].tagname == state.last_tag_stack.items[last_idx].tagname
      end
      if first_same and last_same then
        return -- No changes detected
      end
    else
      return -- Both empty, no changes
    end
  end
  
  -- Cache current state for next comparison
  state.last_tag_stack = vim.deepcopy(current_tag_stack)
  
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
  
  -- Normalize curidx to handle Vim's 1-based indexing
  local normalized_curidx = math.max(0, (current_tag_stack.curidx or 1) - 1)
  
  -- Check if we've returned to root and then jumped to a new path
  if normalized_curidx == 0 or #current_tag_stack.items == 0 then
    active_stack.at_root = true
  elseif active_stack.at_root and normalized_curidx > 0 then
    local current_item = current_tag_stack.items[normalized_curidx]
    local last_known = active_stack.items[1]
    
    if last_known and current_item and 
       (current_item.tagname ~= last_known.tagname or 
        current_item.from[1] ~= last_known.from[1]) then
      M.new_stack()
      return
    end
    active_stack.at_root = false
  end
  
  -- Update current stack with persistent tag stack logic
  M.update_persistent_stack(active_stack, current_tag_stack.items or {}, normalized_curidx)
  state.cached_display = nil
  
  -- Use lightweight update request with minimal delay for tag navigation
  if state.debug_enabled then
    print("DEBUG: calling debounced_update() at:", vim.fn.reltimestr(vim.fn.reltime()))
  end
  require('context-panel').debounced_update(10) -- 10ms instead of default 50ms
  if state.debug_enabled then
    print("DEBUG: debounced_update() call completed at:", vim.fn.reltimestr(vim.fn.reltime()))
  end
end

-- Format tag stack display
function M.format_display(config)
  if state.cached_display then
    return state.cached_display.lines, state.cached_display.highlights
  end
  
  local lines = {}
  local highlights = {}
  local line_num = 0
  
  -- Header
  table.insert(lines, "📁 Tag Stacks:")
  line_num = line_num + 1
  
  -- Force create a stack if none exists for current file
  if vim.tbl_isempty(state.stacks) then
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname and bufname ~= "" and vim.fn.filereadable(bufname) == 1 then
      M.new_stack()
    end
  end
  
  if vim.tbl_isempty(state.stacks) then
    table.insert(lines, "  (no stacks)")
    state.cached_display = { lines = lines, highlights = highlights }
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
        group = 'String',
        line = line_num,
        col_start = 0,
        col_end = #header
      })
    end
    line_num = line_num + 1
    
    -- Show root
    local root_module = M.extract_module_from_file(stack.root_file)
    local root_line = string.format("  %s (root)", root_module)
    
    local at_root = is_active and (stack.current_idx == 0)
    if at_root then
      root_line = root_line .. " ← [current]"
      table.insert(highlights, {
        group = 'String',
        line = line_num,
        col_start = 0,
        col_end = #root_line
      })
    end
    
    table.insert(lines, root_line)
    line_num = line_num + 1
    
    -- Show stack items (use display_items for persistent view)
    local current_idx = stack.current_idx or 0
    local items_to_show = #stack.display_items
    
    for i = 1, items_to_show do
      if i > config.max_stack_depth then
        table.insert(lines, "  ... (truncated)")
        line_num = line_num + 1
        break
      end
      
      local item = stack.display_items[i]
      local is_current = is_active and (i == current_idx) and (current_idx > 0)
      
      local tag_name = item.tagname or ""
      
      -- Add down arrow
      table.insert(lines, "  ↓")
      line_num = line_num + 1
      
      -- Extract module and function from tag
      local display_name = M.format_elixir_tag_display(tag_name, item)
      
      local line = "  " .. display_name
      
      if is_current then
        line = line .. " ← [current]"
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
    
    if stack_count > 1 then
      table.insert(lines, "")
      line_num = line_num + 1
    end
  end
  
  -- Cache the formatted display
  state.cached_display = { lines = lines, highlights = highlights }
  return lines, highlights
end

-- Extract module name from Elixir file path
function M.extract_module_from_file(filepath)
  if not filepath or filepath == "" then
    return "Unknown"
  end
  
  local filename = vim.fn.fnamemodify(filepath, ':t:r')
  
  -- Convert snake_case to PascalCase for module name
  local module_name = filename:gsub("_(%w)", function(letter)
    return letter:upper()
  end)
  
  -- Capitalize first letter
  module_name = module_name:sub(1, 1):upper() .. module_name:sub(2)
  
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
  
  -- Handle function definitions with arity
  local func_name, arity = tag_name:match("^([%w_]+)/(%d+)$")
  if func_name and arity then
    return string.format("%s.%s/%s", module_name, func_name, arity)
  end
  
  -- Handle function definitions without arity
  if tag_name:match("^[%w_]+$") then
    return string.format("%s.%s", module_name, tag_name)
  end
  
  -- Handle already module-qualified names
  if tag_name:match("^[A-Z][%w%.]*$") then
    return tag_name
  end
  
  -- Default: combine module and tag
  return string.format("%s.%s", module_name, tag_name)
end

-- Update stack with persistent display logic
function M.update_persistent_stack(stack, current_items, current_idx)
  -- Store the current Neovim tag stack state
  stack.items = current_items
  stack.current_idx = current_idx
  
  -- If we're at a deeper level than before, extend display_items
  if current_idx > stack.max_depth then
    -- We've gone deeper - extend display with new items
    for i = stack.max_depth + 1, current_idx do
      if current_items[i] then
        stack.display_items[i] = vim.deepcopy(current_items[i])
      end
    end
    stack.max_depth = current_idx
  elseif current_idx < #stack.display_items then
    -- We've gone back up - check if we're branching in a new direction
    local branching = false
    
    -- Check if the current path differs from our display path
    for i = 1, current_idx do
      if current_items[i] and stack.display_items[i] then
        if current_items[i].tagname ~= stack.display_items[i].tagname then
          branching = true
          break
        end
      elseif current_items[i] or stack.display_items[i] then
        -- One exists, other doesn't - this is a branch
        branching = true
        break
      end
    end
    
    if branching then
      -- We're branching - truncate display_items and replace with current path
      stack.display_items = {}
      for i = 1, current_idx do
        if current_items[i] then
          stack.display_items[i] = vim.deepcopy(current_items[i])
        end
      end
      stack.max_depth = current_idx
    end
    -- If not branching, keep existing display_items (preserve deeper items)
  end
  
  -- Ensure display_items includes at least the current path
  for i = 1, current_idx do
    if current_items[i] and not stack.display_items[i] then
      stack.display_items[i] = vim.deepcopy(current_items[i])
    end
  end
end

-- Check if there's a meaningful tag stack
function M.has_tag_stack()
  local tag_stack = vim.fn.gettagstack()
  return tag_stack and tag_stack.items and #tag_stack.items > 0
end

-- Setup minimal event set for testing
function M.setup_minimal_events(augroup)
  vim.api.nvim_clear_autocmds({ group = augroup })
  
  -- Only BufEnter
  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup,
    callback = function(event_data)
      M.log_event(event_data.event)
      -- Defer stack change detection to allow tag stack to update
      vim.defer_fn(function()
        M.detect_stack_changes()
      end, state.defer_delay)
    end,
  })
end

-- Setup medium event set for testing
function M.setup_medium_events(augroup)
  vim.api.nvim_clear_autocmds({ group = augroup })
  
  -- BufEnter and WinEnter
  vim.api.nvim_create_autocmd({'BufEnter', 'WinEnter'}, {
    group = augroup,
    callback = function(event_data)
      M.log_event(event_data.event)
      -- Defer stack change detection to allow tag stack to update
      vim.defer_fn(function()
        M.detect_stack_changes()
      end, state.defer_delay)
    end,
  })
end

return M
