local M = {}

---Group diagnostics and contexts by filename
---@param diagnostics table[] Array of diagnostics
---@param contexts table[] Array of context lines
---@param filenames string[] Array of filenames
---@return table Grouped diagnostics by file
---@throws "Mismatched array lengths" when input arrays have different lengths
function M.group_by_file(diagnostics, contexts, filenames)
    if #diagnostics ~= #contexts or #diagnostics ~= #filenames then
        vim.notify("Mismatched array lengths in diagnostic grouping", vim.log.levels.ERROR)
        return {}
    end
    
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
---@param contexts table[] Array of context information
---@return table Merged context with diagnostic information
function M.merge_contexts(diagnostics, contexts)
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
    
    local merged = {}
    local line_numbers = vim.tbl_keys(line_map)
    table.sort(line_numbers)
    
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

return M
