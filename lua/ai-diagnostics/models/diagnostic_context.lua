local Result = require("ai-diagnostics.utils").Result

---@class DiagnosticContext
---@field lines table[] Array of context lines with number and content
---@field start_line number Starting line number (0-based)
---@field end_line number Ending line number (0-based)
local DiagnosticContext = {}
DiagnosticContext.__index = DiagnosticContext

---Create a new DiagnosticContext instance
---@param lines table[] Array of line data
---@param start_line number Starting line (0-based)
---@param end_line number Ending line (0-based)
---@return DiagnosticContext
function DiagnosticContext:new(lines, start_line, end_line)
    return setmetatable({
        lines = lines,
        start_line = start_line,
        end_line = end_line
    }, self)
end

---Create context from buffer
---@param bufnr number Buffer number
---@param diag_start number Diagnostic start line (0-based)
---@param diag_end number Diagnostic end line (0-based)
---@param before_lines number Lines before to include
---@param after_lines number Lines after to include
---@return Result Result<DiagnosticContext>
function DiagnosticContext:from_buffer(bufnr, diag_start, diag_end, before_lines, after_lines)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return Result:err("Invalid buffer")
    end
    
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local context_start = math.max(0, diag_start - before_lines)
    local context_end = math.min(line_count - 1, diag_end + after_lines)
    
    local ok, buf_lines = pcall(vim.api.nvim_buf_get_lines, bufnr, context_start, context_end + 1, false)
    if not ok then
        return Result:err("Failed to get buffer lines")
    end
    
    local lines = {}
    for i, content in ipairs(buf_lines) do
        table.insert(lines, {
            number = context_start + i - 1,  -- 0-based
            content = content,
            is_diagnostic = (context_start + i - 1) >= diag_start and (context_start + i - 1) <= diag_end
        })
    end
    
    return Result:ok(DiagnosticContext:new(lines, context_start, context_end))
end

---Get formatted lines for display
---@param show_line_numbers boolean Whether to include line numbers
---@return string[] Formatted lines
function DiagnosticContext:format_lines(show_line_numbers)
    local formatted = {}
    for _, line in ipairs(self.lines) do
        local content = line.content
        if show_line_numbers then
            -- Convert to 1-based for display
            content = string.format("%4d: %s", line.number + 1, content)
        end
        table.insert(formatted, content)
    end
    return formatted
end

return DiagnosticContext
