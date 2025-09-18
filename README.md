# nvim-context-panel

A unified Neovim plugin providing a right-side context panel with tag navigation visualization and intelligent code completions, optimized for Elixir development.

## Features

- **Tag Stack Visualization**: Real-time flowchart of your code navigation history
- **Smart Completions**: LSP-powered completions with quick selection keys
- **Modular Architecture**: Enable/disable features independently
- **Elixir Optimized**: Understands modules, functions with arity, and project structure
- **Non-intrusive**: No focus stealing or dropdown overlays

## Quick Setup

Add this to your Neovim config:

```lua
-- If using lazy.nvim
{
  dir = "/Users/jowi/Projects/nvim-tag-stack",
  config = function()
    require('context-panel').setup({
      panel = {
        width = 40,
        position = 'right',
        auto_show = true,
      },
      modules = {
        tag_stack = {
          enabled = true,
          height_ratio = 0.6,
          show_line_numbers = true,
          show_arity = true,
        },
        completions = {
          enabled = true,
          height_ratio = 0.4,
          max_items = 12,
          quick_select_keys = '123456789abcdef',
        }
      }
    })
  end,
  keys = {
    { "<leader>cp", "<cmd>ContextPanelToggle<cr>", desc = "Toggle context panel" },
    { "<leader>ts", "<cmd>TagStackToggle<cr>", desc = "Toggle tag stack" },
    { "<leader>tc", "<cmd>TagStackClear<cr>", desc = "Clear tag stack" },
  },
}

-- Or minimal setup with defaults:
require('context-panel').setup()
```

## Panel Layout

```
┌─────────────────────────────────┐
│ Completions (40% height)        │
│ 1. useState                     │
│ 2. useEffect                    │
│ 3. useCallback                  │
├─────────────────────────────────┤
│ Tag Stack (60% height)          │
│ 📁 my_app.ex:45                 │
│ │  └─ MyApp.Server              │
│ │     └─ handle_call/3:78       │
│ │        └─ process_request/2   │
└─────────────────────────────────┘
```

## Commands

### Panel Commands
- `:ContextPanelToggle` - Show/hide entire panel
- `:ContextPanelShow` - Show panel
- `:ContextPanelHide` - Hide panel

### Module Commands
- `:TagStackToggle` - Toggle tag stack section
- `:CompletionToggle` - Toggle completion section
- `:TagStackClear` - Clear current tag stack

### Completion Commands
- `:CompletionPreview` - Show/hide preview window
- `<C-1>` through `<C-9>` - Select completion by number
- `<C-p>` - Toggle preview for current completion

## Usage

### Tag Stack Navigation
1. Open any file with `:e filename` (becomes stack root)
2. Use `C-]` to jump to tags - adds levels to the stack
3. Use `C-t` to go back up - updates visualization in real-time
4. Panel shows your complete navigation history

### Smart Completions
1. Start typing in insert mode
2. Completions appear in the right panel
3. Use number keys (1-9) or letters (a-f) for instant selection
4. Optional preview window shows function signatures

## Configuration

```lua
require('context-panel').setup({
  panel = {
    width = 40,              -- Panel width in columns
    position = 'right',      -- 'right' or 'left'
    auto_show = true,        -- Auto-show on events
  },
  modules = {
    tag_stack = {
      enabled = true,         -- Enable tag stack module
      height_ratio = 0.6,     -- 60% of panel height
      show_line_numbers = true,
      show_arity = true,      -- Show function arity (Elixir)
      max_stack_depth = 20,
    },
    completions = {
      enabled = true,         -- Enable completion module
      height_ratio = 0.4,     -- 40% of panel height
      max_items = 12,
      show_preview = true,
      preview_position = 'left',
      quick_select_keys = '123456789abcdef',
    }
  }
})
```

## Requirements

- Neovim 0.8+ (for floating window APIs)
- Optional: LSP client for intelligent completions
- Optional: ctags or universal-ctags for enhanced tag information