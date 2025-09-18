# Context Panel Plugin - Neovim Plugin Requirements

## Project Overview
Build a unified Neovim plugin that provides a right-side context panel with two integrated modules: tag navigation visualization (optimized for Elixir) and intelligent code completions.

## Core Functionality Requirements

### 1. Modular Architecture
- **Unified Panel**: Single floating window split into configurable sections
- **Module System**: Enable/disable tag stack and completion modules independently
- **Shared Configuration**: One setup call configures both modules
- **Easy Installation**: Single plugin installation with optional features

### 2. Tag Stack Module (existing functionality)
- **Root Initialization**: When a file is opened with `:e` command, it becomes the root/top of the stack
- **Stack Building**: Each `C-]` (tag jump) adds a new level to the visualization stack
- **Stack Navigation**: `C-t` (tag pop) moves back up the stack and updates the visualization
- **Real-time Updates**: Panel updates immediately on tag navigation events

### 3. Completion Module (new functionality)
- **Right-side List**: Show completions in numbered/lettered list with quick selection keys
- **Live Updates**: Update completions as user types in insert mode
- **Multiple Sources**: Integrate LSP, buffer, and snippet completions
- **Optional Preview**: Floating window to the left showing function details/documentation
- **Non-intrusive**: No focus stealing, no dropdown overlays

## Visualization Requirements

### 1. Panel Layout
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

### 2. Panel Behavior
- **Toggle Command**: Show/hide entire panel or individual modules
- **Resize Support**: Configurable width and height ratios
- **Auto-positioning**: Automatically positions to avoid conflicts
- **Responsive Layout**: Adapts when only one module is enabled

## Elixir-Specific Requirements (Tag Stack Module)

### 1. Symbol Recognition
- Parse Elixir module names (`MyApp.Module`)
- Identify function definitions with arity (`handle_call/3`)
- Recognize pattern matching and function heads
- Handle pipe operator chains contextually

### 2. File Structure Awareness
- Understand typical Elixir project structure (`lib/`, `test/`, etc.)
- Parse `mix.exs` and application structure if available
- Handle umbrella applications appropriately

## Completion System Requirements

### 1. Completion Sources
- **LSP Integration**: Primary source for intelligent completions
- **Buffer Words**: Fallback for non-LSP environments
- **Snippet Integration**: Support for common code snippets
- **File Path Completion**: For imports and requires

### 2. Selection Interface
- **Quick Keys**: Number keys (1-9) and letters (a-z) for instant selection
- **Preview on Demand**: Optional floating preview window with function signatures
- **Context Awareness**: Filter completions based on current context

## Commands and Keybindings

### 1. Panel Commands
- `:ContextPanelToggle` - Show/hide entire panel
- `:ContextPanelShow` - Show panel
- `:ContextPanelHide` - Hide panel

### 2. Module Commands
- `:TagStackToggle` - Toggle just tag stack section
- `:CompletionToggle` - Toggle just completion section
- `:TagStackClear` - Clear current tag stack

### 3. Completion Commands
- `:CompletionPreview` - Show/hide preview window
- `<C-1>` through `<C-9>` - Select completion by number
- `<C-p>` - Toggle preview for current completion

## Configuration Options

### 1. Panel Settings
```lua
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
      max_stack_depth = 20,
    },
    completions = {
      enabled = true,
      height_ratio = 0.4,
      max_items = 12,
      show_preview = true,
      preview_position = 'left',
      quick_select_keys = '123456789abcdef',
    }
  }
})
```

### 2. Completion Settings
- `sources` - Priority order of completion sources
- `min_chars` - Minimum characters before showing completions
- `auto_preview` - Automatically show preview on selection
- `preview_delay` - Delay before showing preview (ms)

## Technical Requirements

### 1. Dependencies
- Neovim 0.8+ for floating window APIs
- Optional: LSP client for intelligent completions
- Optional: `ctags` for enhanced tag information
- Lua implementation for performance

### 2. Performance
- Panel updates < 100ms
- Completion filtering < 50ms
- Graceful handling of large completion lists
- Memory efficient for long coding sessions

## Installation and Setup

### 1. Plugin Manager Integration
```lua
-- Packer
use 'your-username/nvim-context-panel'

-- Lazy.nvim
{ 'your-username/nvim-context-panel', config = true }
```

### 2. Minimal Setup
```lua
require('context-panel').setup({
  -- Uses sensible defaults
  -- Both modules enabled by default
})
```

## Future Extensions

### 1. Additional Modules
- **Diagnostics Panel**: LSP errors/warnings
- **Git Status**: File change indicators
- **Project Files**: Quick file browser
- **Buffer List**: Open buffer management

### 2. Enhanced Features
- **Themes**: Customizable color schemes
- **Layouts**: Horizontal panel option
- **Integration**: Work with other popular plugins
- **Export**: Save/restore panel states

## Error Handling
- Graceful LSP unavailability
- Fallback completions when sources fail
- Clear error messages for configuration issues
- Safe defaults for all options

---

## Implementation Priority
1. **Phase 1**: Refactor existing tag stack into modular architecture
2. **Phase 2**: Add basic completion module with quick selection
3. **Phase 3**: Implement preview window and advanced completion features
4. **Phase 4**: Polish UI/UX and add configuration options
