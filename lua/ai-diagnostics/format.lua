local utils = require("ai-diagnostics.utils")
local M = {}

---Group diagnostics and contexts by filename
---@param diagnostics table[] Array of diagnostics
---@param contexts table[] Array of context information
---@param filenames string[] Array of filenames
---@return table Grouped diagnostics by file
local function group_by_file(diagnostics, contexts, filenames)
    local file_groups = {}
    
    for i, diagnostic in ipairs(diagnostics) do
        local filename = filenames[i]
        if not file_groups[filename] then
            file_groups[filename] = {
                diagnostics = {},
                contexts = {}
            }
        end
        table.insert(file_groups[filename].diagnostics, diagnostic)
        table.insert(file_groups[filename].contexts, contexts[i])
    end
    
    return file_groups
end

---Group diagnostics by line and merge overlapping contexts
---@param diagnostics table[] Array of diagnostics
---@param contexts table[] Array of context information for each diagnostic
---@return table Merged context with diagnostic information
local function merge_contexts(diagnostics, contexts)
    -- Create a map of line numbers to their content and diagnostics
    local line_map = {}
    
    for i, context_lines in ipairs(contexts) do
        local diagnostic = diagnostics[i]
        for _, line in ipairs(context_lines) do
            if not line_map[line.number] then
                line_map[line.number] = {
                    content = line.content,
                    diagnostics = {},
                    is_context = true
                }
            end
            if line.is_diagnostic then
                table.insert(line_map[line.number].diagnostics, diagnostic)
            end
        end
    end
    
    -- Convert map to sorted array
    local merged = {}
    local line_numbers = vim.tbl_keys(line_map)
    table.sort(line_numbers)
    
    -- Group continuous lines
    local current_group = nil
    for _, lnum in ipairs(line_numbers) do
        local line = line_map[lnum]
        if not current_group or lnum > current_group.end_line + 1 then
            if current_group then
                table.insert(merged, current_group)
            end
            current_group = {
                start_line = lnum,
                end_line = lnum,
                lines = {}
            }
        end
        current_group.end_line = lnum
        table.insert(current_group.lines, {
            number = lnum,
            content = line.content,
            diagnostics = line.diagnostics
        })
    end
    if current_group then
        table.insert(merged, current_group)
    end
    
    return merged
end

---Format a diagnostic message inline
---@param diagnostic table The diagnostic to format
---@return string Formatted diagnostic message
local function format_inline_diagnostic(diagnostic)
    return string.format("[%s: %s]", 
        utils.severity_to_string(diagnostic.severity),
        diagnostic.message)
end

---Format diagnostics with merged context
---@param diagnostics table[] Array of diagnostics
---@param contexts table[] Array of context lines with line numbers and markers
---@param filenames string[] Array of filenames
---@return string Formatted diagnostic output
function M.format_diagnostic_with_context(diagnostics, contexts, filenames)
    if #diagnostics == 0 then return "" end
    
    local output = {}
    local file_groups = group_by_file(diagnostics, contexts, filenames)
    
    -- Sort filenames for consistent output
    local sorted_files = vim.tbl_keys(file_groups)
    table.sort(sorted_files)
    
    for _, filename in ipairs(sorted_files) do
        local group = file_groups[filename]
        -- Add filename header
        table.insert(output, string.format("\nFile: %s", filename))
        
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
