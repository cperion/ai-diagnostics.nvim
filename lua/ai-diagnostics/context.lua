local log = require("ai-diagnostics.log")
local M = {}

---Get context lines around a diagnostic
---@param bufnr number Buffer number
---@param diagnostic table The diagnostic to get context for
---@param config table Configuration options
---@return table[] Array of line information
function M.get_diagnostic_context(bufnr, diagnostic, config)
	log.debug(string.format("Getting context for diagnostic in buffer %d", bufnr))
	log.debug(
		string.format(
			"Diagnostic info: severity=%s, message='%s', lnum=%s, end_lnum=%s",
			tostring(diagnostic.severity),
			diagnostic.message or "no message",
			tostring(diagnostic.lnum),
			tostring(diagnostic.end_lnum)
		)
	)

	if not vim.api.nvim_buf_is_valid(bufnr) then
		log.error("Invalid buffer")
		return {}
	end

	-- Add validation for diagnostic structure
	if not diagnostic then
		log.error("Invalid diagnostic")
		return {}
	end

	-- Get line numbers from diagnostic (keeping 0-based for compatibility)
	local start_line = diagnostic.lnum or 0
	local end_line = diagnostic.end_lnum or start_line

	-- Log diagnostic structure
	log.debug(string.format("Processing diagnostic - start_line: %d, end_line: %d", start_line, end_line))

	-- Calculate context range with bounds checking
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local context_start = math.max(0, start_line - (config.before_lines or 2))
	local context_end = math.min(line_count - 1, end_line + (config.after_lines or 2))

	-- Get buffer lines
	local buf_lines = vim.api.nvim_buf_get_lines(bufnr, context_start, context_end + 1, false)

	-- Format lines with line numbers and markers
	local lines = {}
	for i, line in ipairs(buf_lines) do
		local line_num = context_start + i
		table.insert(lines, {
			number = line_num,
			content = line,
		})
	end

	log.debug(string.format("Generated context lines: %d", #lines))
	return lines
end

return M
