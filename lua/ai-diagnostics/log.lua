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
    [4] = "ERROR",
}

-- Internal state
local config = {
    level = M.levels.INFO,
    file = nil,
    max_size = 1024 * 1024, -- 1MB
    silent = false, -- Don't show notifications when true
}

-- Thread safety flags
local is_writing = false
local write_queue = {}
local last_error_time = 0
local ERROR_THROTTLE_MS = 1000 -- Minimum ms between error notifications

local function format_log(level, msg)
    if type(msg) ~= "string" then
        msg = vim.inspect(msg)
    end
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    return string.format("[%s] [%s] %s\n", timestamp, level_strings[level], msg)
end

local function notify_error(msg)
    if config.silent then return end
    
    -- Throttle error notifications
    local current_time = vim.loop.now()
    if current_time - last_error_time >= ERROR_THROTTLE_MS then
        vim.schedule(function()
            vim.notify(msg, vim.log.levels.ERROR)
        end)
        last_error_time = current_time
    end
end

local function process_write_queue()
    if #write_queue == 0 or is_writing then return end
    
    is_writing = true
    local msg = table.remove(write_queue, 1)

    -- Ensure directory exists
    local dir = vim.fn.fnamemodify(config.file, ":h")
    local mkdir_ok = pcall(vim.fn.mkdir, dir, "p")
    
    if not mkdir_ok then
        notify_error(string.format("Failed to create log directory '%s'", dir))
        is_writing = false
        process_write_queue()
        return
    end

    -- Check file size
    local current_size = 0
    local stat = vim.loop.fs_stat(config.file)
    if stat then
        current_size = stat.size
    end

    if current_size >= config.max_size then
        -- Rotate log file
        local backup = config.file .. ".old"
        pcall(vim.loop.fs_unlink, backup)
        pcall(vim.loop.fs_rename, config.file, backup)
    end

    -- Write to file
    local file = io.open(config.file, "a")
    if not file then
        notify_error(string.format("Failed to open log file '%s'", config.file))
        is_writing = false
        process_write_queue()
        return
    end

    local ok = pcall(function()
        file:write(msg)
        file:flush()
        file:close()
    end)

    if not ok then
        notify_error("Failed to write to log file")
    end

    is_writing = false
    vim.schedule(process_write_queue)
end

local function write_to_file(msg)
    if not config.file then return end
    table.insert(write_queue, msg)
    vim.schedule(process_write_queue)
end

function M.log(level, msg)
    if level >= config.level then
        local formatted = format_log(level, msg)
        write_to_file(formatted)
    end
end

function M.debug(msg) M.log(M.levels.DEBUG, msg) end
function M.info(msg)  M.log(M.levels.INFO, msg)  end
function M.warn(msg)  M.log(M.levels.WARN, msg)  end
function M.error(msg) M.log(M.levels.ERROR, msg) end

function M.setup(opts)
	if opts then
		config.level = opts.level or config.level
		config.file = opts.file or config.file
		config.max_size = opts.max_size or config.max_size

		if config.file then
			-- Expand the path fully
			config.file = vim.fn.expand(config.file)

			-- Get the directory path
			local log_dir = vim.fn.fnamemodify(config.file, ":h")

			-- First check if the directory exists and is actually a directory
			local dir_stat = vim.uv.fs_stat(log_dir)
			if dir_stat then
				if dir_stat.type ~= "directory" then
					-- If it exists but is not a directory, try to remove it
					local success = vim.uv.fs_unlink(log_dir)
					if not success then
						error(string.format("Cannot create log directory: '%s' exists and is not a directory", log_dir))
						return
					end
				end
			end

			-- Now try to create the directory
			local mkdir_ok, mkdir_err = pcall(function()
				vim.fn.mkdir(log_dir, "p")
			end)

			if not mkdir_ok then
				error(string.format("Failed to create log directory '%s': %s", log_dir, tostring(mkdir_err)))
				return
			end

			-- Try to create/open the log file
			local file = io.open(config.file, "a+")
			if not file then
				error(string.format("Failed to create/open log file '%s'", config.file))
				return
			end
			file:close()

			-- Write initial log entry
			M.info(string.format("Log file initialized at '%s'", config.file))
		end
	end
end

return M
