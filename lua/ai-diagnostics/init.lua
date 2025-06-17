---@mod ai-diagnostics Simple diagnostic output formatting for AI
---@brief [[
--- Formats Neovim diagnostics with surrounding code context for sharing with AI assistants.
--- Provides basic line context and severity information in a clear, readable format.
---@brief ]]

local config = require("ai-diagnostics.config")

-- Services
local DiagnosticService = require("ai-diagnostics.services.diagnostic_service")
local FormatterService = require("ai-diagnostics.services.formatter_service")
local WindowService = require("ai-diagnostics.services.window_service")
local Logger = require("ai-diagnostics.infrastructure.logger")
local ConfigValidator = require("ai-diagnostics.infrastructure.config_validator")

local M = {
	config = {},
	-- Service instances
	_diagnostic_service = nil,
	_formatter_service = nil,
	_window_service = nil,
	_logger = nil,
}


---Setup the plugin with user configuration
---@param user_config table|nil Optional configuration table with before_lines and after_lines
function M.setup(user_config)
	-- Wrap config initialization in pcall
	local status, err = pcall(function()
		if user_config then
			local valid, err = ConfigValidator.validate(user_config)
			if not valid then
				error(err)
			end
		end
		M.config = vim.tbl_deep_extend("force", config.default_config, user_config or {})
	end)

	if not status then
		vim.notify("AI Diagnostics config error: " .. tostring(err), vim.log.levels.ERROR)
		return
	end


	-- Initialize new logger
	if M.config.log and M.config.log.enabled then
		local log_config = {
			level = M.config.log.level == "DEBUG" and Logger.levels.DEBUG or Logger.levels.INFO,
			file = M.config.log.file or vim.fn.stdpath("cache") .. "/ai-diagnostics.log",
		}
		M._logger = Logger:new(log_config)
	else
		-- Create a no-op logger
		M._logger = {
			debug = function() end,
			info = function() end,
			warn = function() end,
			error = function() end,
		}
	end

	-- Initialize services
	M._diagnostic_service = DiagnosticService:new(M.config, M._logger)
	M._formatter_service = FormatterService:new(M.config)
	M._window_service = WindowService:new()


	-- Set up diagnostic change autocmd if live updates enabled
	if M.config.live_updates then
		local group = vim.api.nvim_create_augroup("AIDiagnosticsUpdates", { clear = true })
		pcall(vim.api.nvim_create_autocmd, "DiagnosticChanged", {
			group = group,
			callback = function()
				if M._window_service:is_open() then
					M.show_diagnostics_window()
				end
			end,
		})

		pcall(vim.api.nvim_create_autocmd, { "BufDelete", "BufUnload" }, {
			group = group,
			callback = function()
				if M._window_service:is_open() then
					M.show_diagnostics_window()
				end
			end,
		})
	end

	-- Create commands safely
	pcall(function()
		vim.api.nvim_create_user_command("AIDiagnosticsShow", function(opts)
			M.show_diagnostics_window(opts.args)
		end, {
			nargs = "?",
			complete = function()
				return { "bottom", "right" }
			end,
		})

		vim.api.nvim_create_user_command("AIDiagnosticsClose", function()
			M.close_diagnostics_window()
		end, {})

		vim.api.nvim_create_user_command("AIDiagnosticsToggle", function(opts)
			M.toggle_diagnostics_window(opts.args)
		end, {
			nargs = "?",
			complete = function()
				return { "bottom", "right" }
			end,
		})
	end)
end

---Get formatted diagnostics for a buffer
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string Formatted diagnostic output with context
function M.get_buffer_diagnostics(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	
	local result = M._diagnostic_service:get_buffer_diagnostics(bufnr)
	if result.is_ok then
		-- Format single file diagnostics
		local file_map = {}
		file_map[result.value.filename] = result.value
		return M._formatter_service:format(file_map)
	else
		M._logger:debug("Failed to get buffer diagnostics: " .. result.error)
		return ""
	end
end

---Get diagnostics for all valid buffers in the workspace
---@return string Formatted diagnostic output for all buffers
function M.get_workspace_diagnostics()
	local result = M._diagnostic_service:get_workspace_diagnostics()
	if result.is_ok then
		return M._formatter_service:format(result.value)
	else
		M._logger:warn("Failed to get workspace diagnostics: " .. result.error)
		return result.error
	end
end

---Show diagnostics in a split window
---@param position string|nil "bottom" or "right" (defaults to "bottom")
function M.show_diagnostics_window(position)
	local content = M.get_workspace_diagnostics()
	M._window_service:open(position)
	M._window_service:update_content(content)
end

---Close the diagnostics window
function M.close_diagnostics_window()
	M._window_service:close()
end

---Toggle the diagnostics window
---@param position string|nil "bottom" or "right" (defaults to "bottom")
function M.toggle_window(position)
	if M._window_service:is_open() then
		M.close_diagnostics_window()
	else
		M.show_diagnostics_window(position)
	end
end


return M
