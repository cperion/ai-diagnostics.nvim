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

	local start_line = diagnostic.range.start.line
	local end_line = diagnostic.range["end"].line

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
