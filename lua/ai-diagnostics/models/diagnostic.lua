---@class Diagnostic
---@field severity number Diagnostic severity (1-4)
---@field message string Diagnostic message
---@field line number 0-based line number
---@field end_line number 0-based end line number
---@field source string|nil Diagnostic source (e.g., LSP server name)
---@field context DiagnosticContext|nil Associated context lines
local Diagnostic = {}
Diagnostic.__index = Diagnostic

---Create a new Diagnostic instance
---@param vim_diagnostic table Vim diagnostic object
---@param context DiagnosticContext|nil Optional context
---@return Diagnostic
function Diagnostic:new(vim_diagnostic, context)
    local instance = setmetatable({}, self)
    
    instance.severity = vim_diagnostic.severity or vim.diagnostic.severity.ERROR
    instance.message = vim_diagnostic.message or ""
    instance.line = vim_diagnostic.lnum or 0
    instance.end_line = vim_diagnostic.end_lnum or instance.line
    instance.source = vim_diagnostic.source
    instance.context = context
    
    return instance
end

---Get 1-based line number for display
---@return number
function Diagnostic:get_display_line()
    return self.line + 1
end

---Get 1-based end line number for display
---@return number
function Diagnostic:get_display_end_line()
    return self.end_line + 1
end

---Get severity as string
---@return string
function Diagnostic:get_severity_string()
    local severities = {
        [vim.diagnostic.severity.ERROR] = "Error",
        [vim.diagnostic.severity.WARN] = "Warning",
        [vim.diagnostic.severity.INFO] = "Info",
        [vim.diagnostic.severity.HINT] = "Hint",
    }
    return severities[self.severity] or "Unknown"
end

---Format diagnostic for inline display
---@return string
function Diagnostic:format_inline()
    local clean_message = self.message:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[\n\r]+", " ")
    return string.format("[%s: %s]", self:get_severity_string(), clean_message)
end

return Diagnostic
