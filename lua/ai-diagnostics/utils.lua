local M = {}

---Sanitize filename by removing potentially problematic characters
---@param filename string The filename to sanitize
---@return string Sanitized filename
function M.sanitize_filename(filename)
	return filename:gsub("[\n\r]", "")
end

---Convert diagnostic severity to string
---@param severity number Diagnostic severity level (1-4)
---@return string Severity name
function M.severity_to_string(severity)
	local severities = {
		[1] = "Error",
		[2] = "Warning",
		[3] = "Info",
		[4] = "Hint",
	}
	return severities[severity] or "Unknown"
end

---Safely truncate string with ellipsis
---@param str string String to truncate
---@param max_length number|nil Maximum length (defaults to config)
---@return string Truncated string
function M.truncate_string(str, max_length)
	local config = require("ai-diagnostics").config
	max_length = max_length or config.max_line_length

	if #str <= max_length then
		return str
	end
	return str:sub(1, max_length - 3) .. "..."
end

return M
