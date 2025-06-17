---@class Logger
---@field level number Log level
---@field file string|nil Log file path
---@field file_handle file*|nil Open file handle
local Logger = {}
Logger.__index = Logger

-- Map numeric levels to string representations
local level_strings = {
    [vim.log.levels.DEBUG] = "DEBUG",
    [vim.log.levels.INFO] = "INFO",
    [vim.log.levels.WARN] = "WARN",
    [vim.log.levels.ERROR] = "ERROR",
    [vim.log.levels.TRACE] = "TRACE",
    [vim.log.levels.OFF] = "OFF",
}

---Create a new logger instance
---@param config table Logger configuration
---@return Logger
function Logger:new(config)
    local instance = setmetatable({}, self)
    
    instance.level = config.level or vim.log.levels.INFO
    instance.file = config.file
    
    if instance.file then
        -- Ensure directory exists
        local dir = vim.fn.fnamemodify(instance.file, ":h")
        vim.fn.mkdir(dir, "p")
        
        -- Open file in append mode
        local file, err = io.open(instance.file, "a")
        if file then
            instance.file_handle = file
        else
            vim.notify("Failed to open log file: " .. tostring(err), vim.log.levels.ERROR)
        end
    end
    
    return instance
end

---Log a message at the specified level
---@param level number Log level
---@param message string Message to log
function Logger:log(level, message)
    if level < self.level then
        return
    end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local formatted = string.format("[%s] [%s] %s\n", timestamp, level_strings[level] or "UNKNOWN", message)
    
    if self.file_handle then
        self.file_handle:write(formatted)
        self.file_handle:flush()
    end
end

---Log debug message
---@param message string
function Logger:debug(message)
    self:log(vim.log.levels.DEBUG, message)
end

---Log info message
---@param message string
function Logger:info(message)
    self:log(vim.log.levels.INFO, message)
end

---Log warning message
---@param message string
function Logger:warn(message)
    self:log(vim.log.levels.WARN, message)
end

---Log error message
---@param message string
function Logger:error(message)
    self:log(vim.log.levels.ERROR, message)
end

---Close the logger
function Logger:close()
    if self.file_handle then
        self.file_handle:close()
        self.file_handle = nil
    end
end

return Logger
