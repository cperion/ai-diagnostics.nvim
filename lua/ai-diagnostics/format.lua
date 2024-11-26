local utils = require("ai-diagnostics.utils")
local M = {}

---Format a diagnostic with its context lines
---@param diagnostic table The diagnostic to format
---@param context table[] Array of context lines with line numbers and markers
---@return string Formatted diagnostic output
function M.format_diagnostic_with_context(diagnostic, context)
	local output = {}

	-- Add severity and message
	table.insert(output, string.format("%s: %s", utils.severity_to_string(diagnostic.severity), diagnostic.message))

	-- Format line context
	table.insert(output, "\nContext:")
	for _, line in ipairs(context) do
		local prefix = line.is_diagnostic and ">" or " "
		table.insert(output, string.format("%s %4d: %s", prefix, line.number, utils.truncate_string(line.content, 120)))
	end

	return table.concat(output, "\n")
end

return M
