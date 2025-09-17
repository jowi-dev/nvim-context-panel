# nvim-tag-stack

A Neovim plugin that visualizes the tag navigation stack as a vertical flowchart, optimized for Elixir development.

## Quick Setup

Add this to your Neovim config:

```lua
-- If using lazy.nvim
{
  dir = "/Users/jowi/Projects/nvim-tag-stack",
  config = function()
    require('tag-stack').setup({
      width = 50,              -- Panel width
      position = 'right',      -- 'right' or 'left'
      auto_show = true,        -- Auto-show on first tag jump
      show_line_numbers = true,
      show_arity = true,       -- Show Elixir function arity
    })
  end,
  keys = {
    { "<leader>ts", "<cmd>TagStackToggle<cr>", desc = "Toggle tag stack" },
    { "<leader>tc", "<cmd>TagStackClear<cr>", desc = "Clear tag stack" },
  },
}

-- Or add directly to your config:
require('tag-stack').setup()
```

## Commands

- `:TagStackToggle` - Toggle the tag stack panel
- `:TagStackShow` - Show the tag stack panel  
- `:TagStackHide` - Hide the tag stack panel
- `:TagStackClear` - Clear the current tag stack

## Default Keybindings

- `<leader>ts` - Toggle tag stack panel
- `<leader>tc` - Clear tag stack

## Usage

1. Open an Elixir file
2. Use `C-]` to jump to tags (requires ctags)
3. The panel will show your navigation stack
4. Use `C-t` to go back up the stack
5. Panel updates in real-time

## Requirements

- Neovim 0.7+
- ctags or universal-ctags for tag generation