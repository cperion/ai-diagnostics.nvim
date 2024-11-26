---@mod ai-diagnostics Simple diagnostic output formatting for AI
---@brief [[
--- Formats Neovim diagnostics with surrounding code context for sharing with AI assistants.
--- Provides basic line context and severity information in a clear, readable format.
---@brief ]]

local config = require("ai-diagnostics.config")
local context = require("ai-diagnostics.context")
local format = require("ai-diagnostics.format")

local M = {
	config = {},
}

---Setup the plugin with user configuration
---@param user_config table|nil Optional configuration table with before_lines and after_lines
function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", config.default_config, user_config or {})
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

	local formatted = {}
	local filename = vim.api.nvim_buf_get_name(bufnr)
	if filename ~= "" then
		table.insert(formatted, string.format("File: %s\n", vim.fn.fnamemodify(filename, ":.")))
	end

	for _, diagnostic in ipairs(diagnostics) do
		local diag_context = context.get_diagnostic_context(bufnr, diagnostic, M.config)
		table.insert(formatted, format.format_diagnostic_with_context(diagnostic, diag_context))
	end

	return table.concat(formatted, "\n\n")
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

return M
