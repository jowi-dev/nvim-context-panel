# Elixir Tag Stack Visualizer - Neovim Plugin Requirements

## Project Overview
Build a Neovim plugin that visualizes the current tag navigation stack as a vertical flowchart in a side panel, specifically optimized for Elixir development workflows.

## Core Functionality Requirements

### 1. Stack Management
- **Root Initialization**: When a file is opened with `:e` command, it becomes the root/top of the stack
- **Stack Building**: Each `C-]` (tag jump) adds a new level to the visualization stack
- **Stack Navigation**: `C-t` (tag pop) moves back up the stack and updates the visualization
- **Real-time Updates**: Side panel updates immediately on tag navigation events

### 2. Visualization Requirements
- **Side Panel**: Display as a vertical panel on the right side of Neovim
- **Flowchart Format**: Show hierarchical flow from top (root file) downward to current position
- **Current Position Indicator**: Clearly mark where the user currently is in the stack
- **File Context**: Show filename, line number, and function/module context for each level

### 3. Technical Integration
- **Tag Stack Integration**: Hook into Neovim's built-in tag stack (`:echo tagstack()`)
- **Ctags Dependency**: Parse and utilize ctags output for symbol information
- **Event Handling**: Listen for tag navigation events to trigger updates
- **Buffer Management**: Handle multiple buffers/files gracefully

## Elixir-Specific Requirements

### 1. Symbol Recognition
- Parse Elixir module names (`MyApp.Module`)
- Identify function definitions with arity (`handle_call/3`)
- Recognize pattern matching and function heads
- Handle pipe operator chains contextually

### 2. File Structure Awareness
- Understand typical Elixir project structure (`lib/`, `test/`, etc.)
- Parse `mix.exs` and application structure if available
- Handle umbrella applications appropriately

## User Interface Specifications

### 1. Display Format
```
📁 my_app.ex:45
│  └─ MyApp.Server
│     └─ handle_call/3:78
│        └─ process_request/2:156
│           └─ validate_params/1:201  ← [current]
```

### 2. Panel Behavior
- **Toggle Command**: Provide command to show/hide the panel
- **Resize Support**: Allow manual resizing of the panel width
- **Auto-update**: Automatically refresh when navigating tags
- **Scroll Support**: Handle long stacks that exceed panel height

## Commands and Keybindings

### 1. Required Commands
- `:TagStackShow` - Show/toggle the tag stack panel
- `:TagStackHide` - Hide the tag stack panel
- `:TagStackClear` - Clear the current stack and start fresh

### 2. Suggested Default Keybindings
- `<leader>ts` - Toggle tag stack panel
- `<leader>tc` - Clear tag stack

## Configuration Options

### 1. Panel Settings
- `width` - Panel width (default: 40 characters)
- `position` - Panel position ('right' or 'left', default: 'right')
- `auto_show` - Auto-show panel on first tag jump (default: true)

### 2. Display Options
- `show_line_numbers` - Show line numbers in stack (default: true)
- `show_file_path` - Show full or relative file paths (default: 'relative')
- `max_stack_depth` - Maximum levels to display (default: 20)

### 3. Elixir-Specific Options
- `show_arity` - Show function arity in display (default: true)
- `show_module_path` - Show full module paths (default: true)

## Future Extension Points

### 1. Sibling Support (Phase 2)
- Show related test files (`*_test.exs`) at each level
- Display related modules in the same application
- Show GenServer callback relationships

### 2. Enhanced Visualization (Phase 3)
- Color coding for different symbol types
- Minimap-style overview for very deep stacks
- Integration with LSP for richer symbol information

## Technical Constraints

### 1. Dependencies
- Requires `ctags` or `universal-ctags` to be installed
- Must work with Neovim 0.7+
- Should be implemented in Lua for performance

### 2. Performance Requirements
- Panel updates should be instantaneous (<100ms)
- Should handle large codebases without significant lag
- Graceful degradation if ctags data is unavailable

## Error Handling
- Handle missing ctags gracefully
- Provide clear error messages for setup issues
- Fall back to basic file:line display if symbol parsing fails

## Testing Requirements
- Include sample Elixir project for testing
- Test with various project structures (standard, umbrella)
- Test performance with large tag stacks
- Verify behavior with multiple open buffers

---

## Getting Started Notes
1. Start with basic tag stack integration and simple ASCII visualization
2. Build the core navigation tracking before adding advanced formatting
3. Test thoroughly with a real Elixir project during development
4. Consider using existing Neovim plugin templates/boilerplates for structure