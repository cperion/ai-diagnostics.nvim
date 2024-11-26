local M = {}

-- Log levels
M.levels = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

local level_strings = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR"
}

local config = {
    level = M.levels.INFO,
    file = nil,
    max_size = 1024 * 1024, -- 1MB
}

local function format_log(level, msg)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    return string.format("[%s] [%s] %s\n", timestamp, level_strings[level], msg)
end

local function write_to_file(msg)
    if not config.file then return end
    
    -- Open file in append mode
    local mode = vim.v.vim_did_enter and "a" or "w"  -- Overwrite on first open, append after
    local file = io.open(config.file, mode)
    if not file then return end
    
    file:write(msg)
    file:close()
end

function M.log(level, msg)
    if level >= config.level then
        local formatted = format_log(level, msg)
        write_to_file(formatted)
    end
end

function M.debug(msg) M.log(M.levels.DEBUG, msg) end
function M.info(msg) M.log(M.levels.INFO, msg) end
function M.warn(msg) M.log(M.levels.WARN, msg) end
function M.error(msg) M.log(M.levels.ERROR, msg) end

function M.setup(opts)
    if opts then
        config.level = opts.level or config.level
        config.file = opts.file or config.file
        config.max_size = opts.max_size or config.max_size
        
        if config.file then
            -- Create full directory path
            local log_dir = vim.fn.fnamemodify(config.file, ":h")
            -- Use recursive directory creation with full path
            local ok, err = pcall(function()
                vim.fn.mkdir(log_dir, "p")
            end)
            
            if not ok then
                vim.notify("Failed to create log directory: " .. tostring(err), vim.log.levels.ERROR)
                -- Disable logging if we can't create the directory
                config.file = nil
            end
        end
    end
end

return M
