# AI Diagnostics Plugin Refactor Design

## Overview
This document outlines a simplified, more maintainable architecture for the ai-diagnostics plugin.

## Core Principles
1. **Simplicity**: Remove over-engineered features
2. **Clear Separation**: Each module has one responsibility
3. **Consistent Error Handling**: Errors bubble up to the main module
4. **Minimal State**: Only track what's necessary

## Module Structure

### 1. `init.lua` - Main Entry Point
**Responsibilities:**
- Setup and configuration
- Command registration
- Public API methods

**Key Functions:**
- `setup(config)` - Initialize plugin
- `get_diagnostics()` - Get formatted diagnostics for current buffer
- `get_all_diagnostics()` - Get diagnostics for all buffers
- `show()` - Show diagnostics in window
- `hide()` - Hide diagnostics window
- `toggle()` - Toggle diagnostics window

### 2. `config.lua` - Configuration Management
**Responsibilities:**
- Default configuration
- Config validation
- Config merging

**Structure:**
