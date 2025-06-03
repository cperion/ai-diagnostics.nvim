---@class FileDiagnostics
---@field filename string File path (relative)
---@field diagnostics Diagnostic[] Array of diagnostics for this file
local FileDiagnostics = {}
FileDiagnostics.__index = FileDiagnostics

---Create a new FileDiagnostics instance
---@param filename string File path
---@param diagnostics Diagnostic[] Array of diagnostics
---@return FileDiagnostics
function FileDiagnostics:new(filename, diagnostics)
    return setmetatable({
        filename = filename,
        diagnostics = diagnostics or {}
    }, self)
end

---Add a diagnostic to this file
---@param diagnostic Diagnostic
function FileDiagnostics:add_diagnostic(diagnostic)
    table.insert(self.diagnostics, diagnostic)
end

---Get diagnostics count
---@return number
function FileDiagnostics:count()
    return #self.diagnostics
end

---Group diagnostics by line number
---@return table<number, Diagnostic[]>
function FileDiagnostics:group_by_line()
    local groups = {}
    for _, diag in ipairs(self.diagnostics) do
        local line = diag.line
        if not groups[line] then
            groups[line] = {}
        end
        table.insert(groups[line], diag)
    end
    return groups
end

return FileDiagnostics
