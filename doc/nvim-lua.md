# Neovim Lua API

## Introduction to Lua in Neovim

Neovim comes with a built-in Lua 5.1 script engine, always available for use. This integration allows users and plugin developers to leverage Lua for scripting and configuration.

**Key Facts:**

* **Lua Version:** Neovim uses Lua 5.1. Plugins and user configurations should target this specific version.
* **Standard Library:** Neovim provides a `vim` module, known as `lua-stdlib`, which acts as a standard library for Lua. This module complements Vimscript functions and Ex commands, and the core Nvim API, forming the complete Nvim programming interface.
* **Automatic Discovery:** Lua plugins and user configurations are automatically discovered and loaded, similar to Vimscript.
* **Shell Execution:** Lua scripts can be executed directly from the shell using the `-l` argument:

    ```bash
    nvim -l foo.lua [args...]
    ```

**Example:**
To inspect the loaded Lua packages:

```lua
:lua vim.print(package.loaded)
```

### Lua Compatibility (`lua-compat`)

Lua 5.1 is the **permanent interface** for Neovim Lua. Later Lua versions are not supported due to their incompatible nature. Extensions often found in other Lua 5.1 interpreters (like LuaJIT's `goto` statements) are also not supported.

### LuaJIT Support (`lua-luajit`)

While Neovim only requires Lua 5.1 support, it is recommended to build Nvim with **LuaJIT** or a compatible fork for performance benefits on supported platforms. LuaJIT also offers useful extensions, though their availability should be explicitly checked:

**Key Facts:**

* **Extensions:** LuaJIT provides `ffi`, profiling capabilities (`lua-profile`), and enhanced standard library functions.
* **Availability Check:** Code should check the `jit` global variable before using LuaJIT-specific features.

**Example: Checking for LuaJIT**

```lua
if jit then
  -- code for luajit
else
  -- code for plain lua 5.1
end
```

**Exception: LuaJIT `bit` extension**
The LuaJIT `bit` extension (`require("bit")`) is *always* available. If Nvim is built with PUC Lua, a fallback implementation is provided.

**Lua Profiling (`lua-profile`)**
If Nvim is built with LuaJIT, Lua code can be profiled:

```lua
-- Start a profiling session:
require('jit.p').start('ri1', '/tmp/profile')

-- Perform arbitrary tasks (use plugins, scripts, etc.) ...

-- Stop the session. Profile is written to /tmp/profile.
require('jit.p').stop()
```

For more details, see the `p.lua` source:

```lua
:lua vim.cmd.edit(package.searchpath('jit.p', package.path))
```

## Lua Concepts and Idioms (`lua-concepts`)

Lua's strength lies in its **simplicity and consistency**. Once you grasp its core quirks, the behavior is uniform across different contexts.

**Fundamental Mechanisms:**
Lua centers around three fundamental mechanisms, each addressing a major aspect of programming:

1. **Tables:**
    * The "object" or container data structure.
    * Represent both **lists** (arrays) and **maps** (dictionaries).
    * Extendable with **metatables** to customize behavior (similar to Python's data model).

2. **Closures:**
    * **Every scope in Lua is a closure.** This includes functions, modules, and `do` blocks.
    * A Lua module is essentially a large closure discovered on the `package.cpath`.

3. **Coroutines:**
    * Enable **cooperative multithreading**, generators, and versatile control flow for both Lua and its host (Nvim).

### Error Handling (`lua-error-handling`)

Lua distinguishes between exceptional (unexpected) failures and normal (expected) failures.

* **Exceptional Failures:**
  * Represented by errors, which can be handled using `pcall()`.
* **Normal Failures (Result-or-Message Pattern):**
  * It's idiomatic to return `nil` (or `nil` plus an error message string) to signal that failure is expected and should be handled by the caller.
  * This pattern is described as a multi-value return type: `any|nil, nil|string`.

**Example: Result-or-Message Pattern**

```lua
vim.ui.open()
io.open()
```

**Guidance for Result-or-Message:**
Use this pattern for:

* Functions communicating with the external world (e.g., HTTP requests, LSP requests), where failure is a common occurrence.
* Functions that return a value (e.g., `Foo:new()`).
* Cases where a list of known error codes can be returned as a third value (like `luv-error-handling`).

**Handling Normal Failures with `assert()`**
When a caller *cannot* proceed on failure, it's idiomatic to use `assert()` to enforce the "result-or-message" pattern.

```lua
local value = assert(fn())
```

### Iterators and Iterables

* **Iterator (`iterator`):** A function that can be called repeatedly to get the "next" value from a collection. Expected by `for-in` loops, produced by `pairs()`, and supported by `vim.iter`.
* **Iterable (`iterable`):** Anything that `vim.iter()` can consume: tables (dicts, lists), iterator functions, tables implementing the `__call()` metamethod, and `vim.iter()` objects.
* **List Iterator (`list-iterator`):** Iterators over `lua-list` tables have a defined "middle" and "end" because lists are finite. Some `vim.iter` operations (e.g., `Iter:rev()`) are only meaningful for list-like tables.

### Lua Function Calls (`lua-function-call`)

Lua functions can be called in multiple ways. Missing arguments are passed as `nil`, and extra parameters are silently discarded.

**Standard Call:**

```lua
local foo = function(a, b)
    print("A: ", a)
    print("B: ", b)
end
foo(1, 2)
-- ==== Result ====
-- A: 1
-- B: 2

foo(1)
-- ==== Result ====
-- A: 1
-- B: nil
```

**"Keyword Arguments" (`kwargs`) Mimicry:**
Parentheses can be omitted if a function takes **exactly one string literal or table literal**. This is commonly used to simulate named parameters.

```lua
local func_with_opts = function(opts)
    local will_do_foo = opts.foo
    local filename = opts.filename
    -- ...
end

-- Calls func_with_opts with a single table argument { foo = true, filename = "hello.world" }
func_with_opts { foo = true, filename = "hello.world" }
```

This is purely syntactic sugar; internally, it's still a single table argument.

### Lua Regex (`lua-regex`)

Lua intentionally *does not support regular expressions*. Instead, it has **limited Lua patterns** which avoid the performance pitfalls of extended regex. For full Vim regex capabilities from Lua, use `vim.regex()`.

**Examples of Lua Patterns:**

```lua
print(string.match("foo123bar123", "%d+"))  -- Matches one or more digits
-- 123

print(string.match("foo123bar123", "[^%d]+")) -- Matches one or more non-digits
-- foo

print(string.match("foo123bar123", "[abc]+")) -- Matches one or more 'a', 'b', or 'c'
-- ba

print(string.match("foo.bar", "%.bar"))     -- Escapes magic character '.'
-- .bar
```

## Importing Lua Modules (`lua-module-load`)

Lua modules are searched for within the directories specified in `'runtimepath'` and `packages-runtimepath`. The order of directories in `nvim_list_runtime_paths()` determines the search priority.

**Search Mechanism:**

1. **Directory Mapping:** Any `.` in the module name (e.g., `foo.bar`) is treated as a directory separator, leading to searches for `lua/foo/bar.lua` and `lua/foo/bar/init.lua` within each `runtimepath` entry.
2. **Shared Libraries:** If no Lua files are found, Nvim searches again for shared libraries matching `lua/foo/bar.?` (where `?` is suffixes from `package.cpath`).
3. **Lua Default:** If still not found, Nvim falls back to Lua's default search mechanism.
4. **First Wins:** The first script found is executed. `require()` returns the value returned by the script, or `true` if no value is returned.
5. **Caching:** The return value of `require()` is cached after the first call for each module. Subsequent calls return the cached value without re-searching or re-executing the script.

**Example Search Order for `require('mod')` (with `runtimepath` `foo,bar` and `package.cpath` `./?.so;./?.dll`):**

```
foo/lua/mod.lua
foo/lua/mod/init.lua
bar/lua/mod.lua
bar/lua/mod/init.lua
foo/lua/mod.so
foo/lua/mod.dll
bar/lua/mod.so
bar/lua/mod.dll
```

**Notes on `runtimepath` and `package.path`:**

* Nvim tracks `'runtimepath'` but not current `package.path` or `package.cpath` values. Setting `'runtimepath'` (e.g., `let &runtimepath = &runtimepath`) triggers an update.
* Paths in `'runtimepath'` containing semicolons are skipped for `package.path` and `package.cpath` to avoid issues with some plugins.

## Commands (`lua-commands`)

Neovim provides several Ex commands for executing Lua code from the command line or files. Each chunk executed has its own scope (closure), so only global variables are shared between command calls. The `lua-stdlib` modules and user modules are available.

**Output Redirection:**
The Lua `print()` function redirects its output to the Nvim message area, with arguments separated by a space (` `) instead of a tab (`\t`).

### `:lua`

Executes a Lua chunk.

* **:lua {chunk}**: Executes the provided Lua chunk.
* **:lua= {expr}**: If the chunk starts with `=`, the rest is evaluated as an expression and printed. This is equivalent to `:lua print(vim.inspect(expr))`.
* **:{range}lua**: Executes buffer lines in `[range]` as Lua code.

**Examples:**

```lua
:lua vim.api.nvim_command('echo "Hello, Nvim!"')
:lua print(_VERSION)             -- See Lua version
:lua =jit.version                -- See LuaJIT version (if available)
```

**Executing a buffer range:**
Select lines and type `:lua<Enter>`.

```lua
print(string.format(
    'unix time: %s', os.time()))
```

### `:lua-heredoc`

Executes a multiline Lua script within Vimscript.

* **`:lua << [trim] [{endmarker}] {script} {endmarker}`**: Executes `script`. `[endmarker]` can be omitted, using `.` (dot) to end the script (similar to `:append`, `:insert`).

**Example:**

```vimscript
function! CurrentLineInfo()
lua << EOF
local linenr = vim.api.nvim_win_get_cursor(0)[1]
local curline = vim.api.nvim_buf_get_lines(0, linenr - 1, linenr, false)[1]
print(string.format('Line [%d] has %d bytes', linenr, #curline))
EOF
endfunction
```

**Subtle Fact:** Local variables defined within a `:lua << EOF` block will disappear after the block finishes, but globals will persist.

### `:luado`

Executes a Lua chunk for each line in a buffer range.

* **`:[range]luado {body}`**: Runs `function(line, linenr) {body} end` for each line. `line` is the current line text, `linenr` is the current line number. If the function returns a string, it replaces the buffer line. Default range is the whole file (`1,$`).

**Examples:**

```lua
:luado return string.format("%s\t%d", line:reverse(), #line)

-- Using LPeg for conditional line modification:
:lua require"lpeg"
:lua -- balanced parenthesis grammar:
:lua bp = lpeg.P{ "(" * ((1 - lpeg.S"()") + lpeg.V(1))^0 * ")" }
:luado if bp:match(line) then return "=>\t" .. line end
```

### `:luafile`

Executes a Lua script from a file.

* **`:luafile {file}`**: Executes the Lua script in `{file}`. The whole argument is used as the filename, so spaces don't need escaping. Equivalent to `:source` for Lua files.

**Examples:**

```vimscript
:luafile script.lua
:luafile %
```

## `luaeval()` (`lua-eval`)

`luaeval()` is the equivalent of `vim.eval` for passing Lua values to Nvim. It evaluates a Lua expression string and returns the result, converting Lua values to their Vimscript types.

**Signature:**

```lua
function luaeval (expstr, arg)
    local chunk = assert(loadstring(chunkheader .. expstr, "luaeval"))
    return chunk(arg) -- return typval
end
```

**Type Conversion Rules:**

* Lua `nil`, numbers, strings, tables, and booleans are converted to their respective Vimscript types.
* Lua strings with NUL bytes are converted to Blobs.
* Conversion of other Lua types is an error.
* The magic global `_A` in the `expstr` contains the second argument passed to `luaeval()`.

**Examples:**

```vimscript
:echo luaeval('_A[1] + _A[2]', [40, 2])
" 42
:echo luaeval('string.match(_A, "[a-z]+")', 'XYXfoo123')
" foo

:echo luaeval('math.pi')
:function Rand(x,y) " random uniform between x and y
:  return luaeval('(_A.y-_A.x)*math.random()+_A.x', {'x':a:x,'y':a:y})
:  endfunction
:echo Rand(1,10)
```

**Subtle Fact:** Arguments to `luaeval` and its return value are **copied** (marshalled). Changes to Lua containers within `luaeval` do not affect the original Vimscript values.

### Lua Table Ambiguity (`lua-table-ambiguous`)

Lua tables serve as both dictionaries and lists, leading to ambiguity for empty tables or those with mixed keys. Nvim defines specific rules for conversion to Vimscript:

* **Empty Table (`lua-list`):** An empty Lua table `{}` is treated as a **list**. To represent an empty Vimscript dictionary, use `vim.empty_dict()`.
* **List (`lua-list`):** A table with `N` consecutive integer keys `1...N` (no `nil` values, i.e., no "holes") is a list.
* **Dictionary (`lua-dict`):**
  * A table with **string keys**, none containing a NUL byte, is a dict.
  * A table with string keys, at least one containing a NUL byte, is also a dictionary, converted to a `msgpack-special-map`.
* **Special Table (`lua-special-tbl`):**
  * Tables with a `vim.type_idx` key can explicitly specify their type:
    * `{[vim.type_idx]=vim.types.float, [vim.val_idx]=1}` converts to a floating-point `1.0`. Allows integral floats.
    * `{[vim.type_idx]=vim.types.dictionary}` converts to an empty dictionary. With other keys (e.g., `{[vim.type_idx]=vim.types.dictionary, [42]=1, a=2}`), non-string keys are ignored (result: `{'a': 2}`).
    * `{[vim.type_idx]=vim.types.array}` converts to an empty list. Integral keys not forming a `1` to `N` sequence and all non-integral keys are ignored.
  * Tables with keys not fitting rules 1-3 (lists/dicts) are considered errors unless `vim.type_idx` is used.

## Vimscript `v:lua` Interface (`v:lua-call`)

The `v:lua` prefix in Vimscript allows calling global Lua functions or functions accessible through global Lua tables.

**Calling Global Functions:**

```vimscript
call v:lua.func(arg1, arg2)
" Equivalent to Lua: return func(...)
```

**Calling Nested Functions:**

```vimscript
call v:lua.somemod.func(args)
" Equivalent to Lua: return somemod.func(...)
```

**Calling Module Functions with `require`:**
Only the single-quote form without parentheses is allowed for `require`.

```vimscript
call v:lua.require'mypack'.func(arg1, arg2)
call v:lua.require'mypack.submod'.func(arg1, arg2)
```

**Subtle Fact:** `require"mypack"` or `require('mypack')` as a prefix will *not* work with `v:lua`.

**Using `v:lua` in `func` options:**

```vimscript
" In Lua:
function mymod.omnifunc(findstart, base)
  if findstart == 1 then
    return 0
  else
    return {'stuff', 'steam', 'strange things'}
  end
end

-- In Vimscript:
vim.bo[buf].omnifunc = 'v:lua.mymod.omnifunc'
```

**Calling as Vimscript methods:**

```vimscript
:eval arg1->v:lua.somemod.func(arg2)
```

**Limitations:**
`v:lua` without a function call (e.g., to create a Funcref) is **not allowed**.

```vimscript
let g:Myvar = v:lua.myfunc        " Error: Funcrefs cannot represent Lua functions.
call SomeFunc(v:lua.mycallback)   " Error
let g:foo = v:lua                 " Error
let g:foo = v:['lua']             " Error
```

## Lua Standard Modules (`lua-stdlib`)

The Neovim Lua standard library is exposed through the `vim` module, which is always loaded. `require("vim")` is unnecessary.

**Inspecting the `vim` module:**

```lua
:lua vim.print(vim)
```

Output will show available functions and sub-modules, e.g.:

```lua
{
  _os_proc_children = <function 1>,
  _os_proc_info = <function 2>,
  ...
  api = {
    nvim__id = <function 5>,
    nvim__id_array = <function 6>,
    ...
  },
  deepcopy = <function 106>,
  gsplit = <function 107>,
  ...
}
```

**Subtle Fact:** Functions prefixed with an underscore (e.g., `_os_proc_children`) are internal/private and **should not be used by plugins**.

To find documentation for a function like `vim.deepcopy()`, use `:help vim.deepcopy()`.

---

## `vim.uv` (`lua-loop vim.uv`)

`vim.uv` provides Lua bindings for `libUV`, Nvim's underlying library for networking, filesystem, and process management. It allows interaction with the main Nvim `luv-event-loop`.

**Event Loop Callbacks (`E5560 lua-loop-callbacks`)**
Directly invoking most `vim.api` functions within `vim.uv` callbacks is an error. To avoid this, use `vim.schedule_wrap()` to defer the callback execution to the main event loop. For one-shot timers, `vim.defer_fn()` automatically handles this wrapping.

**Example: Incorrect Timer Callback (Error)**

```lua
local timer = vim.uv.new_timer()
timer:start(1000, 0, function()
  vim.api.nvim_command('echomsg "test"') -- ERROR here
end)
```

**Example: Correct Timer Callback using `vim.schedule_wrap()`**

```lua
local timer = vim.uv.new_timer()
timer:start(1000, 0, vim.schedule_wrap(function()
  vim.api.nvim_command('echomsg "test"')
end))
```

**Examples:**

##### Repeating Timer

1. Save this code to a file.
2. Execute it with `:luafile %`.

```lua
-- Create a timer handle (implementation detail: uv_timer_t).
local timer = vim.uv.new_timer()
local i = 0
-- Waits 1000ms, then repeats every 750ms until timer:close().
timer:start(1000, 750, function()
  print('timer invoked! i='..tostring(i))
  if i > 4 then
    timer:close()  -- Always close handles to avoid leaks.
  end
  i = i + 1
end)
print('sleeping');
```

##### File-Change Detection (`watch-file`)

1. Save this code to a file.
2. Execute it with `:luafile %`.
3. Use `:Watch %` to watch any file.
4. Try editing the file from another text editor.
5. Observe that the file reloads in Nvim (because `on_change()` calls `:checktime`).

```lua
local w = vim.uv.new_fs_event()
local function on_change(err, fname, status)
  -- Do work...
  vim.api.nvim_command('checktime')
  -- Debounce: stop/start.
  w:stop()
  watch_file(fname)
end
function watch_file(fname)
  local fullpath = vim.api.nvim_call_function(
    'fnamemodify', {fname, ':p'})
  w:start(fullpath, {}, vim.schedule_wrap(function(...)
    on_change(...) end))
end
vim.api.nvim_command(
  "command! -nargs=1 Watch call luaeval('watch_file(_A)', expand('<args>'))")
```

**Inotify Limitations (`inotify-limitations`)**
On Linux, you might need to increase the `fs.inotify.max_user_watches` and queued events limit.

```bash
sysctl fs.inotify.max_user_watches=494462
```

These changes can be made persistent by adding the line to `/etc/sysctl.conf`.
**Subtle Fact:** Each inotify watch consumes kernel memory (up to 1KB). A million watches can consume 1GB of RAM.

##### TCP Echo Server (`tcp-server`)

1. Save this code to a file.
2. Execute it with `:luafile %`.
3. Note the port number printed.
4. Connect from a TCP client (e.g., `nc 0.0.0.0 <port_number>`).

```lua
local function create_server(host, port, on_connect)
  local server = vim.uv.new_tcp()
  server:bind(host, port)
  server:listen(128, function(err)
    assert(not err, err)  -- Check for errors.
    local sock = vim.uv.new_tcp()
    server:accept(sock)  -- Accept client connection.
    on_connect(sock)  -- Start reading messages.
  end)
  return server
end
local server = create_server('0.0.0.0', 0, function(sock)
  sock:read_start(function(err, chunk)
    assert(not err, err)  -- Check for errors.
    if chunk then
      sock:write(chunk)  -- Echo received messages to the channel.
    else  -- EOF (stream closed).
      sock:close()  -- Always close handles to avoid leaks.
    end
  end)
end)
print('TCP echo-server listening on port: '..server:getsockname().port)
```

### Multithreading (`lua-loop-threading`)

Plugins can use `luv`'s threading APIs (e.g., `vim.uv.new_thread`) for work in separate OS-level threads.

**Key Facts:**

* **Separate State:** Each thread has its own Lua interpreter state.
* **No Direct Editor Access:** Threads cannot directly access Lua globals on the main thread or the editor state (buffers, windows, etc.).
* **Available Stdlib Subset:** A subset of `vim.*` is available in threads, including:
  * `vim.uv` (with a separate event loop per thread)
  * `vim.mpack` and `vim.json` (for inter-thread serialization)
  * `require` (using the global `package.path`)
  * `print()` and `vim.inspect`
  * `vim.diff`
  * Most utility functions in `vim.*` that work with pure Lua values (e.g., `vim.split`, `vim.tbl_*`, `vim.list_*`).
* `vim.is_thread()` returns `true` from a non-main thread.

---

## `vim.hl`

Provides functions for Neovim's highlighting system.

##### `vim.hl.on_yank({opts})`

Highlights yanked text during a `TextYankPost` event.

**Parameters:**

* `opts` (`table?`): Optional parameters.
  * `higroup` (`string`): Highlight group (default: `"IncSearch"`).
  * `timeout` (`integer`): Time in milliseconds before highlight clears (default: `150`).
  * `on_macro` (`boolean`): Highlight when executing macro (default: `false`).
  * `on_visual` (`boolean`): Highlight when yanking visual selection (default: `true`).
  * `event` (`table`): Event structure (default: `vim.v.event`).
  * `priority` (`integer`): Priority (default: `vim.hl.priorities.user`).

**Example:**
Add to `init.vim` for yank highlighting:

```vimscript
autocmd TextYankPost * silent! lua vim.hl.on_yank {higroup='Visual', timeout=300}
```

##### `vim.hl.priorities`

Table containing default highlight priorities:

```lua
{
  syntax = 50,         -- standard syntax highlighting
  treesitter = 100,    -- treesitter-based highlighting
  semantic_tokens = 125, -- LSP semantic token highlighting
  diagnostics = 150,   -- code analysis (diagnostics)
  user = 200,          -- user-triggered highlights (LSP document symbols, on_yank)
}
```

##### `vim.hl.range({bufnr}, {ns}, {higroup}, {start}, {finish}, {opts})`

Applies a highlight group to a range of text.

**Parameters:**

* `bufnr` (`integer`): Buffer number.
* `ns` (`integer`): Namespace ID.
* `higroup` (`string`): Highlight group name.
* `start` (`[integer,integer]|string`): Start of region as `(line, column)` tuple or `getpos()` string.
* `finish` (`[integer,integer]|string`): End of region as `(line, column)` tuple or `getpos()` string.
* `opts` (`table?`): Optional fields.
  * `regtype` (`string`): Type of range (default: `'v'` for charwise). See `getregtype()`.
  * `inclusive` (`boolean`): Whether the range is end-inclusive (default: `false`).
  * `priority` (`integer`): Highlight priority (default: `vim.hl.priorities.user`).
  * `timeout` (`integer`): Time in ms before highlight clears (default: `-1` for no timeout).

**Returns:** (`uv.uv_timer_t?`, `fun()`)

* `range_timer`: A timer managing the highlight's remaining time.
* `range_clear`: A function to manually clear the highlight. `nil` if `timeout` is not specified.

---

## `vim.diff`

Provides functions for running diff on strings.

##### `vim.diff({a}, {b}, {opts})`

Runs a diff on strings `{a}` and `{b}`. All returned indices are 1-based.

**Parameters:**

* `a` (`string`): First string.
* `b` (`string`): Second string.
* `opts` (`table?`): Optional parameters.
  * `on_hunk` (`fun(start_a: integer, count_a: integer, start_b: integer, count_b: integer): integer?`): Invoked for each hunk. Return a negative number to cancel remaining callbacks.
  * `result_type` (`'unified'|'indices'`): Form of the returned diff (default: `'unified'`).
    * `'unified'`: String in unified format.
    * `'indices'`: Array of hunk locations (ignored if `on_hunk` is used).
  * `linematch` (`boolean|integer`): Run linematch on xdiff hunks. When integer, only hunks up to this size are processed. Requires `result_type = 'indices'`.
  * `algorithm` (`'myers'|'minimal'|'patience'|'histogram'`): Diff algorithm (default: `'myers'`).
  * `ctxlen` (`integer`): Context length.
  * `interhunkctxlen` (`integer`): Inter-hunk context length.
  * `ignore_whitespace` (`boolean`): Ignore all whitespace.
  * `ignore_whitespace_change` (`boolean`): Ignore whitespace changes.
  * `ignore_whitespace_change_at_eol` (`boolean`): Ignore EOL whitespace changes.
  * `ignore_cr_at_eol` (`boolean`): Ignore carriage returns at EOL.
  * `ignore_blank_lines` (`boolean`): Ignore blank lines.
  * `indent_heuristic` (`boolean`): Use indent heuristic for internal diff library.

**Returns:** (`string|integer[][]?`)

* Based on `opts.result_type`. `nil` if `opts.on_hunk` is given.

**Examples:**

```lua
vim.diff('a\n', 'b\nc\n')
-- =>
-- @@ -1 +1,2 @@
-- -a
-- +b
-- +c

vim.diff('a\n', 'b\nc\n', {result_type = 'indices'})
-- =>
-- {
--   {1, 1, 1, 2}
-- }
```

---

## `vim.mpack`

Provides encoding and decoding of Lua objects to/from Msgpack-encoded strings. Supports `vim.NIL` and `vim.empty_dict()`.

##### `vim.mpack.decode({str})`

Decodes (`unpacks`) a Msgpack-encoded string to a Lua object.

**Parameters:**

* `str` (`string`)

**Returns:** (`any`)

##### `vim.mpack.encode({obj})`

Encodes (`packs`) a Lua object as Msgpack into a Lua string.

**Parameters:**

* `obj` (`any`)

**Returns:** (`string`)

---

## `vim.json`

Provides encoding and decoding of Lua objects to/from JSON-encoded strings. Supports `vim.NIL` and `vim.empty_dict()`.

##### `vim.json.decode({str}, {opts})`

Decodes (`unpacks`) a JSON-encoded string to a Lua object.

**Key Facts:**

* JSON `"null"` decodes as `vim.NIL` (configurable via `opts`).
* Empty JSON object `{}` decodes as `vim.empty_dict()`.
* Empty JSON array `[]` decodes as `{}` (empty Lua table).

**Parameters:**

* `str` (`string`): Stringified JSON data.
* `opts` (`table?`): Options table.
  * `luanil` (`table`):
    * `object` (`boolean`): If `true`, converts `null` in JSON objects to Lua `nil` instead of `vim.NIL`.
    * `array` (`boolean`): If `true`, converts `null` in JSON arrays to Lua `nil` instead of `vim.NIL`.

**Returns:** (`any`)

**Example:**

```lua
vim.print(vim.json.decode('{"bar":[],"foo":{},"zub":null}'))
-- { bar = {}, foo = vim.empty_dict(), zub = vim.NIL }
```

##### `vim.json.encode({obj}, {opts})`

Encodes (`packs`) a Lua object as JSON into a Lua string.

**Parameters:**

* `obj` (`any`)
* `opts` (`table?`): Options table.
  * `escape_slash` (`boolean`): (default: `false`) Escapes `/` characters in string values.

**Returns:** (`string`)

---

## `vim.base64`

Provides Base64 encoding and decoding.

##### `vim.base64.decode({str})`

Decodes a Base64 encoded string.

**Parameters:**

* `str` (`string`): Base64 encoded string.

**Returns:** (`string`) Decoded string.

##### `vim.base64.encode({str})`

Encodes a string using Base64.

**Parameters:**

* `str` (`string`): String to encode.

**Returns:** (`string`) Encoded string.

---

## `vim.spell`

Provides functions for spell checking.

##### `vim.spell.check({str})`

Checks `{str}` for spelling errors, similar to Vimscript's `spellbadword()`.
**Note:** Behavior depends on buffer-local options like `'spelllang'`, `'spellfile'`, `'spellcapcheck'`, and `'spelloptions'`. Consider calling with `nvim_buf_call()`.

**Parameters:**

* `str` (`string`)

**Returns:** (`[string, 'bad'|'rare'|'local'|'caps', integer][]`)
List of tuples:

* Badly spelled word.
* Type of error (`"bad"`, `"rare"`, `"local"`, `"caps"`).
* Starting position (byte index) of the word in `{str}`.

**Example:**

```lua
vim.spell.check("the quik brown fox")
-- =>
-- {
--     {'quik', 'bad', 5}
-- }
```

---

## `vim` Module

This section details various core functions and values available directly under the `vim` global table.

##### `vim.builtin`

Alias for `vim.api`.

##### `vim.api.{func}({...})` (`vim.api`)

Invokes an Nvim API function `{func}` with arguments `{...}`.

**Example:**

```lua
print(tostring(vim.api.nvim_get_current_line()))
```

##### `vim.NIL`

A special value representing `NIL` in RPC and `v:null` in Vimscript conversion. Lua `nil` cannot be used in Lua tables for `Dictionary` or `Array` types, as it's treated as missing.

##### `vim.type_idx`

Used in `lua-special-tbl` to explicitly specify the type of a table during conversion to Vimscript/API types, especially for empty tables or forcing integral numbers to floats.

##### `vim.val_idx`

Used with `vim.type_idx` to represent floating-point values in tables.

**Example:**

```lua
{
  [vim.type_idx] = vim.types.float,
  [vim.val_idx] = 1.0,
}
```

##### `vim.types`

Table with possible values for `vim.type_idx`, including `float`, `array`, and `dictionary`. It maps string names to internal values and vice-versa.
**Note:** Values in `vim.types` might change, and other types might be added.

##### `vim.log.levels`

Table defining log levels for `vim.notify()` and similar functions:

* `vim.log.levels.DEBUG`
* `vim.log.levels.ERROR`
* `vim.log.levels.INFO`
* `vim.log.levels.TRACE`
* `vim.log.levels.WARN`
* `vim.log.levels.OFF`

##### `vim.empty_dict()`

Creates a special empty table (with a metatable) that Nvim converts to an empty dictionary. By default, `{}` converts to a list/array.
**Note:** If numeric keys are present, Nvim ignores the metatable and converts to a list/array.

**Returns:** (`table`)

##### `vim.iconv({str}, {from}, {to})`

Converts text `{str}` from one encoding `{from}` to another `{to}`. Returns `nil` on failure, `?` for unconvertible characters. Encoding names follow `iconv()` library.

**Parameters:**

* `str` (`string`): Text to convert.
* `from` (`string`): Source encoding.
* `to` (`string`): Target encoding.

**Returns:** (`string?`): Converted string, or `nil`.

##### `vim.in_fast_event()`

Returns `true` if code is running in a "fast" event handler (e.g., `lua-loop-callbacks`), where most API functions are disabled.

**Returns:** (`boolean`)

##### `vim.rpcnotify({channel}, {method}, {...})`

Sends an RPC event to `{channel}` immediately. If `channel` is 0, broadcasts to all channels. Works in `api-fast` contexts.

**Parameters:**

* `channel` (`integer`)
* `method` (`string`)
* `...` (`any?`)

##### `vim.rpcrequest({channel}, {method}, {...})`

Sends an RPC request to `{channel}` and blocks until a response. `NIL` values in return are `vim.NIL`.

**Parameters:**

* `channel` (`integer`)
* `method` (`string`)
* `...` (`any?`)

##### `vim.schedule({fn})`

Schedules function `{fn}` to be invoked by the main event loop soon. Useful for avoiding `textlock` or other temporary restrictions.

**Parameters:**

* `fn` (`fun()`)

##### `vim.str_utf_end({str}, {index})`

Gets the byte distance from `index` to the end of the codepoint it points to.

**Examples:**

```lua
vim.str_utf_end('æ', 2) -- Returns 0 ('æ' is '\xc3\xa6', index 2 is last byte)
vim.str_utf_end('æ', 1) -- Returns 1 (index 1 is penultimate byte)
```

**Parameters:**

* `str` (`string`)
* `index` (`integer`)

**Returns:** (`integer`)

##### `vim.str_utf_pos({str})`

Gets a list of starting byte positions for each UTF-8 codepoint in `{str}`. Embedded NUL bytes terminate the string.

**Parameters:**

* `str` (`string`)

**Returns:** (`integer[]`)

##### `vim.str_utf_start({str}, {index})`

Gets the byte distance from `index` to the start of the codepoint it points to.

**Examples:**

```lua
vim.str_utf_start('æ', 1) -- Returns 0 (index 1 is first byte)
vim.str_utf_start('æ', 2) -- Returns -1 (index 2 is second byte)
```

**Parameters:**

* `str` (`string`)
* `index` (`integer`)

**Returns:** (`integer`)

##### `vim.stricmp({a}, {b})`

Compares strings case-insensitively.

**Parameters:**

* `a` (`string`)
* `b` (`string`)

**Returns:** (`0|1|-1`): 0 if equal, 1 if `a > b`, -1 if `a < b`.

##### `vim.ui_attach({ns}, {opts}, {callback})`

**WARNING:** Experimental/Unstable feature.
Subscribes to UI events, similar to `nvim_ui_attach()`, but receives events in a Lua callback. Used for implementing screen elements like `popupmenu` or message handling in Lua.

**Key Facts:**

* `callback` receives event name and parameters.
* Callbacks for `msg_show` events are in `api-fast` context; message display should be scheduled.
* Excessive errors in callback result in forced detachment.
* Considered experimental, usability may vary. Expected for `cmdheight=0` use.

**Example (stub for `ui-popupmenu`):**

```lua
ns = vim.api.nvim_create_namespace('my_fancy_pum')
vim.ui_attach(ns, {ext_popupmenu=true}, function(event, ...)
  if event == 'popupmenu_show' then
    local items, selected, row, col, grid = ...
    print('display pum ', #items)
  elseif event == 'popupmenu_select' then
    local selected = ...
    print('selected', selected)
  elseif event == 'popupmenu_hide' then
    print('FIN')
  end
end)
```

**Parameters:**

* `ns` (`integer`): Namespace ID.
* `opts` (`table<string, any>`): Optional parameters.
  * `ext_…` (`boolean`): Any of `ui-ext-options` (e.g., `ext_popupmenu=true`).
  * `set_cmdheight` (`boolean`): If `false`, avoids setting `'cmdheight'` to 0 when `ext_messages` is enabled.
* `callback` (`fun(event: string, ...): any`): Function called for each UI event. A truthy return value signals the event is handled and not propagated.

##### `vim.ui_detach({ns})`

Detaches a callback previously attached with `vim.ui_attach()`.

**Parameters:**

* `ns` (`integer`): Namespace ID.

##### `vim.wait({time}, {callback}, {interval}, {fast_only})`

Waits for `{time}` milliseconds, optionally until `{callback}` returns `true`. Nvim still processes other events. Cannot be called in `api-fast` events.

**Parameters:**

* `time` (`integer`): Milliseconds to wait.
* `callback` (`fun(): boolean?`): Optional. Waits until it returns `true`.
* `interval` (`integer?`): (Approximate) milliseconds between polls (default: `200`).
* `fast_only` (`boolean?`): If `true`, only `api-fast` events are processed.

**Returns:** (`boolean`, `-1|-2?`)

* `true`, `nil`: If `callback` returns `true` within `time`.
* `false`, `-1`: If `callback` never returns `true`.
* `false`, `-2`: If `callback` is interrupted.
* Errors raised by `callback` are propagated.

**Examples:**

```lua
-- Wait for 100 ms, allowing other events to process
vim.wait(100, function() end)

-- Wait for 100 ms or until global variable set.
vim.wait(100, function() return vim.g.waiting_for_var end)

-- Wait for 1 second or until global variable set, checking every ~500 ms
vim.wait(1000, function() return vim.g.waiting_for_var end, 500)

-- Example with defer_fn
vim.defer_fn(function() vim.g.timer_result = true end, 100)
if vim.wait(10000, function() return vim.g.timer_result end) then
  print('Only waiting a little bit of time!') -- Prints after ~100ms
end
```

---

## Lua-Vimscript Bridge (`lua-vimscript`)

Nvim Lua provides a bridge to Vimscript variables, functions, commands, and options.

**Subtle Fact:** Objects passed over this bridge are **COPIED (marshalled)**; there are no references. Modifying a copied Lua list in Vimscript via `vim.fn.remove()` does **not** modify the original Lua list.

**Example: Copying Behavior**

```lua
local list = { 1, 2, 3 }
vim.fn.remove(list, 0)
vim.print(list)  --> "{ 1, 2, 3 }"
```

##### `vim.call({func}, {...})`

Invokes a Vimscript function or user-defined function `{func}` with arguments `{...}`. Equivalent to `vim.fn[func]({...})`.

##### `vim.cmd({command})`

Executes Vimscript (Ex commands). See `vim.cmd()` section below.

##### `vim.fn.{func}({...})`

Invokes a Vimscript function or user-defined function `{func}` with arguments `{...}`. For autoload functions, use `vim.fn['some#function']({...})`.
**Key Facts:**

* Directly converts between Vim and Lua objects (e.g., Vim floats become Lua numbers).
* Empty lists and dictionaries are represented by an empty table.
* `v:null` values in return are `vim.NIL`.
* Keys in `vim.fn` are generated lazily (only enumerated after being called at least once).
* Most functions cannot run in `api-fast` callbacks.

### Lua Vim Variables (`lua-vim-variables`)

The Vim global dictionaries `g:`, `w:`, `b:`, `t:`, `v:` are accessible and modifiable through `vim.*` Lua tables.

**Subtle Fact:** Setting dictionary fields directly (e.g., `vim.g.my_dict.field1 = 'value'`) **does not work** because indexing returns a copy. The entire dictionary must be retrieved, modified, and then reassigned.

**Example: Correctly Modifying a Vimscript Dictionary from Lua**

```lua
vim.g.my_dict.field1 = 'value'  -- DOES NOT WORK as intended
local my_dict = vim.g.my_dict   -- Get a copy
my_dict.field1 = 'value'        -- Modify the copy
vim.g.my_dict = my_dict         -- Assign the modified copy back
```

##### `vim.g`

Global (`g:`) editor variables. Unset keys return `nil`.

**Example:**

```lua
vim.g.foo = 5     -- Set g:foo
print(vim.g.foo)  -- Get g:foo
vim.g.foo = nil   -- Delete g:foo (:unlet)
```

##### `vim.b`

Buffer-scoped (`b:`) variables for the current buffer. Can be indexed with an integer (`vim.b[2].foo`) for specific buffers. Invalid or unset keys return `nil`.

**Example:**

```lua
local bufnr = vim.api.nvim_get_current_buf()
vim.b[bufnr].buflisted = true    -- same as vim.bo.buflisted = true (if current)
print(vim.bo.comments)
-- print(vim.bo.baz)              -- error: invalid key
```

##### `vim.w`

Window-scoped (`w:`) variables for the current window. Can be indexed with an integer for specific windows. Invalid or unset keys return `nil`.

##### `vim.t`

Tabpage-scoped (`t:`) variables for the current tabpage. Can be indexed with an integer for specific tabpages. Invalid or unset keys return `nil`.

##### `vim.v`

`v:` variables. Invalid or unset keys return `nil`.

### Lua Options (`lua-vim-options`)

Vim options can be accessed via `vim.o`, `vim.bo`, `vim.wo`, and `vim.go`.

* **`vim.o` (`lua-vim-set`):** Behaves like Vimscript `:set`.
* **`vim.bo`:** Buffer-scoped options.
* **`vim.wo`:** Window-scoped options.
* **`vim.go` (`lua-vim-setglobal`):** Accesses *global* value of a global-local option, like `:setglobal`.

**Examples:**

```lua
vim.o.number = true                           -- set number
vim.o.wildignore = '*.o,*.a,__pycache__'      -- set wildignore=...
vim.go.cmdheight = 4                          -- setglobal cmdheight=4
print(vim.o.columns)
-- print(vim.o.foo)                           -- error: invalid key
```

##### `vim.bo[{bufnr}]`

Get or set buffer-scoped options. `{bufnr}` defaults to current buffer if omitted.

**Example:**

```lua
local bufnr = vim.api.nvim_get_current_buf()
vim.bo[bufnr].buflisted = true    -- same as vim.bo.buflisted = true
print(vim.bo.comments)
-- print(vim.bo.baz)                 -- error: invalid key
```

##### `vim.env`

Environment variables defined in the editor session. See `expand-env` and `:let-environment`. Invalid or unset keys return `nil`.

**Example:**

```lua
vim.env.FOO = 'bar'
print(vim.env.TERM)
```

##### `vim.wo[{winid}][{bufnr}]`

Get or set window-scoped options. `{winid}` defaults to current window. `{bufnr}` is only supported with `0` (current buffer in the window).

**Example:**

```lua
local winid = vim.api.nvim_get_current_win()
vim.wo[winid].number = true    -- same as vim.wo.number = true
print(vim.wo.foldmarker)
-- print(vim.wo.quux)             -- error: invalid key
vim.wo[winid][0].spell = false -- like ':setlocal nospell'
```

### `vim.opt` (Option Interface)

`vim.opt` provides a special interface for conveniently interacting with list- and map-style options as Lua tables, offering object-oriented methods for adding and removing entries. `vim.opt_local` and `vim.opt_global` provide local and global variants.

**Examples:**

**Setting list-style option:**

```lua
-- Vimscript:
-- set wildignore=*.o,*.a,__pycache__

-- Lua (vim.o):
vim.o.wildignore = '*.o,*.a,__pycache__'

-- Lua (vim.opt):
vim.opt.wildignore = { '*.o', '*.a', '__pycache__' }
```

**Appending to list-style option (`:set+=`):**

```lua
vim.opt.wildignore:append { "*.pyc", "node_modules" }
-- Equivalent to: vim.opt.wildignore = vim.opt.wildignore + 'j'
```

**Prepending to list-style option (`:set^=`):**

```lua
vim.opt.wildignore:prepend { "new_first_value" }
-- Equivalent to: vim.opt.wildignore = vim.opt.wildignore ^ '*.o'
```

**Removing from list-style option (`:set-=`):**

```lua
vim.opt.wildignore:remove { "node_modules" }
-- Equivalent to: vim.opt.wildignore = vim.opt.wildignore - '*.pyc'
```

**Setting map-style option:**

```lua
-- Vimscript:
-- set listchars=space:_,tab:>~

-- Lua (vim.o):
vim.o.listchars = 'space:_,tab:>~'

-- Lua (vim.opt):
vim.opt.listchars = { space = '_', tab = '>~' }
```

**Getting option values:**
`vim.opt` returns an Option object, not the value. Use `vim.opt:get()` to retrieve the value.

**Example: Getting list-style option:**

```lua
-- Vimscript:
-- echo wildignore

-- Lua (vim.o):
print(vim.o.wildignore)

-- Lua (vim.opt):
vim.cmd [[set wildignore=*.pyc,*.o]]
vim.print(vim.opt.wildignore:get())
-- { "*.pyc", "*.o", }

for _, ignore_pattern in ipairs(vim.opt.wildignore:get()) do
    print("Will ignore:", ignore_pattern)
end
```

**Example: Getting map-style option:**

```lua
vim.cmd [[set listchars=space:_,tab:>~]]
vim.print(vim.opt.listchars:get())
--  { space = "_", tab = ">~", }

for char, representation in pairs(vim.opt.listchars:get()) do
    print(char, "=>", representation)
end
```

**Example: Getting flag-style option (set returns `set` as table with boolean `true` values):**

```lua
vim.cmd [[set formatoptions=njtcroql]]
vim.print(vim.opt.formatoptions:get())
-- { n = true, j = true, c = true, ... }

local format_opts = vim.opt.formatoptions:get()
if format_opts.j then
    print("J is enabled!")
end
```

`vim.opt_local` and `vim.opt_global` replicate `:setlocal` and `:setglobal` behavior respectively.

---

## Lua module: `vim`

Contains general-purpose Neovim functions.

##### `vim.cmd({command})`

Executes Vimscript (Ex commands).

**Key Features:**

* **String form:** Supports multiline Vimscript, behaves like `:source` (`nvim_exec2()`).
* **Table form:** Executes a single command (`nvim_cmd()`). Allows specifying `args` and `bang`.
* **Indexed access:** Can be indexed with a command name to get a function, allowing `vim.cmd.echo(...)`.

**Examples:**

```lua
-- Single command:
vim.cmd('echo 42')

-- Multiline script:
vim.cmd([[
  augroup my.group
    autocmd!
    autocmd FileType c setlocal cindent
  augroup END
]])

-- Ex command :echo "foo" (string literals must be double-quoted):
vim.cmd('echo "foo"')
vim.cmd { cmd = 'echo', args = { '"foo"' } }
vim.cmd.echo({ args = { '"foo"' } })
vim.cmd.echo('"foo"')

-- Ex command :write! myfile.txt:
vim.cmd('write! myfile.txt')
vim.cmd { cmd = 'write', args = { 'myfile.txt' }, bang = true }
vim.cmd.write { args = { 'myfile.txt' }, bang = true }
vim.cmd.write { 'myfile.txt', bang = true }

-- Ex command :vertical resize +2:
vim.cmd.resize({ '+2', mods = { vertical = true } })
```

##### `vim.defer_fn({fn}, {timeout})`

Defers calling `{fn}` until `{timeout}` milliseconds have passed. Useful for one-shot timers.
**Note:** `{fn}` is automatically `vim.schedule_wrap()`ped, making API functions safe to call.

**Parameters:**

* `fn` (`function`): Callback function.
* `timeout` (`integer`): Milliseconds to wait.

**Returns:** (`table`) A `luv` timer object.

##### `vim.deprecate({name}, {alternative}, {version}, {plugin}, {backtrace})`

Displays a deprecation message to the user.

**Parameters:**

* `name` (`string`): Deprecated feature name.
* `alternative` (`string?`): Suggested alternative.
* `version` (`string`): Version when the feature will be removed.
* `plugin` (`string?`): Owning plugin name (default: `"Nvim"`).
* `backtrace` (`boolean?`): Prints backtrace (default: `true`).

**Returns:** (`string?`): The deprecated message, or `nil` if no message was shown.

##### `vim.inspect(x, opts?)`

Gets a human-readable representation of the given object (`x`).

**Returns:** (`string`)

**See also:** `vim.print()`, `kikito/inspect.lua`, `mpeterv/vinspect`.

##### `vim.keycode({str})`

Translates keycodes.

**Example:**

```lua
local k = vim.keycode
vim.g.mapleader = k'<bs>'
```

**Parameters:**

* `str` (`string`): String to be converted.

**Returns:** (`string`)

**See also:** `nvim_replace_termcodes()`.

##### `vim.lua_omnifunc({find_start})`

Omnifunc for completing Lua values from the runtime Lua interpreter, similar to `:lua` command completion. Activate with `set omnifunc=v:lua.vim.lua_omnifunc` in a Lua buffer.

**Parameters:**

* `find_start` (`1|0`)

##### `vim.notify({msg}, {level}, {opts})`

Displays a notification to the user. Can be overridden by plugins for custom notification providers (e.g., system notifications). By default, writes to `:messages`.

**Parameters:**

* `msg` (`string`): Content of the notification.
* `level` (`integer?`): One of `vim.log.levels`.
* `opts` (`table?`): Optional parameters (unused by default).

##### `vim.notify_once({msg}, {level}, {opts})`

Displays a notification only once. Subsequent calls with the same message are suppressed.

**Parameters:**

* `msg` (`string`): Content of the notification.
* `level` (`integer?`): One of `vim.log.levels`.
* `opts` (`table?`): Optional parameters (unused by default).

**Returns:** (`boolean`): `true` if message was displayed, `false` otherwise.

##### `vim.on_key({fn}, {ns_id}, {opts})`

Adds a Lua function `{fn}` as a listener to every input key, after mappings are applied but before further processing.

**Key Notes:**

* `{fn}` is removed on error.
* `{fn}` is not invoked recursively if it consumes input itself.
* `{fn}` is not cleared by `nvim_buf_clear_namespace()`.

**Parameters:**

* `fn` (`fun(key: string, typed: string): string??`): Function invoked. `key` is after mappings, `typed` is before. Returns empty string to discard `key`. If `nil`, removes callback for `ns_id`.
* `ns_id` (`integer?`): Namespace ID. If `nil` or `0`, generates a new `nvim_create_namespace()` ID.
* `opts` (`table?`): Optional parameters.

**Returns:** (`integer`): Namespace ID associated with `{fn}`, or count of all callbacks if called without arguments.

**See also:** `keytrans()`.

##### `vim.paste({lines}, {phase})`

Paste handler invoked by `nvim_paste()`. Not to be called directly; use `nvim_paste()` which handles redo and invokes this.

**Example: Removing ANSI color codes on paste**

```lua
vim.paste = (function(overridden)
  return function(lines, phase)
    for i,line in ipairs(lines) do
      -- Scrub ANSI color codes from paste input.
      lines[i] = line:gsub('\27%[[0-9;mK]+', '')
    end
    return overridden(lines, phase)
  end
end)(vim.paste)
```

**Parameters:**

* `lines` (`string[]`): `readfile()`-style list of lines.
* `phase` (`-1|1|2|3`):
  * `-1`: "Non-streaming" paste (all lines provided at once).
  * `1`: Stream starts (exactly once).
  * `2`: Stream continues (zero or more times).
  * `3`: Stream ends (exactly once).

**Returns:** (`boolean`): `false` if client should cancel paste.

**See also:** `paste`.

##### `vim.print({...})`

"Pretty prints" the given arguments and returns them unmodified.

**Example:**

```lua
local hl_normal = vim.print(vim.api.nvim_get_hl(0, { name = 'Normal' }))
```

**Parameters:**

* `...` (`any`)

**Returns:** (`any`) The given arguments.

**See also:** `vim.inspect()`, `:=`.

##### `vim.schedule_wrap({fn})`

Returns a function that calls `{fn}` via `vim.schedule()`. All arguments are passed through.

**Example:**

```lua
function notify_readable(_err, readable)
  vim.notify("readable? " .. tostring(readable))
end
vim.uv.fs_access(vim.fn.stdpath("config"), "R", vim.schedule_wrap(notify_readable))
```

**Parameters:**

* `fn` (`function`)

**Returns:** (`function`)

**See also:** `lua-loop-callbacks`, `vim.schedule()`, `vim.in_fast_event()`.

##### `vim.str_byteindex({s}, {encoding}, {index}, {strict_indexing})`

Converts a UTF-32, UTF-16, or UTF-8 `{index}` to a byte index.
If `strict_indexing` is `false`, out-of-range indices return byte length instead of error. Invalid UTF-8 and NUL are handled like `vim.str_utfindex()`. UTF-16 sequence middle indices are rounded up.

**Parameters:**

* `s` (`string`)
* `encoding` (`"utf-8"|"utf-16"|"utf-32"`)
* `index` (`integer`)
* `strict_indexing` (`boolean?`): Default: `true`.

**Returns:** (`integer`)

##### `vim.str_utfindex({s}, {encoding}, {index}, {strict_indexing})`

Converts a byte index to a UTF-32, UTF-16, or UTF-8 codepoint index. If `{index}` is not supplied, string length is used. All indices are zero-based.
If `strict_indexing` is `false`, out-of-range indices return string length instead of error. Invalid UTF-8 bytes and embedded surrogates count as one codepoint. UTF-8 sequence middle indices are rounded up.

**Parameters:**

* `s` (`string`)
* `encoding` (`"utf-8"|"utf-16"|"utf-32"`)
* `index` (`integer?`)
* `strict_indexing` (`boolean?`): Default: `true`.

**Returns:** (`integer`)

##### `vim.system({cmd}, {opts}, {on_exit})`

Runs a system command. Throws an error if `cmd` cannot be run.

**Parameters:**

* `cmd` (`string[]`): Command to execute.
* `opts` (`vim.SystemOpts?`): Options.
  * `cwd` (`string`): Current working directory for subprocess.
  * `env` (`table<string,string>`): Environment variables. Inherits current, plus `NVIM` set to `v:servername`.
  * `clear_env` (`boolean`): If `true`, `env` defines job environment exactly, no merging.
  * `stdin` (`string|string[]|boolean`): If `true`, pipe to stdin opened. If string/table, written to stdin and closed. Default: `false`.
  * `stdout` (`boolean|function`): Handle stdout. Function signature: `fun(err: string, data: string)`. Default: `true`.
  * `stderr` (`boolean|function`): Handle stderr. Function signature: `fun(err: string, data: string)`. Default: `true`.
  * `text` (`boolean`): Handle stdout/stderr as text (`\r\n` replaced with `\n`).
  * `timeout` (`integer`): Time limit. Process sent TERM (15) on timeout, exit code 124.
  * `detach` (`boolean`): If `true`, spawn detached (process group leader). Child keeps running after parent exits. Parent must call `uv.unref()` on child handle to avoid keeping event loop alive.
* `on_exit` (`fun(out: vim.SystemCompleted)?`): Callback when subprocess exits. If provided, command runs asynchronously. Receives `SystemCompleted` object.

**Returns:** (`vim.SystemObj`)
Object with fields:

* `cmd` (`string[]`): Command name and arguments.
* `pid` (`integer`): Process ID.
* `wait` (`fun(timeout: integer|nil): SystemCompleted`): Waits for process to complete. Sends KILL (9) on timeout, exit code 124. Cannot be called in `api-fast`.
  * `SystemCompleted` object fields: `code` (`integer`), `signal` (`integer`), `stdout` (`string`, `nil` if `stdout` argument passed), `stderr` (`string`, `nil` if `stderr` argument passed).
* `kill` (`fun(signal: integer|string)`)
* `write` (`fun(data: string|nil)`): Requires `stdin=true`. Pass `nil` to close stream.
* `is_closing` (`fun(): boolean`)

**Examples:**

```lua
local on_exit = function(obj)
  print(obj.code)
  print(obj.signal)
  print(obj.stdout)
  print(obj.stderr)
end

-- Runs asynchronously:
vim.system({'echo', 'hello'}, { text = true }, on_exit)

-- Runs synchronously:
local obj = vim.system({'echo', 'hello'}, { text = true }):wait()
-- { code = 0, signal = 0, stdout = 'hello\n', stderr = '' }
```

---

## Lua module: `vim.inspector`

Provides functions for inspecting buffer content at a given position.

##### `vim.inspect_pos({bufnr}, {row}, {col}, {filter})`

Gets all items (highlights, extmarks) at a given buffer position. Can be pretty-printed with `:Inspect!`.

**Parameters:**

* `bufnr` (`integer?`): Defaults to current buffer.
* `row` (`integer?`): 0-based row. Defaults to cursor row.
* `col` (`integer?`): 0-based column. Defaults to cursor column.
* `filter` (`table?`): Key-value pairs to filter items.
  * `syntax` (`boolean`): Include syntax highlights (default: `true`).
  * `treesitter` (`boolean`): Include treesitter highlights (default: `true`).
  * `extmarks` (`boolean|"all"`): Include extmarks. `"all"` includes those without `hl_group` (default: `true`).
  * `semantic_tokens` (`boolean`): Include LSP semantic token highlights (default: `true`).

**Returns:** (`table`) A table with `treesitter`, `syntax`, `semantic_tokens`, `extmarks` lists, and `buffer`, `row`, `col` used. Items in "traversal order".

##### `vim.show_pos({bufnr}, {row}, {col}, {filter})`

Shows all items at a given buffer position. Can be shown with `:Inspect`.

**Example:** Bind to `zS` in Normal mode:

```lua
vim.keymap.set('n', 'zS', vim.show_pos)
```

**Parameters:**

* `bufnr` (`integer?`): Defaults to current buffer.
* `row` (`integer?`): 0-based row. Defaults to cursor row.
* `col` (`integer?`): 0-based column. Defaults to cursor column.
* `filter` (`table?`): Same filtering options as `vim.inspect_pos()`.

---

## `vim.Ringbuf`

A ring buffer data structure.

**Fields:**

* `clear` (`fun()`): See `Ringbuf:clear()`.
* `push` (`fun(item: T)`): See `Ringbuf:push()`.
* `pop` (`fun(): T?`): See `Ringbuf:pop()`.
* `peek` (`fun(): T?`): See `Ringbuf:peek()`.

##### `Ringbuf:clear()`

Clears all items from the ring buffer.

##### `Ringbuf:peek()`

Returns the first unread item without removing it.

**Returns:** (`any?`)

##### `Ringbuf:pop()`

Removes and returns the first unread item.

**Returns:** (`any?`)

##### `Ringbuf:push({item})`

Adds an item. If the buffer is full, overrides the oldest item.

**Parameters:**

* `item` (`any`)

##### `vim.ringbuf({size})`

Creates a `Ringbuf` instance.

**Example:**

```lua
local ringbuf = vim.ringbuf(4)
ringbuf:push("a")
ringbuf:push("b")
ringbuf:push("c")
ringbuf:push("d")
ringbuf:push("e")    -- overrides "a"
print(ringbuf:pop()) -- returns "b"
print(ringbuf:pop()) -- returns "c"
-- Can be used as iterator. Pops remaining items:
for val in ringbuf do
  print(val)
end
```

**Parameters:**

* `size` (`integer`)

**Returns:** (`vim.Ringbuf`)

---

## `vim.deep_equal({a}, {b})`

Deeply compares two values for equality. Tables are compared recursively unless they both provide an `eq` metamethod. Other types use `==`.

**Parameters:**

* `a` (`any`): First value.
* `b` (`any`): Second value.

**Returns:** (`boolean`): `true` if values are equal, `false` otherwise.

---

## `vim.deepcopy({orig}, {noref})`

Returns a deep copy of the given object. Tables are copied recursively. Functions are copied by reference. Userdata and threads are not copied and will throw an error.

**Subtle Fact:** `noref=true` is more performant for tables with unique fields. `noref=false` (default) is more performant for tables that reuse fields; cyclic references can cause `deepcopy()` to fail if `noref=true`.

**Parameters:**

* `orig` (`table`): Table to copy.
* `noref` (`boolean?`): If `false` (default), contained tables are copied once, all references point to that copy. If `true`, every occurrence of a table results in a new copy.

**Returns:** (`table`): Table of copied keys and (nested) values.

---

## `vim.defaulttable({createfn})`

Creates a table where missing keys are provided by `createfn` (similar to Python's `defaultdict`). If `createfn` is `nil`, it defaults to `defaulttable()` itself, creating nested tables.

**Example:**

```lua
local a = vim.defaulttable()
a.b.c = 1
```

**Parameters:**

* `createfn` (`fun(key:any):any?`): Provides value for a missing key.

**Returns:** (`table`): Empty table with `__index` metamethod.

---

## `vim.endswith({s}, {suffix})`

Tests if string `s` ends with `suffix`.

**Parameters:**

* `s` (`string`): String.
* `suffix` (`string`): Suffix to match.

**Returns:** (`boolean`): `true` if `suffix` is a suffix of `s`.

---

## `vim.gsplit({s}, {sep}, {opts})`

Gets an iterator that splits a string at each instance of a separator in a "lazy" fashion (unlike `vim.split()`).

**Parameters:**

* `s` (`string`): String to split.
* `sep` (`string`): Separator or pattern.
* `opts` (`table?`): Keyword arguments.
  * `plain` (`boolean`): Use `sep` literally (as in `string.find`).
  * `trimempty` (`boolean`): Discard empty segments at start and end.

**Returns:** (`fun():string?`): Iterator over split components.

**Examples:**

```lua
for s in vim.gsplit(':aa::b:', ':', {plain=true}) do
  print(s)
end
-- Output:
--
-- aa
--
-- b
--
```

**See also:** `string.gmatch()`, `vim.split()`, `lua-patterns`.

---

## `vim.is_callable({f})`

Returns `true` if object `f` can be called as a function.

**Parameters:**

* `f` (`any`): Any object.

**Returns:** (`boolean`): `true` if callable, `false` otherwise.

---

## `vim.isarray({t})`

Tests if `t` is an "array": a table indexed only by integers (potentially non-contiguous). Empty table `{}` is an array, unless created by `vim.empty_dict()` or returned as a dict-like API/Vimscript result.

**Parameters:**

* `t` (`table?`)

**Returns:** (`boolean`): `true` if array-like, `false` otherwise.

**See also:** `vim.islist()`.

---

## `vim.islist({t})`

Tests if `t` is a "list": a table indexed only by contiguous integers starting from 1 (a "regular array" in Lua). Empty table `{}` is a list, unless created by `vim.empty_dict()` or returned as a dict-like API/Vimscript result.

**Parameters:**

* `t` (`table?`)

**Returns:** (`boolean`): `true` if list-like, `false` otherwise.

**See also:** `vim.isarray()`.

---

## `vim.list_contains({t}, {value})`

Checks if a list-like table (integer keys without gaps) contains `value`.
**Note:** Does not validate `t` as list-like.

**Parameters:**

* `t` (`table`): List-like table.
* `value` (`any`): Value to compare.

**Returns:** (`boolean`): `true` if `t` contains `value`.

**See also:** `vim.tbl_contains()` for general tables.

---

## `vim.list_extend({dst}, {src}, {start}, {finish})`

Extends a list-like table `{dst}` with values from another list-like table `{src}`.
**NOTE:** This function mutates `dst`!

**Parameters:**

* `dst` (`table`): List to be modified.
* `src` (`table`): List from which values are inserted.
* `start` (`integer?`): Start index on `src` (default: 1).
* `finish` (`integer?`): Final index on `src` (default: `#src`).

**Returns:** (`table`): `dst`.

**See also:** `vim.tbl_extend()`.

---

## `vim.list_slice({list}, {start}, {finish})`

Creates a copy of a table containing elements from `start` to `finish` (inclusive).

**Parameters:**

* `list` (`any[]`): Table.
* `start` (`integer?`): Start range of slice.
* `finish` (`integer?`): End range of slice.

**Returns:** (`any[]`): Copy of table sliced.

---

## `vim.pesc({s})`

Escapes magic characters in Lua patterns.

**Parameters:**

* `s` (`string`): String to escape.

**Returns:** (`string`): `%-escaped` pattern string.

---

## `vim.spairs({t})`

Enumerates key-value pairs of a table, ordered by key.

**Parameters:**

* `t` (`table`): Dict-like table.

**Returns:** (`fun(table: table<K, V>, index?: K):K, V`) for-in iterator.

---

## `vim.split({s}, {sep}, {opts})`

Splits a string at each instance of a separator and returns the result as a table (eagerly, unlike `vim.gsplit()`).

**Parameters:**

* `s` (`string`): String to split.
* `sep` (`string`): Separator or pattern.
* `opts` (`table?`): Keyword arguments.
  * `plain` (`boolean`): Use `sep` literally (as in `string.find`).
  * `trimempty` (`boolean`): Discard empty segments at start and end.

**Returns:** (`string[]`): List of split components.

**Examples:**

```lua
vim.split(":aa::b:", ":")                   --> {'','aa','','b',''}
vim.split("axaby", "ab?")                   --> {'','x','y'}
vim.split("x*yz*o", "*", {plain=true})      --> {'x','yz','o'}
vim.split("|x|y|z|", "|", {trimempty=true}) --> {'x', 'y', 'z'}
```

**See also:** `vim.gsplit()`, `string.gmatch()`, `lua-patterns`.

---

## `vim.startswith({s}, {prefix})`

Tests if string `s` starts with `prefix`.

**Parameters:**

* `s` (`string`): String.
* `prefix` (`string`): Prefix to match.

**Returns:** (`boolean`): `true` if `prefix` is a prefix of `s`.

---

## `vim.tbl_contains({t}, {value}, {opts})`

Checks if a table contains a given `value`, or if a `predicate` function returns true for any value.

**Example:**

```lua
vim.tbl_contains({ 'a', { 'b', 'c' } }, function(v)
  return vim.deep_equal(v, { 'b', 'c' })
end, { predicate = true })
-- true
```

**Parameters:**

* `t` (`table`): Table to check.
* `value` (`any`): Value to compare or predicate function.
* `opts` (`table?`): Keyword arguments.
  * `predicate` (`boolean`): If `true`, `value` is a function reference (default: `false`).

**Returns:** (`boolean`): `true` if `t` contains `value`.

**See also:** `vim.list_contains()` for list-like tables.

---

## `vim.tbl_count({t})`

Counts the number of non-nil values in table `t`.

**Examples:**

```lua
vim.tbl_count({ a=1, b=2 })  --> 2
vim.tbl_count({ 1, 2 })      --> 2
```

**Parameters:**

* `t` (`table`)

**Returns:** (`integer`): Number of non-nil values.

---

## `vim.tbl_deep_extend({behavior}, {...})`

Recursively merges two or more tables. Only empty tables or non-list tables are merged recursively. Lists are treated as literals (overwritten, not merged).

**Parameters:**

* `behavior` (`'error'|'keep'|'force'|fun(key:any, prev_value:any?, value:any): any`):
  * `"error"`: Raise error if key found in multiple maps.
  * `"keep"`: Use value from leftmost map.
  * `"force"`: Use value from rightmost map.
  * `function`: Receives `key`, `prev_value`, `value`; returns value for merged table.
* `...` (`table`): Two or more tables.

**Returns:** (`table`): Merged table.

**See also:** `vim.tbl_extend()`.

---

## `vim.tbl_extend({behavior}, {...})`

Merges two or more tables (non-recursively).

**Parameters:**

* `behavior` (`'error'|'keep'|'force'|fun(key:any, prev_value:any?, value:any): any`): Same as `vim.tbl_deep_extend()`.
* `...` (`table`): Two or more tables.

**Returns:** (`table`): Merged table.

**See also:** `extend()`.

---

## `vim.tbl_filter({func}, {t})`

Filters a table using a predicate function.

**Parameters:**

* `func` (`function`): Function.
* `t` (`table`): Table.

**Returns:** (`any[]`): Table of filtered values.

---

## `vim.tbl_get({o}, {...})`

Indexes into a table (`o`) via string keys passed as subsequent arguments. Returns `nil` if a key does not exist.

**Examples:**

```lua
vim.tbl_get({ key = { nested_key = true }}, 'key', 'nested_key') == true
vim.tbl_get({ key = {}}, 'key', 'nested_key') == nil
```

**Parameters:**

* `o` (`table`): Table to index.
* `...` (`any`): Optional keys (0 or more).

**Returns:** (`any`): Nested value, or `nil`.

---

## `vim.tbl_isempty({t})`

Checks if a table is empty.

**Parameters:**

* `t` (`table`): Table to check.

**Returns:** (`boolean`): `true` if `t` is empty.

---

## `vim.tbl_keys({t})`

Returns a list of all keys used in a table. Order is not guaranteed.

**Parameters:**

* `t` (`table`): Table.

**Returns:** (`any[]`): List of keys.

---

## `vim.tbl_map({func}, {t})`

Applies a function to all values of a table.

**Parameters:**

* `func` (`fun(value: T): any`): Function.
* `t` (`table<any, T>`): Table.

**Returns:** (`table`): Table of transformed values.

---

## `vim.tbl_values({t})`

Returns a list of all values used in a table. Order is not guaranteed.

**Parameters:**

* `t` (`table`): Table.

**Returns:** (`any[]`): List of values.

---

## `vim.trim({s})`

Trims whitespace (`%s` Lua pattern) from both sides of a string.

**Parameters:**

* `s` (`string`): String to trim.

**Returns:** (`string`): String with whitespace removed.

---

## `vim.validate()`

Validates function arguments. Has two forms:

1. **`vim.validate(name, value, validator[, optional][, message])`**:
    Validates argument `{name}` with `{value}` against `{validator}`. If `optional` is `true`, `value` can be `nil`. `message` overrides default error message.

    **`validator` types:**
    * `string|string[]`: Any value from `lua-type()` plus `'callable'`.
    * `fun(val:any): boolean, string?`: A function returning `boolean` and optional error message.

    **Example:**

    ```lua
    function vim.startswith(s, prefix)
      vim.validate('s', s, 'string')
      vim.validate('prefix', prefix, 'string')
      -- ...
    end
    ```

2. **`vim.validate(spec)` (deprecated)**:
    Validates an argument specification table. Specs are evaluated alphanumerically.

    **Example:**

    ```lua
    function user.new(name, age, hobbies)
      vim.validate{
        name={name, 'string'},
        age={age, 'number'},
        hobbies={hobbies, 'table'},
      }
      -- ...
    end
    ```

**Examples with explicit argument values:**

```lua
vim.validate('arg1', {'foo'}, 'table')       --> NOP (success)
vim.validate('arg2', 'foo', 'string')        --> NOP (success)
vim.validate('arg1', 1, 'table')             --> error('arg1: expected table, got number')
vim.validate('arg1', 3, function(a) return (a % 2) == 0 end, 'even number')
   --> error('arg1: expected even number, got 3')
vim.validate('arg1', {'foo'}, {'table', 'string'}) --> NOP (success)
vim.validate('arg1', 1, {'string', 'table'}) --> error('arg1: expected string|table, got number')
```

**Note:** Using values returned by `lua-type()` for `validator` provides best performance.

---

## Lua module: `vim.loader`

**WARNING:** Experimental/Unstable feature.
Manages an experimental Lua module loader.

##### `vim.loader.enable({enable})`

Enables or disables the experimental Lua module loader.

* `enable=true` (or `nil`):
  * Overrides `loadfile()`.
  * Adds Lua loader with byte-compilation cache.
  * Adds `libs` loader.
  * Removes default Nvim loader.
* `enable=false`:
  * Removes loaders.
  * Adds default Nvim loader.

**Parameters:**

* `enable` (`boolean?`): `true`/`nil` to enable, `false` to disable.

##### `vim.loader.find({modname}, {opts})`

Finds Lua modules for a given module name.

**Parameters:**

* `modname` (`string`): Module name, or `"*"` for top-level modules.
* `opts` (`table?`): Options.
  * `rtp` (`boolean`): Search in runtime path (default: `true`).
  * `paths` (`string[]`): Extra paths to search (default: `{}`).
  * `patterns` (`string[]`): List of patterns for searching (default: `{"/init.lua", ".lua"}`).
  * `all` (`boolean`): Search for all matches (default: `false`).

**Returns:** (`table[]`): List of objects with `modpath`, `modname`, and `stat` (if not `modname="*"`) fields.

##### `vim.loader.reset({path})`

Resets the cache for a specific path, or all paths if `path` is `nil`.

**Parameters:**

* `path` (`string?`): Path to reset.

---

## Lua module: `vim.uri`

Provides functions for URI manipulation.

##### `vim.uri_decode({str})`

URI-decodes a string containing percent escapes.

**Parameters:**

* `str` (`string`): String to decode.

**Returns:** (`string`): Decoded string.

##### `vim.uri_encode({str}, {rfc})`

URI-encodes a string using percent escapes.

**Parameters:**

* `str` (`string`): String to encode.
* `rfc` (`"rfc2396"|"rfc2732"|"rfc3986"?`): RFC standard to follow.

**Returns:** (`string`): Encoded string.

##### `vim.uri_from_bufnr({bufnr})`

Gets a URI from a buffer number.

**Parameters:**

* `bufnr` (`integer`)

**Returns:** (`string`): URI.

##### `vim.uri_from_fname({path})`

Gets a URI from a file path.

**Parameters:**

* `path` (`string`): Path to file.

**Returns:** (`string`): URI.

##### `vim.uri_to_bufnr({uri})`

Gets the buffer number for a URI. Creates a new unloaded buffer if none exists.

**Parameters:**

* `uri` (`string`)

**Returns:** (`integer`): `bufnr`.

##### `vim.uri_to_fname({uri})`

Gets a filename from a URI.

**Parameters:**

* `uri` (`string`)

**Returns:** (`string`): Filename or unchanged URI for non-file URIs.

---

## Lua module: `vim.ui`

Provides user interface interaction functions.

##### `vim.ui.input({opts}, {on_confirm})`

Prompts the user for input, allowing arbitrary asynchronous work until `on_confirm`.

**Example:**

```lua
vim.ui.input({ prompt = 'Enter value for shiftwidth: ' }, function(input)
    vim.o.shiftwidth = tonumber(input)
end)
```

**Parameters:**

* `opts` (`table?`): Additional options.
  * `prompt` (`string|nil`): Prompt text.
  * `default` (`string|nil`): Default reply.
  * `completion` (`string|nil`): Completion type (same as `:command-completion`).
  * `highlight` (`function`): Function for highlighting user input.
* `on_confirm` (`function`): `((input|nil) -> ())` Called when user confirms/aborts. `input` is typed text, `nil` if aborted.

##### `vim.ui.open({path}, {opt})`

Opens a path with the system's default handler (e.g., `open` on macOS, `explorer.exe` on Windows, `xdg-open` on Linux), or returns an error message. Expands `~/` and environment variables. Can be invoked with `:Open`.

**Parameters:**

* `path` (`string`): Path or URL.
* `opt` (`{ cmd?: string[] }?`): Options.
  * `cmd` (`string[]|nil`): Command to use (e.g., `{ 'osurl' }`).

**Returns:** (`vim.SystemObj?`, `string?`): Command object (or `nil`), error message (or `nil`).

**Examples:**

```lua
-- Asynchronous.
vim.ui.open("https://neovim.io/")
vim.ui.open("~/path/to/file")

-- Use the "osurl" command:
vim.ui.open("gh#neovim/neovim!29490", { cmd = { 'osurl' } })

-- Synchronous (wait until the process exits).
local cmd, err = vim.ui.open("$VIMRUNTIME")
if cmd then
  cmd:wait()
end
```

##### `vim.ui.select({items}, {opts}, {on_choice})`

Prompts the user to pick from a list of items, allowing asynchronous work.

**Example:**

```lua
vim.ui.select({ 'tabs', 'spaces' }, {
    prompt = 'Select tabs or spaces:',
    format_item = function(item)
        return "I'd like to choose " .. item
    end,
}, function(choice)
    if choice == 'spaces' then
        vim.o.expandtab = true
    else
        vim.o.expandtab = false
    end
end)
```

**Parameters:**

* `items` (`any[]`): Arbitrary items.
* `opts` (`table`): Additional options.
  * `prompt` (`string|nil`): Prompt text (default: `"Select one of:"`).
  * `format_item` (`function`): `item -> text` Function to format an item (default: `tostring`).
  * `kind` (`string|nil`): Arbitrary hint string for plugins.
* `on_choice` (`fun(item: T?, idx: integer?)`): Called when user makes a choice. `idx` is 1-based index, `nil` if aborted.

---

## Lua module: `vim._extui`

**WARNING:** Experimental interface, intended to replace the message grid in the TUI.

**Enabling Experimental UI:**

```lua
require('vim._extui').enable({
 enable = true, -- Whether to enable or disable the UI.
 msg = { -- Options related to the message module.
   ---@type 'cmd'|'msg' Where to place regular messages, either in the
   ---cmdline or in a separate ephemeral message window.
   target = 'cmd',
   timeout = 4000, -- Time a message is visible in the message window.
 },
})
```

**Window Types:**
This interface uses four window types, each with a specific `'filetype'`:

* `"cmd"`: Cmdline window (for `'showcmd'`, `'showmode'`, `'ruler'`, and messages if `'cmdheight' > 0`). Filetype: `"cmd"`.
* `"msg"`: Message window (for messages when `'cmdheight' == 0`). Filetype: `"msg"`.
* `"pager"`: Pager window (for `:messages` and full messages). Filetype: `"pager"`.
* `"dialog"`: Dialog window (for prompt messages expecting input). Filetype: `"dialog"`.

**Subtle Fact:** Configure local options for these windows using `FileType` autocommands (e.g., `autocmd FileType cmd setlocal ...`).

**Message Handling:**
Instead of `hit-enter-prompt`, messages in the cmdline area that don't fit are appended with a `[+x]` "spill" indicator. Use `g<` command to see the full message.

---

## Lua module: `vim.filetype`

Provides functions for managing and detecting filetypes.

##### `vim.filetype.add({filetypes})`

Adds new filetype mappings. Mappings can be by extension, filename (tail or full path), or Lua patterns.

**Matching Order:**

1. Full file path.
2. File name.
3. Lua patterns (sorted by priority).
4. File extension.

**Filetype Value:**
Can be a `string` (used directly) or a `function`.

* **Function Signature:** `function(path, bufnr, ...)` (captures from pattern).
* **Function Return:** A `string` (the filetype), and optionally a second `function` (`function(bufnr)`) which modifies buffer state (called before setting filetype).

**Filename Patterns:**
Can specify an optional `priority` (default: 0). Higher priorities match first. Can contain environment variables (`"${SOME_VAR}"`).

**Example:**

```lua
vim.filetype.add({
  extension = {
    foo = 'fooscript',
    bar = function(path, bufnr)
      if some_condition() then
        return 'barscript', function(bufnr)
          -- Set a buffer variable
          vim.b[bufnr].barscript_version = 2
        end
      end
      return 'bar'
    end,
  },
  filename = {
    ['.foorc'] = 'toml',
    ['/etc/foo/config'] = 'toml',
  },
  pattern = {
    ['.*/etc/foo/.*'] = 'fooscript',
    -- Using an optional priority
    ['.*/etc/foo/.*%.conf'] = { 'dosini', { priority = 10 } },
    -- A pattern containing an environment variable
    ['${XDG_CONFIG_HOME}/foo/git'] = 'git',
    ['.*README.(%a+)'] = function(path, bufnr, ext)
      if ext == 'md' then
        return 'markdown'
      elseif ext == 'rst' then
        return 'rst'
      end
    end,
  },
})
```

**Example: Fallback match on contents (low priority):**

```lua
vim.filetype.add {
  pattern = {
    ['.*'] = {
      function(path, bufnr)
        local content = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
        if vim.regex([[^#!.*\\<mine\\>]]):match_str(content) ~= nil then
          return 'mine'
        elseif vim.regex([[\\<drawing\\>]]):match_str(content) ~= nil then
          return 'drawing'
        end
      end,
      { priority = -math.huge }, -- Very low priority
    },
  },
}
```

**Parameters:**

* `filetypes` (`table`): Table mapping `pattern`, `extension`, `filename` to filetype definitions.

##### `vim.filetype.get_option({filetype}, {option})`

Gets the default option value for a `{filetype}`. This reflects what would be set in a new buffer after `'filetype'` is set (respecting `FileType` autocmds and `ftplugin` files).
**Note:** Uses `nvim_get_option_value()` and caches the result, meaning `ftplugin` and `FileType` autocmds are triggered only once.

**Example:**

```lua
vim.filetype.get_option('vim', 'commentstring')
```

**Parameters:**

* `filetype` (`string`): Filetype.
* `option` (`string`): Option name.

**Returns:** (`string|boolean|integer`): Option value.

##### `vim.filetype.match({args})`

Performs filetype detection.

**Detection Methods:**

1. **Using an existing buffer:** `args.buf`
2. **Using only a file name:** `args.filename` (without `buf`)
3. **Using only file contents:** `args.contents`

**Parameters:**

* `args` (`table`): Table specifying matching strategy.
  * `buf` (`integer`): Buffer number. Mutually exclusive with `contents`.
  * `filename` (`string`): Filename. Defaults to buffer's filename if `buf` is given. Can be used without `buf` (less accurate).
  * `contents` (`string[]`): Array of lines. Can be used with `filename`. Mutually exclusive with `buf`.

**Returns:** (`string?`, `function?`)

* Matched filetype (if found).
* A function that modifies buffer state when called (accepts `bufnr`).

**Examples:**

```lua
vim.filetype.match({ buf = 42 })
vim.filetype.match({ buf = 42, filename = 'foo.c' })
vim.filetype.match({ filename = 'main.lua' })
vim.filetype.match({ contents = {'#!/usr/bin/env bash'} })
```

---

## Lua module: `vim.keymap`

Provides functions for defining and removing key mappings.

##### `vim.keymap.del({modes}, {lhs}, {opts})`

Removes an existing mapping.

**Parameters:**

* `modes` (`string|string[]`): Mode "short-name" (e.g., `'n'`, `'i'`, or `{'n', 'i', 'v'}`).
* `lhs` (`string`): Left-hand side of the mapping.
* `opts` (`table?`): Options.
  * `buffer` (`integer|boolean`): Remove buffer-local mapping. `0` or `true` for current buffer.

**Examples:**

```lua
vim.keymap.del('n', 'lhs')
vim.keymap.del({'n', 'i', 'v'}, '<leader>w', { buffer = 5 })
```

**See also:** `vim.keymap.set()`.

##### `vim.keymap.set({mode}, {lhs}, {rhs}, {opts})`

Defines a mapping of keycodes to a function or keycodes.

**Parameters:**

* `mode` (`string|string[]`): Mode "short-name" or list thereof.
* `lhs` (`string`): Left-hand side.
* `rhs` (`string|function`): Right-hand side, can be a Lua function.
* `opts` (`table?`): Table of `:map-arguments` (same as `nvim_set_keymap() {opts}`).
  * `replace_keycodes`: Defaults to `true` if `expr` is `true`.
  * `buffer` (`integer|boolean`): Creates buffer-local mapping. `0` or `true` for current buffer.
  * `remap` (`boolean`): Make mapping recursive (default: `false`). Inverse of `noremap`.

**Examples:**

```lua
-- Map "x" to a Lua function:
vim.keymap.set('n', 'x', function() print("real lua function") end)

-- Map "<leader>x" to multiple modes for the current buffer:
vim.keymap.set({'n', 'v'}, '<leader>x', vim.lsp.buf.references, { buffer = true })

-- Map <Tab> to an expression (|:map-<expr>|):
vim.keymap.set('i', '<Tab>', function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true })

-- Map "[%%" to a <Plug> mapping:
vim.keymap.set('n', '[%%', '<Plug>(MatchitNormalMultiBackward)')
```

**See also:** `nvim_set_keymap()`, `maparg()`, `mapcheck()`, `mapset()`.

---

## Lua module: `vim.fs`

Provides filesystem utilities.

##### `vim.fs.exists()`

Use `vim.uv.fs_stat()` to check a file's type and existence.

**Example:**

```lua
if vim.uv.fs_stat(file) then
  vim.print('file exists')
end
```

##### `vim.fs.abspath({path})`

Converts path to an absolute path. Expands `~`. Does not check existence, normalize, resolve symlinks, or expand environment variables (except `~`). Converts `\` to `/`.

**Parameters:**

* `path` (`string`)

**Returns:** (`string`): Absolute path.

##### `vim.fs.basename({file})`

Returns the basename of the given path.

**Parameters:**

* `file` (`string?`)

**Returns:** (`string?`): Basename.

##### `vim.fs.dir({path}, {opts})`

Returns an iterator over items in `{path}`.

**Parameters:**

* `path` (`string`): Absolute or relative path to directory (normalized first).
* `opts` (`table?`): Optional keyword arguments.
  * `depth` (`integer|nil`): How deep to traverse (default: `1`).
  * `skip` (`fun(dir_name: string): boolean|nil`): Predicate to control traversal. Return `false` to stop searching current directory. Only useful if `depth > 1`.
  * `follow` (`boolean|nil`): Follow symbolic links (default: `false`).

**Returns:** (`Iterator`): Over `name` (basename) and `type` (`"file"`, `"directory"`, `"link"`, etc.).

##### `vim.fs.dirname({file})`

Gets the parent directory of the given path (not expanded/resolved).

**Parameters:**

* `file` (`string?`)

**Returns:** (`string?`): Parent directory.

##### `vim.fs.find({names}, {opts})`

Finds files or directories (or other types) in a path. Searches upward (`upward=true`) or downward (recursively).

**Parameters:**

* `names` (`string|string[]|fun(name: string, path: string): boolean`): Names to find (basenames only if string/table). If a function, it's called for each item (`name`, `path`) and returns `true` for a match.
* `opts` (`table`): Optional keyword arguments.
  * `path` (`string`): Path to start searching (default: current directory).
  * `upward` (`boolean`): Search upward (default: `false`).
  * `stop` (`string`): Stop search when this directory is reached (not searched itself).
  * `type` (`string`): Find only items of this type (`"file"`, `"directory"`, etc.).
  * `limit` (`number`): Stop after finding this many matches (default: 1). Use `math.huge` for no limit.
  * `follow` (`boolean`): Follow symbolic links (default: `false`).

**Returns:** (`string[]`): Normalized paths of matching items.

**Examples:**

```lua
-- List all test directories under the runtime directory.
local dirs = vim.fs.find(
  { 'test', 'tst', 'testdir' },
  { limit = math.huge, type = 'directory', path = './runtime/' }
)

-- Get all "lib/*.cpp" and "lib/*.hpp" files, using Lua patterns.
local files = vim.fs.find(function(name, path)
  return name:match('.*%.[ch]pp$') and path:match('[/\\]lib$')
end, { limit = math.huge, type = 'file' })
```

##### `vim.fs.joinpath({...})`

Concatenates partial paths. Slashes are normalized (`/`).

**Examples:**

```lua
"foo/", "/bar" => "foo/bar"
Windows: "a\foo\", "\bar" => "a/foo/bar"
```

**Parameters:**

* `...` (`string`)

**Returns:** (`string`)

##### `vim.fs.normalize({path}, {opts})`

Normalizes a path to a standard format. Expands `~` and environment variables. Resolves `.` and `..` components. Converts `\` to `/` on Windows.

**Parameters:**

* `path` (`string`): Path to normalize.
* `opts` (`table?`): Options.
  * `expand_env` (`boolean`): Expand environment variables (default: `true`).
  * `win` (`boolean`): Path is a Windows path (default: `true` on Windows, `false` otherwise).

**Returns:** (`string`): Normalized path.

**Examples:**

```lua
[[C:\Users\jdoe]]                         => "C:/Users/jdoe"
"~/src/neovim"                            => "/home/jdoe/src/neovim"
"$XDG_CONFIG_HOME/nvim/init.vim"          => "/Users/jdoe/.config/nvim/init.vim"
"~/src/nvim/api/../tui/./tui.c"           => "/home/jdoe/src/nvim/tui/tui.c"
"foo/../../../bar"                        => "../../bar"
"/home/jdoe/../../../bar"                 => "/bar"
"C:foo/../../baz"                         => "C:../baz"
"C:/foo/../../baz"                        => "C:/baz"
[[\\?\UNC\server\share\foo\..\..\..\bar]] => "//?/UNC/server/share/bar"
```

##### `vim.fs.parents({start})`

Iterates over all parent directories of a given path (not expanded/resolved).

**Example:**

```lua
local root_dir
for dir in vim.fs.parents(vim.api.nvim_buf_get_name(0)) do
  if vim.fn.isdirectory(dir .. '/.git') == 1 then
    root_dir = dir
    break
  end
end
if root_dir then
  print('Found git repository at', root_dir)
end
```

**Parameters:**

* `start` (`string`): Initial path.

**Returns:** (`fun(_, dir: string): string?`): Iterator.

##### `vim.fs.relpath({base}, {target}, {opts})`

Gets the target path relative to `base`, or `nil` if `base` is not an ancestor.

**Examples:**

```lua
vim.fs.relpath('/var', '/var/lib') -- 'lib'
vim.fs.relpath('/var', '/usr/bin') -- nil
```

**Parameters:**

* `base` (`string`)
* `target` (`string`)
* `opts` (`table?`): Reserved for future use.

**Returns:** (`string?`)

##### `vim.fs.rm({path}, {opts})`

Removes files or directories.

**Parameters:**

* `path` (`string`): Path to remove.
* `opts` (`table?`): Options.
  * `recursive` (`boolean`): Remove directories and contents recursively.
  * `force` (`boolean`): Ignore nonexistent files and arguments.

##### `vim.fs.root({source}, {marker})`

Finds the first parent directory containing a specific "marker", relative to a file path or buffer.

**Parameters:**

* `source` (`integer|string`): Buffer number (0 for current) or file path.
* `marker` (`(string|string[]|fun(name: string, path: string): boolean)[]|string|fun(name: string, path: string): boolean`): Filename, function, or list thereof.
  * Nested lists (`{ { 'a.txt', 'b.lua' }, ... }`) indicate "equal priority" markers.
  * A function item: `fun(name: string, path: string): boolean` returning `true` for a match.
  * Each item (or nested list) is evaluated in order against ancestors until a match is found.

**Returns:** (`string?`): Directory path containing a marker, or `nil`.

**Examples:**

```lua
-- Find the root of a Python project:
vim.fs.root(vim.fs.joinpath(vim.env.PWD, 'main.py'), {'pyproject.toml', 'setup.py' })

-- Find the root of a git repository:
vim.fs.root(0, '.git')

-- Find the parent directory containing any file with a .csproj extension:
vim.fs.root(0, function(name, path)
  return name:match('%.csproj$') ~= nil
end)

-- Find first ancestor with "stylua.toml" OR ".luarc.json"; if not, then ".git":
vim.fs.root(0, { { 'stylua.toml', '.luarc.json' }, '.git' })
```

---

## Lua module: `vim.glob`

Provides a Glob-to-LPeg Converter (Peglob), converting glob patterns to LPeg patterns according to LSP 3.17 specification.

**Glob Grammar Overview:**

* `*`: Matches zero or more characters in a path segment.
* `?`: Matches one character in a path segment.
* `**`: Matches any number of path segments, including none. Must be delimited by `/` or pattern boundaries.
* `{}`: Groups conditions (e.g., `*.{ts,js}`). Must contain at least two branches.
* `[]`: Character range in a path segment (e.g., `example.[0-9]`).
* `[!...]`: Negated character range.
* **Constraints:** Pattern must match *entire* path; partial matches fail. `/` is not matched by character ranges.

##### `vim.glob.to_lpeg({pattern})`

Parses a raw glob into an `lua-lpeg` pattern.

**Parameters:**

* `pattern` (`string`): Raw glob pattern.

**Returns:** (`vim.lpeg.Pattern`)

---

## `vim.lpeg`

LPeg is a pattern-matching library for Lua, based on Parsing Expression Grammars (PEGs). Included as `vim.lpeg`. Its regex-like interface is available as `vim.re`.

##### `Pattern:match({subject}, {init}, {...})`

Matches the pattern against the subject string. Returns the index after the match or captured values. `init` specifies start position. Works in **anchored mode** (prefix match).

**Parameters:**

* `subject` (`string`)
* `init` (`integer?`)
* `...` (`any`)

**Returns:** (`any`)

**Example:**

```lua
local pattern = lpeg.R('az') ^ 1 * -1
assert(pattern:match('hello') == 6)
assert(lpeg.match(pattern, 'hello') == 6)
assert(pattern:match('1 hello') == nil)
```

##### `vim.lpeg.B({pattern})`

Returns a pattern that matches only if input is preceded by `patt`. `patt` must have fixed length and no captures. Does not consume input.

**Parameters:**

* `pattern` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

**Returns:** (`vim.lpeg.Pattern`)

##### `vim.lpeg.C({patt})`

Creates a simple capture, capturing the substring that matches `patt`. Captured value is a string. Other captures in `patt` are returned after this one.

**Example:**

```lua
local function split (s, sep)
  sep = lpeg.P(sep)
  local elem = lpeg.C((1 - sep) ^ 0)
  local p = elem * (sep * elem) ^ 0
  return lpeg.match(p, s)
end
local a, b, c = split('a,b,c', ',')
assert(a == 'a')
assert(b == 'b')
assert(c == 'c')
```

**Parameters:**

* `patt` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

**Returns:** (`vim.lpeg.Capture`)

##### `vim.lpeg.Carg({n})`

Creates an argument capture. Matches empty string, produces `nth` extra argument from `lpeg.match`.

**Parameters:**

* `n` (`integer`)

**Returns:** (`vim.lpeg.Capture`)

##### `vim.lpeg.Cb({name})`

Creates a back capture. Matches empty string, produces values from most recent **complete outermost group capture** named `name`.

**Parameters:**

* `name` (`any`)

**Returns:** (`vim.lpeg.Capture`)

##### `vim.lpeg.Cc({...})`

Creates a constant capture. Matches empty string, produces all given values as captured values.

**Parameters:**

* `...` (`any`)

**Returns:** (`vim.lpeg.Capture`)

##### `vim.lpeg.Cf({patt}, {func})`

Creates a fold capture. Folds (accumulates) captures from `patt` using `func`. `func` is called with accumulator and subsequent capture values.

**Example:**

```lua
local number = lpeg.R('09') ^ 1 / tonumber
local list = number * (',' * number) ^ 0
local function add(acc, newvalue) return acc + newvalue end
local sum = lpeg.Cf(list, add)
assert(sum:match('10,30,43') == 83)
```

**Parameters:**

* `patt` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)
* `func` (`fun(acc, newvalue)`)

**Returns:** (`vim.lpeg.Capture`)

##### `vim.lpeg.Cg({patt}, {name})`

Creates a group capture. Groups all values from `patt` into a single capture. Can be named.

**Parameters:**

* `patt` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)
* `name` (`string?`)

**Returns:** (`vim.lpeg.Capture`)

##### `vim.lpeg.Cmt({patt}, {fn})`

Creates a match-time capture. Evaluated immediately on match (even if outer pattern fails later). Forces nested capture evaluation, then calls `fn`. `fn` returns numeric position for success/new position, `true` for success (no input consumed), `false`/`nil` for failure. Extra values from `fn` become capture values.

**Parameters:**

* `patt` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)
* `fn` (`fun(s: string, i: integer, ...: any)`) returning `(position: boolean|integer, ...: any)`

**Returns:** (`vim.lpeg.Capture`)

##### `vim.lpeg.Cp()`

Creates a position capture. Matches empty string, captures current position in subject. Captured value is a number.

**Example:**

```lua
local I = lpeg.Cp()
local function anywhere(p) return lpeg.P({I * p * I + 1 * lpeg.V(1)}) end
local match_start, match_end = anywhere('world'):match('hello world!')
assert(match_start == 7)
assert(match_end == 12)
```

**Returns:** (`vim.lpeg.Capture`)

##### `vim.lpeg.Cs({patt})`

Creates a substitution capture. Captures substring matching `patt`, with substitutions. For captures inside `patt` with values, the matched substring is replaced by the capture value (must be string).

**Example:**

```lua
local function gsub (s, patt, repl)
  patt = lpeg.P(patt)
  patt = lpeg.Cs((patt / repl + 1) ^ 0)
  return lpeg.match(patt, s)
end
assert(gsub('Hello, xxx!', 'xxx', 'World') == 'Hello, World!')
```

**Parameters:**

* `patt` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

**Returns:** (`vim.lpeg.Capture`)

##### `vim.lpeg.Ct({patt})`

Creates a table capture. Returns a table with anonymous captures from `patt` in integer keys (1-based), and first value of named capture groups with group name as key.

**Parameters:**

* `patt` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

**Returns:** (`vim.lpeg.Capture`)

##### `vim.lpeg.locale({tab})`

Returns a table with patterns for character classes (alnum, alpha, etc.) according to current locale. If `tab` is given, adds fields to it.

**Example:**

```lua
lpeg.locale(lpeg) -- Adds locale patterns to lpeg global table
local locale = lpeg.locale()
assert(type(locale.digit) == 'userdata')
```

**Parameters:**

* `tab` (`table?`)

**Returns:** (`vim.lpeg.Locale`)

##### `vim.lpeg.match({pattern}, {subject}, {init}, {...})`

(Same as `Pattern:match`, included for completeness).

##### `vim.lpeg.P({value})`

Converts a value into a proper LPeg pattern.

**Conversion Rules:**

* `pattern`: Returned unmodified.
* `string`: Matches string literally.
* `non-negative number n`: Matches exactly `n` characters.
* `negative number -n`: Succeeds only if input has less than `n` characters left (equivalent to `-lpeg.P(n)`).
* `boolean`: Always succeeds or fails, consumes no input.
* `table`: Interpreted as a grammar.
* `function`: Equivalent to match-time capture over empty string.

**Parameters:**

* `value` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

**Returns:** (`vim.lpeg.Pattern`)

##### `vim.lpeg.R({...})`

Returns a pattern matching any single character within given ranges. Each range is `xy` (length 2), representing characters between `x` and `y` (inclusive).

**Example:**

```lua
local pattern = lpeg.R('az') ^ 1 * -1
assert(pattern:match('hello') == 6)
```

**Parameters:**

* `...` (`string`)

**Returns:** (`vim.lpeg.Pattern`)

##### `vim.lpeg.S({string})`

Returns a pattern matching any single character appearing in the given string (Set).

**Example:**
`lpeg.S('+-*/')` matches any arithmetic operator.

**Parameters:**

* `string` (`string`)

**Returns:** (`vim.lpeg.Pattern`)

##### `vim.lpeg.setmaxstack({max})`

Sets a limit for the backtrack stack size (default: 400).

**Parameters:**

* `max` (`integer`)

##### `vim.lpeg.type({value})`

Returns `"pattern"` if value is an LPeg pattern, otherwise `nil`.

**Parameters:**

* `value` (`vim.lpeg.Pattern|string|integer|boolean|table|function`)

**Returns:** (`"pattern"?`)

##### `vim.lpeg.V({v})`

Creates a non-terminal (variable) for a grammar, referring to the rule indexed by `v` in the enclosing grammar.

**Example:**

```lua
local b = lpeg.P({'(' * ((1 - lpeg.S '()') + lpeg.V(1)) ^ 0 * ')'})
assert(b:match('((string))') == 11)
assert(b:match('(') == nil)
```

**Parameters:**

* `v` (`boolean|string|number|function|table|thread|userdata|lightuserdata`)

**Returns:** (`vim.lpeg.Pattern`)

##### `vim.lpeg.version()`

Returns a string with the running LPeg version.

**Returns:** (`string`)

---

## `vim.re`

Provides a conventional regex-like syntax for LPeg patterns. (Unrelated to `vim.regex`).

##### `vim.re.compile({string}, {defs})`

Compiles the given regex-like `{string}` into an LPeg pattern. `defs` provides extra Lua values.

**Parameters:**

* `string` (`string`)
* `defs` (`table?`)

**Returns:** (`vim.lpeg.Pattern`)

##### `vim.re.find({subject}, {pattern}, {init})`

Searches for `{pattern}` in `{subject}`. Returns start and end indices of first match, or `nil`. `init` specifies start position.

**Parameters:**

* `subject` (`string`)
* `pattern` (`vim.lpeg.Pattern|string`)
* `init` (`integer?`)

**Returns:** (`integer?`, `integer?`)

##### `vim.re.gsub({subject}, {pattern}, {replacement})`

Performs a global substitution, replacing all occurrences of `{pattern}` with `{replacement}`.

**Parameters:**

* `subject` (`string`)
* `pattern` (`vim.lpeg.Pattern|string`)
* `replacement` (`string`)

**Returns:** (`string`)

##### `vim.re.match({subject}, {pattern}, {init})`

Matches `{pattern}` against `{subject}`, returning all captures.

**Parameters:**

* `subject` (`string`)
* `pattern` (`vim.lpeg.Pattern|string`)
* `init` (`integer?`)

**Returns:** (`integer|vim.lpeg.Capture?`)

**See also:** `vim.lpeg.match()`.

##### `vim.re.updatelocale()`

Updates pre-defined character classes to the current locale.

---

## `vim.regex`

Allows using Vim regexes directly from Lua. Currently limited to single-line matching.

##### `regex:match_line({bufnr}, {line_idx}, {start}, {end_})`

Matches a line in a buffer. Match restricted by `start` and `end_` byte indices. Returns byte indices relative to `start`.

**Parameters:**

* `bufnr` (`integer`)
* `line_idx` (`integer`)
* `start` (`integer?`)
* `end_` (`integer?`)

**Returns:** (`integer?`, `integer?`): Match start (byte index), match end (byte index), or `nil`.

##### `regex:match_str({str})`

Matches string `str` against the regex. Returns start and end byte indices, or `nil`. Can be used directly in `if` statements as integers are truthy. To match precisely, surround regex with `^` and `$`.

**Parameters:**

* `str` (`string`)

**Returns:** (`integer?`, `integer?`): Match start (byte index), match end (byte index), or `nil`.

##### `vim.regex({re})`

Parses a Vim regex `{re}` and returns a regex object. Regexes are "magic" and case-sensitive by default, regardless of `'magic'` and `'ignorecase'`. Can be controlled with flags (see `/magic`, `/ignorecase`).

**Parameters:**

* `re` (`string`)

**Returns:** (`vim.regex`)

---

## Lua module: `vim.secure`

Provides functions for managing a trust database.

##### `vim.secure.read({path})`

If `{path}` is a file, attempts to read it, prompting the user for trust. If `{path}` is a directory, returns `true` if trusted (non-recursive), prompting user as necessary. User's choice is persisted in `$XDG_STATE_HOME/nvim/trust`.

**Parameters:**

* `path` (`string`): Path to file or directory.

**Returns:** (`boolean|string?`):

* `nil`: If path not trusted or doesn't exist.
* `string`: File contents if path is a file and trusted.
* `true`: If path is a directory and trusted.

**See also:** `:trust`.

##### `vim.secure.trust({opts})`

Manages the trust database located at `$XDG_STATE_HOME/nvim/trust`.

**Parameters:**

* `opts` (`table`): Options.
  * `action` (`'allow'|'deny'|'remove'`):
    * `'allow'`: Add file to trust database and trust it.
    * `'deny'`: Add file to trust database and deny it.
    * `'remove'`: Remove file from trust database.
  * `path` (`string`): Path to file to update. Mutually exclusive with `bufnr`. Cannot be used when `action` is `"allow"`.
  * `bufnr` (`integer`): Buffer number to update. Mutually exclusive with `path`.

**Returns:** (`boolean`, `string`): `success` (true/false), `msg` (full path or error message).

---

## Lua module: `vim.version`

Provides functions for comparing semantic versions (`semver.org`) and ranges. Plugins can use this for tool/dependency checks.

##### `vim.version()`

Returns the version of the current Neovim process.

### Version Range Specification (`version-range`)

A version "range spec" defines a semantic version range that can be tested against a version using `vim.version.range()`.
**Note:** Suffixed versions (e.g., `1.2.3-rc1`) are not matched.

**Supported Range Specs:**

* `1.2.3`: Is exactly 1.2.3
* `=1.2.3`: Is exactly 1.2.3
* `>1.2.3`: Greater than 1.2.3
* `<1.2.3`: Before 1.2.3
* `>=1.2.3`: At least 1.2.3
* `~1.2.3`: Is `>=1.2.3 <1.3.0` ("reasonably close")
* `^1.2.3`: Is `>=1.2.3 <2.0.0` ("compatible").
  * Special case: `^0.2.3` is `>=0.2.3 <0.3.0` (0.x.x is special).
  * Special case: `^0.0.1` is `=0.0.1` (0.0.x is special).
* `^1.2`: Is `>=1.2.0 <2.0.0` (like `^1.2.0`)
* `~1.2`: Is `>=1.2.0 <1.3.0` (like `~1.2.0`)
* `^1`: Is `>=1.0.0 <2.0.0` ("compatible with 1")
* `~1`: Same as `^1` ("reasonably close to 1")
* `1.x`, `1.*`, `1`, `*`, `x`: Any version matching the specified major/minor parts.
* `1.2.3 - 2.3.4`: Is `>=1.2.3 <=2.3.4` (inclusive range).
  * Partial right: `1.2.3 - 2.3` is `>=1.2.3 <2.4.0` (`2.3` becomes `2.3.x`).
  * Partial right: `1.2.3 - 2` is `>=1.2.3 <3.0.0`.
  * Partial left: `1.2 - 2.3.0` is `1.2.0 - 2.3.0` (`1.2` becomes `1.2.0`).

##### `vim.version.cmp({v1}, {v2})`

Parses and compares two version objects (from `vim.version.parse()`, or `{major, minor, patch}` tuple, or string).
**Note:** Per semver, build metadata is ignored for comparison.

**Parameters:**

* `v1` (`vim.Version|number[]|string`): Version object.
* `v2` (`vim.Version|number[]|string`): Version to compare.

**Returns:** (`integer`): `-1` if `v1 < v2`, `0` if `v1 == v2`, `1` if `v1 > v2`.

**Examples:**

```lua
if vim.version.cmp({1,0,3}, {0,2,1}) == 0 then
  -- ...
end
local v1 = vim.version.parse('1.0.3-pre')
local v2 = vim.version.parse('0.2.1')
if vim.version.cmp(v1, v2) == 0 then
  -- ...
end
```

##### `vim.version.eq({v1}, {v2})`

Returns `true` if versions are equal. See `vim.version.cmp()` for usage.

##### `vim.version.ge({v1}, {v2})`

Returns `true` if `v1 >= v2`. See `vim.version.cmp()` for usage.

##### `vim.version.gt({v1}, {v2})`

Returns `true` if `v1 > v2`. See `vim.version.cmp()` for usage.

##### `vim.version.last({versions})`

(TODO: generalize this, move to `func.lua`).

**Parameters:**

* `versions` (`vim.Version[]`)

**Returns:** (`vim.Version?`)

##### `vim.version.le({v1}, {v2})`

Returns `true` if `v1 <= v2`. See `vim.version.cmp()` for usage.

##### `vim.version.lt({v1}, {v2})`

Returns `true` if `v1 < v2`. See `vim.version.cmp()` for usage.

##### `vim.version.parse({version}, {opts})`

Parses a semantic version string and returns a version object.

**Example:** `"1.0.1-rc1+build.2"` returns `{ major = 1, minor = 0, patch = 1, prerelease = "rc1", build = "build.2" }`.

**Parameters:**

* `version` (`string`): Version string.
* `opts` (`table?`): Optional keyword arguments.
  * `strict` (`boolean`): Default `false`. If `true`, no coercion for non-semver v2.0.0 input. If `false`, attempts to coerce inputs like `"1.0"`, `"0-x"`, `"tmux 3.2a"`.

**Returns:** (`vim.Version?`): Parsed version object, or `nil` if invalid.

##### `vim.version.range({spec})`

Parses a semver version-range `spec` and returns a range object with `from`, `to` versions, and a `has()` method. `has(v)` checks if a version `v` is in the range (inclusive `from`, exclusive `to`).

**Example:**

```lua
local r = vim.version.range('1.0.0 - 2.0.0') -- >=1.0.0, <2.0.0
print(r:has('1.9.9'))       -- true
print(r:has('2.0.0'))       -- false
print(r:has(vim.version())) -- check against current Nvim version
```

Or compare directly:

```lua
local r = vim.version.range('1.0.0 - 2.0.0')
print(vim.version.ge({1,0,3}, r.from) and vim.version.lt({1,0,3}, r.to))
```

**Parameters:**

* `spec` (`string`): Version range "spec".

**Returns:** (`table?`): Table with `from` (`vim.Version`), `to` (`vim.Version`), and `has` (`fun(self: vim.VersionRange, version: string|vim.Version)`).

---

## Lua module: `vim.iter`

`vim.iter()` is an interface for iterables, wrapping tables or functions into an `Iter` object with transformable methods (e.g., `filter()`, `map()`). These methods can be chained.

**Initialization Behavior:**

* **Lists/Arrays (`lua-list`):** Yield only values. Holes (nil values) are discarded.
  * Use `pairs()` for dict-like behavior (preserve holes, non-contiguous integer keys): `vim.iter(pairs(...))`.
  * Use `Iter:enumerate()` or initialize with `ipairs()` (`vim.iter(ipairs(...))`) to include indices.
* **Non-list tables (`lua-dict`):** Yield both key and value.
* **Function iterators:** Yield all values returned by the underlying function.
* **Tables with `__call()` metamethod:** Treated as function iterators.

**Subtle Fact:** `vim.iter()` scans table input to decide if it's a list or dict. To avoid this cost, wrap with `ipairs()` (but this limits list-only operations like `Iter:rev()`).

**Examples:**

```lua
local it = vim.iter({ 1, 2, 3, 4, 5 })
it:map(function(v) return v * 3 end)
it:rev()
it:skip(2)
it:totable()
-- { 9, 6, 3 }

-- ipairs() is a function iterator yielding index and value
vim.iter(ipairs({ 1, 2, 3, 4, 5 })):map(function(i, v)
  if i > 2 then return v end
end):totable()
-- { 3, 4, 5 }

local it = vim.iter(vim.gsplit('1,2,3,4,5', ','))
it:map(function(s) return tonumber(s) end)
for i, d in it:enumerate() do
  print(string.format("Column %d is %d", i, d))
end
-- Output:
-- Column 1 is 1
-- Column 2 is 2
-- Column 3 is 3
-- Column 4 is 4
-- Column 5 is 5

vim.iter({ a = 1, b = 2, c = 3, z = 26 }):any(function(k, v)
  return k == 'z'
end)
-- true

local rb = vim.ringbuf(3)
rb:push("a")
rb:push("b")
vim.iter(rb):totable()
-- { "a", "b" }
```

##### `Iter:all({pred})`

Returns `true` if all items match the predicate.

**Parameters:**

* `pred` (`fun(...):boolean`): Predicate function.

##### `Iter:any({pred})`

Returns `true` if any item matches the predicate.

**Parameters:**

* `pred` (`fun(...):boolean`): Predicate function.

##### `Iter:each({f})`

Calls a function for each item, draining the iterator. For side effects. To modify values, use `Iter:map()`.

**Parameters:**

* `f` (`fun(...)`): Function to execute.

##### `Iter:enumerate()`

Yields item index (count) and value for each item. More efficient for list tables when used with `ipairs()`.

**Example:**

```lua
local it = vim.iter(vim.gsplit('abc', '')):enumerate()
it:next() -- 1, 'a'
it:next() -- 2, 'b'
it:next() -- 3, 'c'
```

**Returns:** (`Iter`)

##### `Iter:filter({f})`

Filters an iterator pipeline. If `f` returns `false` or `nil`, the element is removed.

**Example:**

```lua
local bufs = vim.iter(vim.api.nvim_list_bufs()):filter(vim.api.nvim_buf_is_loaded)
```

**Parameters:**

* `f` (`fun(...):boolean`): Function returning `true` to keep, `false`/`nil` to remove.

**Returns:** (`Iter`)

##### `Iter:find({f})`

Finds the first value satisfying the predicate. Advances/drains iterator. Returns `nil` if not found.

**Examples:**

```lua
local it = vim.iter({ 3, 6, 9, 12 })
it:find(12)      -- 12
it:find(20)      -- nil

local it = vim.iter({ 3, 6, 9, 12 })
it:find(function(v) return v % 4 == 0 end) -- 12
```

**Parameters:**

* `f` (`any`)

**Returns:** (`any`)

##### `Iter:flatten({depth})`

Flattens a list-iterator, un-nesting values up to `depth`. Errors on dict-like values.

**Examples:**

```lua
vim.iter({ 1, { 2 }, { { 3 } } }):flatten():totable()      -- { 1, 2, { 3 } }
vim.iter({1, { { a = 2 } }, { 3 } }):flatten():totable()   -- { 1, { a = 2 }, 3 }
vim.iter({ 1, { { a = 2 } }, { 3 } }):flatten(math.huge):totable()
-- error: attempt to flatten a dict-like table
```

**Parameters:**

* `depth` (`number?`): Depth to flatten (default: 1).

**Returns:** (`Iter`)

##### `Iter:fold({init}, {f})`

Folds ("reduces") an iterator into a single value.

**Examples:**

```lua
-- Create a new table with only even values
vim.iter({ a = 1, b = 2, c = 3, d = 4 })
  :filter(function(k, v) return v % 2 == 0 end)
  :fold({}, function(acc, k, v)
    acc[k] = v
    return acc
  end) --> { b = 2, d = 4 }

-- Get the "maximum" item
vim.iter({ -99, -4, 3, 42, 0, 0, 7 })
  :fold({}, function(acc, v)
    acc.max = math.max(v, acc.max or v)
    return acc
  end) --> { max = 42 }
```

**Parameters:**

* `init` (`any`): Initial accumulator value.
* `f` (`fun(acc:A, ...):A`): Accumulation function.

**Returns:** (`any`)

##### `Iter:join({delim})`

Collects iterator into a delimited string. Consumes iterator.

**Parameters:**

* `delim` (`string`): Delimiter.

**Returns:** (`string`)

##### `Iter:last()`

Drains iterator and returns the last item.

**Example:**

```lua
local it = vim.iter(vim.gsplit('abcdefg', ''))
it:last() -- 'g'
```

**Returns:** (`any`)

**See also:** `Iter:rpeek()`.

##### `Iter:map({f})`

Maps items to values returned by `f`. If `f` returns `nil`, the value is filtered.

**Example:**

```lua
local it = vim.iter({ 1, 2, 3, 4 }):map(function(v)
  if v % 2 == 0 then
    return v * 3
  end
end)
it:totable() -- { 6, 12 }
```

**Parameters:**

* `f` (`fun(...):...:any`): Mapping function.

**Returns:** (`Iter`)

##### `Iter:next()`

Gets the next value from the iterator.

**Example:**

```lua
local it = vim.iter(string.gmatch('1 2 3', '%d+')):map(tonumber)
it:next() -- 1
it:next() -- 2
it:next() -- 3
```

**Returns:** (`any`)

##### `Iter:nth({n})`

Gets the `nth` value (and advances to it). Negative `n` offsets from end for list-iterators.

**Examples:**

```lua
local it = vim.iter({ 3, 6, 9, 12 })
it:nth(2) -- 6
it:nth(2) -- 12

local it2 = vim.iter({ 3, 6, 9, 12 })
it2:nth(-2) -- 9
it2:nth(-2) -- 3
```

**Parameters:**

* `n` (`number`): Index.

**Returns:** (`any`)

##### `Iter:peek()`

Gets the next value in a list-iterator *without* consuming it.

**Example:**

```lua
local it = vim.iter({ 3, 6, 9, 12 })
it:peek() -- 3
it:peek() -- 3
it:next() -- 3
```

**Returns:** (`any`)

##### `Iter:pop()`

"Pops" a value from a list-iterator (gets last value and decrements tail).

**Example:**

```lua
local it = vim.iter({1, 2, 3, 4})
it:pop() -- 4
it:pop() -- 3
```

**Returns:** (`any`)

##### `Iter:rev()`

Reverses a list-iterator pipeline.

**Example:**

```lua
local it = vim.iter({ 3, 6, 9, 12 }):rev()
it:totable() -- { 12, 9, 6, 3 }
```

**Returns:** (`Iter`)

##### `Iter:rfind({f})`

Gets the first value satisfying a predicate, from the end of a list-iterator. Advances/drains iterator. Returns `nil` if not found.

**Examples:**

```lua
local it = vim.iter({ 1, 2, 3, 2, 1 }):enumerate()
it:rfind(1) -- 5, 1
it:rfind(1) -- 1, 1
```

**Parameters:**

* `f` (`any`)

**Returns:** (`any`)

**See also:** `Iter:find()`.

##### `Iter:rpeek()`

Gets the last value of a list-iterator *without* consuming it.

**Example:**

```lua
local it = vim.iter({1, 2, 3, 4})
it:rpeek() -- 4
it:rpeek() -- 4
it:pop()   -- 4
```

**Returns:** (`any`)

**See also:** `Iter:last()`.

##### `Iter:rskip({n})`

Discards `n` values from the end of a list-iterator pipeline.

**Example:**

```lua
local it = vim.iter({ 1, 2, 3, 4, 5 }):rskip(2)
it:next() -- 1
it:pop()  -- 3
```

**Parameters:**

* `n` (`number`): Number of values to skip.

**Returns:** (`Iter`)

##### `Iter:skip({n})`

Skips `n` values of an iterator pipeline from the beginning.

**Example:**

```lua
local it = vim.iter({ 3, 6, 9, 12 }):skip(2)
it:next() -- 9
```

**Parameters:**

* `n` (`number`): Number of values to skip.

**Returns:** (`Iter`)

##### `Iter:slice({first}, {last})`

Sets the start and end of a list-iterator pipeline. Equivalent to `:skip(first - 1):rskip(len - last + 1)`.

**Parameters:**

* `first` (`number`)
* `last` (`number`)

**Returns:** (`Iter`)

##### `Iter:take({n})`

Transforms an iterator to yield only the first `n` values.

**Example:**

```lua
local it = vim.iter({ 1, 2, 3, 4 }):take(2)
it:next() -- 1
it:next() -- 2
it:next() -- nil
```

**Parameters:**

* `n` (`integer`)

**Returns:** (`Iter`)

##### `Iter:totable()`

Collects the iterator into a table.

* Array-like tables and function iterators collected into array-like table.
* If multiple values returned from final stage, each value included in a sub-table.
* Generated table is array-like with consecutive, numeric indices. For map-like table, use `Iter:fold()`.

**Examples:**

```lua
vim.iter(string.gmatch('100 20 50', '%d+')):map(tonumber):totable()
-- { 100, 20, 50 }
vim.iter({ 1, 2, 3 }):map(function(v) return v, 2 * v end):totable()
-- { { 1, 2 }, { 2, 4 }, { 3, 6 } }
vim.iter({ a = 1, b = 2, c = 3 }):filter(function(k, v) return v % 2 ~= 0 end):totable()
-- { { 'a', 1 }, { 'c', 3 } }
```

**Returns:** (`table`)

---

## Lua module: `vim.snippet`

Provides functions for working with LSP-style text snippets.

##### `vim.snippet.ActiveFilter`

Fields for filtering active snippets:

* `direction` (`vim.snippet.Direction`): Navigation direction (`-1` for previous, `1` for next).

##### `vim.snippet.active({filter})`

Returns `true` if there's an active snippet in the current buffer, optionally applying a filter.

**Parameters:**

* `filter` (`vim.snippet.ActiveFilter?`): Filter. If `direction` is specified, returns `true` if snippet can be jumped in that direction.

**Returns:** (`boolean`)

##### `vim.snippet.expand({input})`

Expands the given snippet text (conforming to LSP snippet syntax). Tabstops are highlighted with `hl-SnippetTabstop`.

**Parameters:**

* `input` (`string`)

##### `vim.snippet.jump({direction})`

Jumps to the next (or previous) placeholder in the current snippet. By default, `<Tab>` is set up to jump if a snippet is active.

**Example Default Mapping (`<Tab>`):**

```lua
vim.keymap.set({ 'i', 's' }, '<Tab>', function()
   if vim.snippet.active({ direction = 1 }) then
     return '<Cmd>lua vim.snippet.jump(1)<CR>'
   else
     return '<Tab>'
   end
 end, { descr = '...', expr = true, silent = true })
```

**Parameters:**

* `direction` (`vim.snippet.Direction`): Navigation direction (`-1` for previous, `1` for next).

##### `vim.snippet.stop()`

Exits the current snippet.

---

## Lua module: `vim.text`

Provides text manipulation utilities.

##### `vim.text.hexdecode({enc})`

Hex decodes a string.

**Parameters:**

* `enc` (`string`): String to decode.

**Returns:** (`string?`, `string?`): Decoded string, and error message if any.

##### `vim.text.hexencode({str})`

Hex encodes a string.

**Parameters:**

* `str` (`string`): String to encode.

**Returns:** (`string`): Hex encoded string.

##### `vim.text.indent({size}, {text}, {opts})`

Sets the common leading whitespace (indent) of non-empty lines in `text` to `size` spaces/tabs.

**Key Facts:**

* Indent is calculated by number of consecutive indent characters.
* First indented, non-empty line determines indent character (space/tab).
* `opts.expandtab` treats tabs as spaces.
* To "dedent" (remove common indent), pass `size=0`.
* To adjust relative to existing indent, call `indent()` twice.
* To ignore trailing blank lines, use `gsub()` before calling `indent()`.

**Parameters:**

* `size` (`integer`): Number of spaces.
* `text` (`string`): Text to indent.
* `opts` (`{ expandtab?: integer }?`)

**Returns:** (`string`, `integer`): Indented text, and original indent size.

**Examples:**

```lua
vim.print(vim.text.indent(0, ' a\n  b\n')) -- Dedent
-- Output will remove common leading space

local text = '  a\n  b\n '
vim.print(vim.text.indent(0, (text:gsub('\n[\t ]+\n?$', '\n')))) -- Dedent, ignoring final blank line
```

---

## Lua module: `vim.tohtml`

Provides functionality to convert buffer content to HTML.

##### `:[range]TOhtml {file}`

Converts the buffer in the current window to HTML, opens it in a new split window, and saves to `{file}`. If `{file}` is omitted, a temporary file is used.

##### `tohtml.tohtml({winid}, {opt})`

Converts the buffer shown in window `{winid}` to HTML and returns the output as a list of strings.

**Parameters:**

* `winid` (`integer?`): Window to convert (defaults to current).
* `opt` (`table?`): Optional parameters.
  * `title` (`string|false`): Title tag (default: buffer name).
  * `number_lines` (`boolean`): Show line numbers (default: `false`).
  * `font` (`string[]|string`): Fonts to use (default: `guifont`).
  * `width` (`integer`): Width for right-aligned/repeating characters (default: `'textwidth'` or window width).
  * `range` (`integer[]`): Range of rows (default: entire buffer).

**Returns:** (`string[]`)

---
