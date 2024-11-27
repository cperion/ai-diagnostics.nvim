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

local M = {
	config = {},
}

---Validate configuration table
---@param cfg table Configuration to validate
---@return boolean valid
---@return string? error_message
local function validate_config(cfg)
	if cfg.before_lines and type(cfg.before_lines) ~= "number" then
		return false, "before_lines must be a number"
	end
	if cfg.after_lines and type(cfg.after_lines) ~= "number" then
		return false, "after_lines must be a number"
	end
	if cfg.max_line_length and type(cfg.max_line_length) ~= "number" then
		return false, "max_line_length must be a number"
	end
	if cfg.show_line_numbers ~= nil and type(cfg.show_line_numbers) ~= "boolean" then
		return false, "show_line_numbers must be a boolean"
	end
	return true
end

---Setup the plugin with user configuration
---@param user_config table|nil Optional configuration table with before_lines and after_lines
function M.setup(user_config)
	-- Wrap config initialization in pcall
	local status, err = pcall(function()
		if user_config then
			local valid, err = validate_config(user_config)
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

	-- Setup logging with pcall
	if M.config.log and M.config.log.enabled then
		pcall(function()
			if not M.config.log.file then
				M.config.log.file = vim.fn.stdpath("cache") .. "/ai-diagnostics.log"
			end
			log.setup({
				level = M.config.log.level == "DEBUG" and log.levels.DEBUG or log.levels.INFO,
				file = M.config.log.file,
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

	local diagnostics = vim.diagnostic.get(bufnr)
	log.debug(string.format("Raw diagnostics count: %d", #diagnostics))

	-- Log each diagnostic for debugging
	for i, diag in ipairs(diagnostics) do
		local severity_str = diag.severity and vim.diagnostic.severity[diag.severity] or "UNKNOWN"
		local line_num = "unknown"

		-- Get line number directly from diagnostic
		line_num = diag.lnum and tostring(diag.lnum) or "unknown"

		log.debug(
			string.format(
				"Diagnostic %d: severity=%s, message=%s, line=%s",
				i,
				severity_str,
				diag.message or "no message",
				tostring(line_num)
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

---Get diagnostics for all buffers
---@return string Formatted diagnostic output for all buffers
function M.get_workspace_diagnostics()
	local all_diagnostics = {}
	local has_content = false
	log.debug("Getting workspace diagnostics")

	-- Get list of valid buffers with files
	local valid_buffers = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		log.debug(
			string.format(
				"Checking buffer %d: valid=%s, loaded=%s, name='%s'",
				bufnr,
				tostring(vim.api.nvim_buf_is_valid(bufnr)),
				tostring(vim.api.nvim_buf_is_loaded(bufnr)),
				vim.api.nvim_buf_get_name(bufnr)
			)
		)

		if
			vim.api.nvim_buf_is_valid(bufnr)
			and vim.api.nvim_buf_is_loaded(bufnr)
			and vim.api.nvim_buf_get_name(bufnr) ~= ""
		then
			table.insert(valid_buffers, bufnr)
		end
	end

	-- Log number of valid buffers found
	log.debug(string.format("Found %d valid buffers", #valid_buffers))

	-- Check if we have any valid buffers
	if #valid_buffers == 0 then
		log.debug("No valid buffers found")
		return "No valid buffers found"
	end

	-- Process each valid buffer
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
	ui.open_window(position)
	ui.update_content(content)
end

---Close the diagnostics window
function M.close_diagnostics_window()
	ui.close_window()
end

---Toggle the diagnostics window
---@param position string|nil "bottom" or "right" (defaults to "bottom")
function M.toggle_window(position)
	if ui.is_open() then
		ui.close_window()
	else
		M.show_diagnostics_window(position)
	end
end

-- Alias for backward compatibility
M.toggle_diagnostics_window = M.toggle_window

function M.close_window()
	if M.is_open() then
		local win_id = M.state.win_id
		local buf_id = M.state.buf_id

		-- Fermeture de la fenêtre
		vim.api.nvim_win_close(win_id, true)

		-- Nettoyage du buffer s'il existe et est valide
		if buf_id and vim.api.nvim_buf_is_valid(buf_id) then
			vim.api.nvim_buf_delete(buf_id, { force = true })
		end

		-- Réinitialisation de l'état
		M.state.win_id = nil
		M.state.buf_id = nil
	end
end

return M
