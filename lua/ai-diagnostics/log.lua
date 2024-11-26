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

local config = {
	level = M.levels.INFO,
	file = nil,
	max_size = 1024 * 1024, -- 1MB
}

local function format_log(level, msg)
	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	return string.format("[%s] [%s] %s\n", timestamp, level_strings[level], msg)
end

local is_writing = false

local function write_to_file(msg)
	if not config.file or is_writing then
		return
	end

	is_writing = true

	-- Ensure directory exists before writing
	local dir = vim.fn.fnamemodify(config.file, ":h")

	-- Create directory with "p" flag BEFORE trying to open the file
	local mkdir_ok = pcall(function()
		vim.fn.mkdir(dir, "p")
	end)

	if not mkdir_ok then
		vim.notify(string.format("Failed to create log directory '%s'", dir), vim.log.levels.ERROR)
		is_writing = false
		return
	end

	-- Always open in write mode to overwrite
	local file = io.open(config.file, "w")
	if not file then
		vim.notify(string.format("Failed to open log file '%s' for writing", config.file), vim.log.levels.ERROR)
		is_writing = false
		return
	end

	local ok, err = pcall(function()
		file:write(msg)
		file:close()
	end)

	if not ok then
		vim.notify(string.format("Failed to write to log file: %s", err), vim.log.levels.ERROR)
	end

	is_writing = false
end

function M.log(level, msg)
	if level >= config.level then
		local formatted = format_log(level, msg)
		write_to_file(formatted)
	end
end

function M.debug(msg)
	M.log(M.levels.DEBUG, msg)
end
function M.info(msg)
	M.log(M.levels.INFO, msg)
end
function M.warn(msg)
	M.log(M.levels.WARN, msg)
end
function M.error(msg)
	M.log(M.levels.ERROR, msg)
end

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
