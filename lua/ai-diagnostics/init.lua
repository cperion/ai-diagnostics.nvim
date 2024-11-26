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
---@return boolean, string? valid, error_message
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
    return true
end

---Setup the plugin with user configuration
---@param user_config table|nil Optional configuration table with before_lines and after_lines
function M.setup(user_config)
    if user_config then
        local valid, err = validate_config(user_config)
        if not valid then
            vim.notify("AI Diagnostics config error: " .. err, vim.log.levels.ERROR)
            return
        end
    end
    
    M.config = vim.tbl_deep_extend("force", config.default_config, user_config or {})
	
	-- Setup logging
	if M.config.log.enabled then
		local ok, err = pcall(function()
			log.setup({
				level = log.levels[M.config.log.level] or log.levels.INFO,
				file = M.config.log.file,
				max_size = M.config.log.max_size
			})
		end)
		
		if not ok then
			vim.notify("Failed to initialize logging: " .. tostring(err), vim.log.levels.WARN)
		else
			log.info("AI Diagnostics plugin initialized")
		end
	end

	-- Set up diagnostic change autocmd if live updates enabled
	if M.config.live_updates then
		vim.api.nvim_create_autocmd("DiagnosticChanged", {
			callback = function()
				if ui.state.win_id and vim.api.nvim_win_is_valid(ui.state.win_id) then
					local content = M.get_workspace_diagnostics()
					ui.update_content(content)
				end
			end,
		})
	end

	-- Create commands
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
end

---Get formatted diagnostics for a buffer
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string Formatted diagnostic output with context
function M.get_buffer_diagnostics(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		local msg = string.format("Invalid buffer %s. Buffer may have been closed or deleted.", tostring(bufnr))
		log.error(msg)
		vim.notify(msg, vim.log.levels.ERROR)
		return ""
	end
	
	local diagnostics = vim.diagnostic.get(bufnr)
	log.debug(string.format("Got %d diagnostics for buffer %d", #diagnostics, bufnr))
	
	if not diagnostics or #diagnostics == 0 then
		log.debug("No diagnostics found for buffer " .. tostring(bufnr))
		return ""
	end

	local contexts = {}
	local filenames = {}
	local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")

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

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local buf_diagnostics = M.get_buffer_diagnostics(bufnr)
			if buf_diagnostics ~= "" then
				table.insert(all_diagnostics, buf_diagnostics)
				has_content = true
			end
		end
	end

	if not has_content then
		return "No diagnostics found in workspace"
	end

	return table.concat(all_diagnostics, "\n\n")
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
function M.toggle_diagnostics_window(position)
	if ui.is_open() then
		ui.close_window()
	else
		M.show_diagnostics_window(position)
	end
end

return M
