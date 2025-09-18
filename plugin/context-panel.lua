-- nvim-context-panel: Unified context panel with tag stack and completions
-- Maintainer: Generated Plugin
-- Version: 0.2.0

if vim.g.loaded_context_panel then
  return
end
vim.g.loaded_context_panel = true

-- Initialize the plugin with default keybindings
local function setup_default_keybindings()
  -- Context panel controls
  if not vim.fn.hasmapto('<Plug>ContextPanelToggle', 'n') then
    vim.keymap.set('n', '<space>cp', '<Plug>ContextPanelToggle', { desc = 'Toggle context panel' })
  end
  
  -- Legacy tag stack mappings for backwards compatibility
  if not vim.fn.hasmapto('<Plug>TagStackToggle', 'n') then
    vim.keymap.set('n', '<leader>ts', '<Plug>TagStackToggle', { desc = 'Toggle tag stack panel' })
  end
  
  if not vim.fn.hasmapto('<Plug>TagStackClear', 'n') then
    vim.keymap.set('n', '<leader>tc', '<Plug>TagStackClear', { desc = 'Clear tag stack' })
  end
end

-- Plugin mappings
vim.keymap.set('n', '<Plug>ContextPanelToggle', function()
  require('context-panel').toggle()
end, { silent = true })

vim.keymap.set('n', '<Plug>ContextPanelShow', function()
  require('context-panel').show()
end, { silent = true })

vim.keymap.set('n', '<Plug>ContextPanelHide', function()
  require('context-panel').hide()
end, { silent = true })

-- Legacy mappings for backwards compatibility
vim.keymap.set('n', '<Plug>TagStackToggle', function()
  require('context-panel').toggle()
end, { silent = true })

vim.keymap.set('n', '<Plug>TagStackClear', function()
  require('context-panel').clear_tag_stack()
end, { silent = true })

-- Setup default keybindings
setup_default_keybindings()

-- Auto-setup with defaults if not explicitly configured
vim.defer_fn(function()
  if not vim.g.context_panel_setup_called then
    require('context-panel').setup()
  end
end, 0)