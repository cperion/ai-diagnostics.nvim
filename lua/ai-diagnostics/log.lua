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
    
    local file = io.open(config.file, "a")
    if not file then return end
    
    -- Check file size
    local size = file:seek("end")
    if size > config.max_size then
        file:close()
        -- Rotate log file
        os.rename(config.file, config.file .. ".old")
        file = io.open(config.file, "w")
    end
    
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
        
        -- Create logs directory if it doesn't exist
        local log_dir = vim.fn.fnamemodify(config.file, ":h")
        if vim.fn.isdirectory(log_dir) == 0 then
            vim.fn.mkdir(log_dir, "p")
        end
    end
end

return M
