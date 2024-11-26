local M = {}

---Get context lines around a diagnostic
---@param bufnr number Buffer number
---@param diagnostic table The diagnostic to get context for
---@param config table Configuration options
---@return table[] Array of line information
function M.get_diagnostic_context(bufnr, diagnostic, config)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		vim.notify("Invalid buffer", vim.log.levels.ERROR)
		return {}
	end

	-- Add validation for diagnostic structure
	if not diagnostic then
		vim.notify("Invalid diagnostic", vim.log.levels.ERROR)
		return {}
	end

	-- Ensure diagnostic has range information
	local range = diagnostic.range or {}
	local start_pos = range.start or {}
	local end_pos = range["end"] or {}

	-- Get line numbers with defaults
	local start_line = start_pos.line or 0
	local end_line = end_pos.line or start_line

	-- Calculate context range with bounds checking
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local context_start = math.max(0, start_line - config.before_lines)
	local context_end = math.min(line_count - 1, end_line + config.after_lines)

	-- Get buffer lines
	local buf_lines = vim.api.nvim_buf_get_lines(bufnr, context_start, context_end + 1, false)

	-- Format lines with line numbers and markers
	local lines = {}
	for i, line in ipairs(buf_lines) do
		local line_num = context_start + i
		local is_diagnostic_line = line_num >= start_line and line_num <= end_line

		table.insert(lines, {
			number = line_num + 1,
			content = line,
			is_diagnostic = is_diagnostic_line,
		})
	end

	return lines
end

return M
