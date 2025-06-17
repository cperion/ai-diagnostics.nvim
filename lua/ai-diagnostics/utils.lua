local M = {}

---@class Result
---@field is_ok boolean Whether the result is successful
---@field value any|nil The value if successful
---@field error string|nil The error message if failed
local Result = {}
Result.__index = Result

---Create a successful result
---@param value any The successful value
---@return Result
function Result:ok(value)
    return setmetatable({
        is_ok = true,
        value = value,
        error = nil
    }, self)
end

---Create an error result
---@param error string The error message
---@return Result
function Result:err(error)
    return setmetatable({
        is_ok = false,
        value = nil,
        error = error
    }, self)
end

---Map a function over a successful result
---@param fn function Function to apply to the value
---@return Result
function Result:map(fn)
    if self.is_ok then
        return Result:ok(fn(self.value))
    else
        return self
    end
end

---Get the value or a default
---@param default any Default value if result is error
---@return any
function Result:unwrap_or(default)
    if self.is_ok then
        return self.value
    else
        return default
    end
end

M.Result = Result

---Sanitize filename by removing potentially problematic characters
---@param filename string The filename to sanitize
---@return string Sanitized filename
function M.sanitize_filename(filename)
	return (filename:gsub("[\n\r]", ""))
end

---Safely truncate string with ellipsis
---@param str string String to truncate
---@param max_length number Maximum length
---@return string Truncated string
function M.truncate_string(str, max_length)
	if not max_length or #str <= max_length then
		return str
	end
	return str:sub(1, max_length - 3) .. "..."
end

return M
