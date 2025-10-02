# Context Panel Plugin - Neovim Plugin Requirements

## Project Overview
A unified Neovim plugin providing a right-side context panel with advanced tag navigation and intelligent code completions. Features multi-stack tag management with persistent visualization, quick navigation keybindings, and real-time updates optimized for development workflows.

## Core Functionality Requirements

### 1. Modular Architecture
- **Unified Panel**: Single floating window split into configurable sections
- **Module System**: Enable/disable tag stack and completion modules independently
- **Shared Configuration**: One setup call configures both modules
- **Easy Installation**: Single plugin installation with optional features

### 2. Tag Stack Module (fully implemented)
- **Multi-Stack Support**: Multiple named stacks that can be created and switched between
- **Persistent Visualization**: Tag stack items remain visible even when navigating up, until branching
- **Root Initialization**: When a file is opened, it becomes the root/top of a new stack
- **Stack Building**: Each `C-]` (tag jump) adds a new level with downward arrow visualization  
- **Stack Navigation**: `C-t` (tag pop) moves back up the stack and updates the visualization
- **Quick Navigation**: `Alt-1` through `Alt-9` for instant jumping to any stack position
- **Real-time Updates**: Panel updates immediately on tag navigation events with 50ms debouncing
- **Stack Switching**: Use `:TagStackNext`/`:TagStackPrev` to switch between multiple stacks
- **Current Position Indicators**: Shows `← [current]` for active position and `▶` for active stack
- **Smart Branching**: Only truncates display when taking a different path from a previous position

### 3. Completion Module (implemented)
- **Right-side List**: Show completions in numbered/lettered list with quick selection keys
- **Live Updates**: Update completions as user types in insert mode
- **Multiple Sources**: Integrate LSP, buffer, and snippet completions
- **Quick Selection**: `Ctrl-1` through `Ctrl-9` for instant completion selection
- **Preview Toggle**: `Ctrl-P` to show/hide function details/documentation
- **Optional Preview**: Floating window to the left showing function signatures
- **Non-intrusive**: No focus stealing, no dropdown overlays
- **Context Awareness**: Updates based on current editing context

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
│ 📁 Tag Stacks: (Alt-# to jump)  │
│ ▶ MyApp                         │
│   1. MyApp (root) ← [current]   │
│   ↓                             │
│   2. MyApp.Server.handle_call/3 │
│   ↓                             │
│   3. MyApp.process_request/2    │
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
- `:TagStackNew` - Create a new tag stack
- `:TagStackNext` - Switch to next stack
- `:TagStackPrev` - Switch to previous stack

### 3. Completion Commands
- `:CompletionPreview` - Show/hide preview window
- `<C-1>` through `<C-9>` - Select completion by number
- `<C-p>` - Toggle preview for current completion

### 4. Tag Stack Navigation
- `<Alt-1>` through `<Alt-9>` - Jump directly to tag stack position (preserves tag stack)
- `<Alt-1>` - Jump to root file
- `<Alt-2>` - Jump to first tag in stack
- `<Alt-3>` - Jump to second tag in stack, etc.
- `<C-]>` - Standard tag jump (builds stack downward)
- `<C-t>` - Standard tag pop (moves up stack)

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
- Panel updates with 50ms debouncing for smooth real-time updates
- Tag navigation responds instantly with deferred stack detection
- Completion filtering < 50ms
- Graceful handling of large completion lists
- Memory efficient for long coding sessions
- Persistent tag stack visualization without memory leaks

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

## Implementation Status
✅ **Phase 1**: Modular architecture with unified context panel  
✅ **Phase 2**: Multi-stack tag navigation with persistent visualization  
✅ **Phase 3**: Quick navigation keybindings (`Alt-1` through `Alt-9`)  
✅ **Phase 4**: Completion module with preview and quick selection  
✅ **Phase 5**: Real-time updates with optimized debouncing  
✅ **Phase 6**: Smart branching detection and stack persistence

## Current Features Working
- **Multi-stack tag management** with stack switching
- **Persistent tag visualization** that preserves context
- **Quick navigation** via `Alt-#` keybindings  
- **Real-time panel updates** with race condition fixes
- **Completion system** with `Ctrl-#` selection and `Ctrl-P` preview
- **Elixir-optimized** module and function display formatting
- **Configurable panel** sizing and positioning
- **Debug commands** for troubleshooting when needed
