-- nvim-tag-stack: Visualize tag navigation stack for Elixir development
-- Maintainer: Generated Plugin
-- Version: 0.1.0

if vim.g.loaded_tag_stack then
  return
end
vim.g.loaded_tag_stack = true

-- Initialize the plugin with default keybindings
local function setup_default_keybindings()
  -- Only set if not already mapped
  if not vim.fn.hasmapto('<Plug>TagStackToggle', 'n') then
    vim.keymap.set('n', '<leader>ts', '<Plug>TagStackToggle', { desc = 'Toggle tag stack panel' })
  end
  
  if not vim.fn.hasmapto('<Plug>TagStackClear', 'n') then
    vim.keymap.set('n', '<leader>tc', '<Plug>TagStackClear', { desc = 'Clear tag stack' })
  end
end

-- Plugin mappings
vim.keymap.set('n', '<Plug>TagStackToggle', function()
  require('tag-stack').toggle()
end, { silent = true })

vim.keymap.set('n', '<Plug>TagStackClear', function()
  require('tag-stack').clear()
end, { silent = true })

-- Setup default keybindings
setup_default_keybindings()

-- Auto-setup with defaults if not explicitly configured
vim.defer_fn(function()
  if not vim.g.tag_stack_setup_called then
    require('tag-stack').setup()
  end
end, 0)