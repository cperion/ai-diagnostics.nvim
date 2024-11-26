---@mod ai-diagnostics Simple diagnostic output formatting for AI
---@brief [[
--- Formats Neovim diagnostics with surrounding code context for sharing with AI assistants.
--- Provides basic line context and severity information in a clear, readable format.
---@brief ]]

local config = require("ai-diagnostics.config")
local context = require("ai-diagnostics.context")
local format = require("ai-diagnostics.format")
local ui = require("ai-diagnostics.ui")

local M = {
	config = {},
}

---Setup the plugin with user configuration
---@param user_config table|nil Optional configuration table with before_lines and after_lines
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", config.default_config, user_config or {})
	
	-- Set up diagnostic change autocmd if live updates enabled
	if M.config.live_updates then
		vim.api.nvim_create_autocmd("DiagnosticChanged", {
			callback = function()
				if ui.win_id and vim.api.nvim_win_is_valid(ui.win_id) then
					local content = M.get_workspace_diagnostics()
					ui.update_content(content)
				end
			end,
		})
	end
	
	-- Create commands
	vim.api.nvim_create_user_command('AIDiagnosticsShow', function(opts)
		M.show_diagnostics_window(opts.args)
	end, {
		nargs = '?',
		complete = function()
			return { 'bottom', 'right' }
		end
	})
	
	vim.api.nvim_create_user_command('AIDiagnosticsClose', function()
		M.close_diagnostics_window()
	end, {})
	
	vim.api.nvim_create_user_command('AIDiagnosticsToggle', function(opts)
		M.toggle_diagnostics_window(opts.args)
	end, {
		nargs = '?',
		complete = function()
			return { 'bottom', 'right' }
		end
	})
end

---Get formatted diagnostics for a buffer
---@param bufnr number|nil Buffer number (defaults to current buffer)
---@return string Formatted diagnostic output with context
function M.get_buffer_diagnostics(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		vim.notify("Invalid buffer", vim.log.levels.ERROR)
		return ""
	end
    local diagnostics = vim.diagnostic.get(bufnr)
    if #diagnostics == 0 then
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

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			local buf_diagnostics = M.get_buffer_diagnostics(bufnr)
			if buf_diagnostics ~= "" then
				table.insert(all_diagnostics, buf_diagnostics)
			end
		end
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
	if ui.win_id and vim.api.nvim_win_is_valid(ui.win_id) then
		ui.close_window()
	else
		M.show_diagnostics_window(position)
	end
end

return M
