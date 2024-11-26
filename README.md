# nvim-ai-diagnostics

A Neovim plugin that formats diagnostics in an AI-friendly way, making it easier to share and discuss code issues with AI assistants.

## Features

- Generate clear, context-rich diagnostic reports
- Include configurable context lines before/after each diagnostic
- Support for all diagnostic severities (Error, Warning, Info, Hint)
- Buffer-specific or workspace-wide diagnostic collection
- Markdown-friendly output format
- Line truncation for better readability

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'cperion/ai-diagnostics',
    config = function()
        require('ai-diagnostics').setup({
            -- optional configuration
        })
    end
}
```

## Configuration

Default configuration:

```lua
require('ai-diagnostics').setup({
    -- Number of context lines to show before/after diagnostic
    before_lines = 2,
    after_lines = 2,
    -- Maximum length for truncated lines
    max_line_length = 120
})
```

## Usage

### Lua API

```lua
-- Get diagnostics for current buffer
local buf_diagnostics = require('ai-diagnostics').get_buffer_diagnostics()

-- Get diagnostics for specific buffer
local buf_diagnostics = require('ai-diagnostics').get_buffer_diagnostics(bufnr)

-- Get workspace diagnostics (all buffers)
local workspace_diagnostics = require('ai-diagnostics').get_workspace_diagnostics()
```

### Example Output

```
File: example.lua

Error: Variable 'foo' is not defined
Context:
  1: local function test()
  2:   local x = 10
> 3:   print(foo)
  4:   return x
  5: end

Warning: Unused variable 'x'
Context:
  1: local function test()
> 2:   local x = 10
  3:   print(foo)
  4:   return x
  5: end
```

## License

MIT License - see LICENSE file for details.
