# nvim-ai-diagnostics

A Neovim plugin that provides AI-friendly diagnostic output formatting.

## Overview

nvim-ai-diagnostics is designed to make it easier to share and discuss Neovim LSP diagnostics with AI assistants. It provides context-aware diagnostic output that includes:

- File information
- Diagnostic severity and messages
- Code context around each diagnostic
- Clear visual indicators of problematic lines
- Markdown-friendly output format

## Features

- Generate AI-friendly diagnostic reports
- Include configurable context lines before/after each diagnostic
- Support for all diagnostic severities (Error, Warning, Info, Hint)
- Buffer-specific or workspace-wide diagnostic collection
- Customizable output formatting
- Optional automatic copying to clipboard
- Vim commands and Lua API

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
    'username/nvim-ai-diagnostics',
    requires = {
        'nvim-lua/plenary.nvim'
    }
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'username/nvim-ai-diagnostics',
    dependencies = {
        'nvim-lua/plenary.nvim'
    }
}
```

## Configuration

Default configuration:

```lua
require('ai-diagnostics').setup({
    -- Number of context lines to show before/after diagnostic
    before_lines = 2,
    after_lines = 2
})
```

## Usage

### Commands

- `:AIDiagnostics` - Show diagnostics for current buffer
- `:AIDiagnosticsWorkspace` - Show diagnostics for all buffers
- `:AIDiagnosticsCopy` - Copy diagnostics to clipboard

### Lua API

```lua
-- Get formatted diagnostics string
local diagnostics = require('ai-diagnostics').get_diagnostics()

-- Get diagnostics for specific buffer
local buf_diagnostics = require('ai-diagnostics').get_buffer_diagnostics(bufnr)

-- Get workspace diagnostics
local workspace_diagnostics = require('ai-diagnostics').get_workspace_diagnostics()

-- Copy diagnostics to clipboard
require('ai-diagnostics').copy_diagnostics()
```

### Keymaps

Example keymaps:

```lua
vim.keymap.set('n', '<leader>ad', ':AIDiagnostics<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>aw', ':AIDiagnosticsWorkspace<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>ac', ':AIDiagnosticsCopy<CR>', { noremap = true, silent = true })
```

## Output Format

The plugin generates output in the following format:

```
Diagnostics for file: example.lua

Diagnostic: [Error] Variable 'foo' is not defined
Context:
  1: local function test()
  2:   local x = 10
> 3:   print(foo)
  4:   return x
  5: end

Diagnostic: [Warning] Unused variable 'x'
Context:
  1: local function test()
> 2:   local x = 10
  3:   print(foo)
  4:   return x
  5: end
```

## Project Structure

```
.
├── lua
│   └── ai-diagnostics
│       ├── init.lua
│       ├── config.lua
│       ├── context.lua
│       ├── format.lua
│       └── utils.lua
├── plugin
│   └── ai-diagnostics.lua
├── README.md
├── LICENSE
└── doc
    └── ai-diagnostics.txt
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Inspired by the need for better AI-diagnostic communication
- Built on Neovim's powerful diagnostic API
