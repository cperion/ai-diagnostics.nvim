local utils = require("ai-diagnostics.utils")
local grouping = require("ai-diagnostics.grouping")
local config = require("ai-diagnostics.config")
local M = {}


---Format a diagnostic message inline
---@param diagnostic table The diagnostic to format
---@return string Formatted diagnostic message
local function format_inline_diagnostic(diagnostic)
    return string.format("[%s: %s]", 
        utils.severity_to_string(diagnostic.severity),
        diagnostic.message)
end

---Format diagnostics with merged context, grouped by file
---@param diagnostics table[] Array of diagnostics
---@param contexts table[] Array of context lines with line numbers and markers
---@param filenames string[] Array of filenames corresponding to each diagnostic
---@return string Formatted diagnostic output
---@throws "Mismatched array lengths" when input arrays have different lengths
function M.format_diagnostic_with_context(diagnostics, contexts, filenames)
    if #diagnostics == 0 then return "" end
    
    local output = {}
    local file_groups = grouping.group_by_file(diagnostics, contexts, filenames)
    
    -- Sort filenames for consistent output
    local sorted_files = vim.tbl_keys(file_groups)
    table.sort(sorted_files)
    
    for _, filename in ipairs(sorted_files) do
        local group = file_groups[filename]
        -- Add filename header
        local display_filename = filename
        if require("ai-diagnostics").config.sanitize_filenames then
            display_filename = utils.sanitize_filename(filename)
        end
        table.insert(output, string.format("\n" .. require("ai-diagnostics").config.file_header_format, display_filename))
        
        -- Format merged context for this file's diagnostics
        local merged = merge_contexts(group.diagnostics, group.contexts)
        
        for _, block in ipairs(merged) do
            table.insert(output, "")  -- Add blank line between blocks
            for _, line in ipairs(block.lines) do
                local line_content = utils.truncate_string(line.content)
                if #line.diagnostics > 0 then
                    local diag_messages = {}
                    for _, diag in ipairs(line.diagnostics) do
                        table.insert(diag_messages, format_inline_diagnostic(diag))
                    end
                    line_content = line_content .. " " .. table.concat(diag_messages, " ")
                end
                table.insert(output, string.format("%4d: %s", line.number, line_content))
            end
        end
    end
    
    return table.concat(output, "\n")
end

return M
