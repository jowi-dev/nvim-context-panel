# nvim-context-panel

A unified Neovim plugin providing a right-side context panel with advanced tag navigation and intelligent code completions. Features multi-stack management, persistent visualization, and lightning-fast navigation via keybindings.

## Features

### 🚀 Advanced Tag Navigation
- **Multi-Stack Support**: Create and switch between multiple named tag stacks
- **Persistent Visualization**: Tag history remains visible even when navigating up the stack
- **Quick Navigation**: `Alt-1` through `Alt-9` for instant jumping to any position
- **Smart Branching**: Only truncates display when taking a different path
- **Real-time Updates**: Immediate visual feedback with optimized 50ms debouncing

### 🎯 Intelligent Completions  
- **Quick Selection**: `Ctrl-1` through `Ctrl-9` for instant completion selection
- **Live Preview**: `Ctrl-P` to toggle function signatures and documentation
- **Multiple Sources**: LSP, buffer, snippet, and file path completions
- **Context Awareness**: Updates automatically as you type

### ⚡ Performance & UX
- **Lightning Fast**: Optimized event handling with race condition fixes
- **Non-intrusive**: No focus stealing or dropdown overlays  
- **Elixir Optimized**: Smart formatting for modules, functions, and arity
- **Modular Architecture**: Enable/disable features independently

## Quick Setup

Add this to your Neovim config:

```lua
-- Using lazy.nvim
{
  "yourusername/nvim-context-panel",
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

-- Using packer.nvim
use {
  'yourusername/nvim-context-panel',
  config = function()
    require('context-panel').setup()
  end
}

-- Minimal setup with defaults:
require('context-panel').setup()
```

## Panel Layout

```
┌─────────────────────────────────┐
│ Completions (40% height)        │
│ 1. useState                     │  ← Ctrl-1 to select
│ 2. useEffect                    │  ← Ctrl-2 to select  
│ 3. useCallback                  │  ← Ctrl-3 to select
├─────────────────────────────────┤
│ Tag Stack (60% height)          │
│ 📁 Tag Stacks: (Alt-# to jump)  │
│ ▶ MyApp                         │
│   1. MyApp (root) ← [current]   │  ← Alt-1 to jump
│   ↓                             │
│   2. MyApp.handle_call/3        │  ← Alt-2 to jump
│   ↓                             │
│   3. MyApp.process_request/2    │  ← Alt-3 to jump
└─────────────────────────────────┘
```

## Commands & Keybindings

### Panel Commands
- `:ContextPanelToggle` - Show/hide entire panel
- `:ContextPanelShow` - Show panel  
- `:ContextPanelHide` - Hide panel

### Tag Stack Commands
- `:TagStackToggle` - Toggle tag stack section
- `:TagStackClear` - Clear current tag stack
- `:TagStackNew` - Create a new tag stack
- `:TagStackNext` - Switch to next stack
- `:TagStackPrev` - Switch to previous stack

### Tag Stack Navigation Keybindings
- `<Alt-1>` through `<Alt-9>` - Jump directly to tag stack position
- `<C-]>` - Standard tag jump (builds stack downward)
- `<C-t>` - Standard tag pop (moves up stack)

### Completion Commands & Keybindings
- `:CompletionToggle` - Toggle completion section
- `:CompletionPreview` - Show/hide preview window
- `<C-1>` through `<C-9>` - Select completion by number (insert mode)
- `<C-p>` - Toggle preview for current completion (insert mode)

## Usage

### Tag Stack Navigation
1. **Create Stack**: Open any file (becomes stack root)
2. **Build Stack**: Use `C-]` to jump to tags - adds levels with ↓ arrows
3. **Navigate**: Use `C-t` to go back up - visualization persists deeper items
4. **Quick Jump**: Press `Alt-1` through `Alt-9` to instantly jump to any position
5. **Multi-Stack**: Use `:TagStackNew` to create additional stacks, `:TagStackNext` to switch
6. **Smart Persistence**: Stack items remain visible until you branch in a new direction

### Smart Completions  
1. **Auto-Show**: Start typing in insert mode - completions appear instantly
2. **Quick Select**: Press `Ctrl-1` through `Ctrl-9` for immediate selection
3. **Preview**: Press `Ctrl-P` to toggle function signatures and documentation
4. **Multiple Sources**: Automatic LSP, buffer, snippet, and file completions

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

## Why This Plugin?

Unlike traditional tag navigation that only shows your current position, nvim-context-panel provides:

- 🧠 **Cognitive Support**: See your complete navigation path, not just where you are now  
- ⚡ **Speed**: Instant jumping to any previous position with `Alt-#` 
- 🎯 **Persistence**: Tag history persists even when navigating up, until you branch
- 🔄 **Multi-Context**: Work with multiple tag stacks simultaneously
- 🎨 **Visual Clarity**: Downward arrows clearly show navigation flow

Perfect for exploring large codebases, understanding call hierarchies, and maintaining context during deep debugging sessions.

## Requirements

- Neovim 0.8+ (for floating window APIs)
- Optional: LSP client for intelligent completions
- Optional: ctags or universal-ctags for enhanced tag information

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

MIT License - see LICENSE file for details.