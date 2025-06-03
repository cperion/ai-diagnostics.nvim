---@mod ai-diagnostics Simple diagnostic output formatting for AI
---@brief [[
--- Formats Neovim diagnostics with surrounding code context for sharing with AI assistants.
--- Provides basic line context and severity information in a clear, readable format.
---@brief ]]

local config = require("ai-diagnostics.config")
local context = require("ai-diagnostics.context")
local format = require("ai-diagnostics.format")
local ui = require("ai-diagnostics.ui")
local log = require("ai-diagnostics.log")

-- New services
local DiagnosticService = require("ai-diagnostics.services.diagnostic_service")
local FormatterService = require("ai-diagnostics.services.formatter_service")
local WindowService = require("ai-diagnostics.services.window_service")
local Logger = require("ai-diagnostics.infrastructure.logger")

local M = {
	config = {},
	-- Service instances
	_diagnostic_service = nil,
	_formatter_service = nil,
	_window_service = nil,
	_logger = nil,
}

-- Use new config validator
local ConfigValidator = require("ai-diagnostics.infrastructure.config_validator")

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

	-- Setup UI first
	ui.setup()

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

	-- Keep legacy logging for backwards compatibility during transition
	if M.config.log and M.config.log.enabled then
		pcall(function()
			log.setup({
				level = M.config.log.level == "DEBUG" and log.levels.DEBUG or log.levels.INFO,
				file = M.config.log.file or vim.fn.stdpath("cache") .. "/ai-diagnostics.log",
				max_size = M.config.log.max_size,
			})
		end)
	end

	-- Set up diagnostic change autocmd if live updates enabled
	if M.config.live_updates then
		local group = vim.api.nvim_create_augroup("AIDiagnosticsUpdates", { clear = true })
		pcall(vim.api.nvim_create_autocmd, "DiagnosticChanged", {
			group = group,
			callback = function()
				if ui.is_open() then
					M.show_diagnostics_window()
				end
			end,
		})

		pcall(vim.api.nvim_create_autocmd, { "BufDelete", "BufUnload" }, {
			group = group,
			callback = function()
				if ui.is_open() then
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
	log.debug(string.format("Getting diagnostics for buffer %d", bufnr))

	-- Check if buffer is valid and loaded
	if not (vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr)) then
		log.debug("Buffer is not valid or not loaded: " .. tostring(bufnr))
		return ""
	end

	-- Check if buffer has a valid file path
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	log.debug(string.format("Buffer name: '%s'", bufname))
	if bufname == "" then
		log.debug("Buffer has no file path")
		return ""
	end

	-- Check for LSP clients
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	log.debug(string.format("Found %d LSP clients for buffer", #clients))
	if #clients == 0 then
		log.debug("No LSP clients attached to buffer " .. tostring(bufnr))
		return ""
	end

	local diagnostics = vim.diagnostic.get(bufnr, { severity = M.config.severity })
	if not diagnostics then
		log.debug("No raw diagnostics found for buffer")
		return ""
	end

	-- Filter and validate diagnostics
	log.debug(string.format("Filtered diagnostics count: %d", #diagnostics))

	-- Enhanced diagnostic logging
	for i, diag in ipairs(diagnostics) do
		local severity_name = vim.diagnostic.severity[diag.severity] or "UNKNOWN"
		local line_num = diag.lnum + 1 -- Convert to 1-based line numbers

		log.debug(
			string.format(
				"Diagnostic[%d]: severity=%s(%d), line=%d, col=%d, message='%s'",
				i,
				severity_name,
				diag.severity,
				line_num,
				diag.col or 0,
				diag.message or ""
			)
		)
	end

	if not diagnostics or #diagnostics == 0 then
		log.debug("No diagnostics found for buffer " .. tostring(bufnr))
		return ""
	end

	local contexts = {}
	local filenames = {}
	local filename = vim.fn.fnamemodify(bufname, ":.")

	for _, diagnostic in ipairs(diagnostics) do
		local diag_context = context.get_diagnostic_context(bufnr, diagnostic, M.config)
		table.insert(contexts, diag_context)
		table.insert(filenames, filename)
	end

	return format.format_diagnostic_with_context(diagnostics, contexts, filenames)
end

---Get diagnostics for all valid buffers in the workspace
---@return string Formatted diagnostic output for all buffers
function M.get_workspace_diagnostics()
	-- Try to use new service first
	if M._diagnostic_service and M._formatter_service then
		local result = M._diagnostic_service:get_workspace_diagnostics()
		if result.is_ok then
			return M._formatter_service:format(result.value)
		else
			M._logger:debug("New service error: " .. result.error)
			-- Fall back to legacy implementation
		end
	end

	-- Legacy implementation
	local all_diagnostics = {}
	log.debug("Getting workspace diagnostics")

	-- Get list of valid buffers with files
	local valid_buffers = vim.tbl_filter(function(bufnr)
		local is_valid = vim.api.nvim_buf_is_valid(bufnr)
		local is_loaded = vim.api.nvim_buf_is_loaded(bufnr)
		local has_name = vim.api.nvim_buf_get_name(bufnr) ~= ""

		log.debug(
			string.format(
				"Buffer %d: valid=%s, loaded=%s, has_name=%s",
				bufnr,
				tostring(is_valid),
				tostring(is_loaded),
				tostring(has_name)
			)
		)

		return is_valid and is_loaded and has_name
	end, vim.api.nvim_list_bufs())

	-- Log number of valid buffers found
	log.debug(string.format("Found %d valid buffers", #valid_buffers))

	-- Check if we have any valid buffers
	if #valid_buffers == 0 then
		log.debug("No valid buffers found")
		return "No valid buffers found"
	end

	-- Process each valid buffer
	local has_content = false
	for _, bufnr in ipairs(valid_buffers) do
		log.debug(string.format("Processing buffer %d", bufnr))
		local buf_diagnostics = M.get_buffer_diagnostics(bufnr)
		if buf_diagnostics ~= "" then
			table.insert(all_diagnostics, buf_diagnostics)
			has_content = true
		end
	end

	if not has_content then
		log.debug("No diagnostics found in workspace")
		return "No diagnostics found in workspace"
	end

	local result = table.concat(all_diagnostics, "\n\n")
	log.debug(string.format("Final diagnostic content length: %d", #result))
	return result
end

---Show diagnostics in a split window
---@param position string|nil "bottom" or "right" (defaults to "bottom")
function M.show_diagnostics_window(position)
	local content = M.get_workspace_diagnostics()
	
	-- Use new window service if available
	if M._window_service then
		M._window_service:open(position)
		M._window_service:update_content(content)
	else
		-- Fallback to legacy UI
		ui.open_window(position)
		ui.update_content(content)
	end
end

---Close the diagnostics window
function M.close_diagnostics_window()
	-- Use new window service if available
	if M._window_service then
		M._window_service:close()
	else
		-- Fallback to legacy UI
		ui.close_window()
	end
end

---Toggle the diagnostics window
---@param position string|nil "bottom" or "right" (defaults to "bottom")
function M.toggle_window(position)
	-- Use new window service if available
	if M._window_service then
		M._window_service:toggle(position)
	else
		-- Fallback to legacy UI
		if ui.is_open() then
			ui.close_window()
		else
			M.show_diagnostics_window(position)
		end
	end
end

-- Alias for backward compatibility
M.toggle_diagnostics_window = M.toggle_window


return M
