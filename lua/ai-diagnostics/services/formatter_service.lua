local utils = require("ai-diagnostics.utils")

---@class FormatterService
---@field config table Configuration
local FormatterService = {}
FormatterService.__index = FormatterService

---Create a new FormatterService instance
---@param config table Configuration
---@return FormatterService
function FormatterService:new(config)
    return setmetatable({
        config = config
    }, self)
end

---Format diagnostics grouped by file
---@param file_diagnostics_map table<string, FileDiagnostics> Map of filename to FileDiagnostics
---@return string Formatted output
function FormatterService:format(file_diagnostics_map)
    local output = {}
    
    -- Sort filenames for consistent output
    local filenames = vim.tbl_keys(file_diagnostics_map)
    table.sort(filenames)
    
    for _, filename in ipairs(filenames) do
        local file_diags = file_diagnostics_map[filename]
        
        -- Add file header
        local display_filename = filename
        if self.config.sanitize_filenames then
            display_filename = utils.sanitize_filename(filename)
        end
        table.insert(output, string.format("\n" .. self.config.file_header_format, display_filename))
        
        -- Format diagnostics with merged contexts
        local formatted_lines = self:format_file_diagnostics(file_diags)
        for _, line in ipairs(formatted_lines) do
            table.insert(output, line)
        end
        
        -- Add blank line between files
        table.insert(output, "")
    end
    
    return table.concat(output, "\n")
end

---Format diagnostics for a single file
---@param file_diagnostics FileDiagnostics
---@return string[] Formatted lines
function FormatterService:format_file_diagnostics(file_diagnostics)
    local lines = {}
    local merged_blocks = self:merge_diagnostic_contexts(file_diagnostics)
    
    for _, block in ipairs(merged_blocks) do
        for _, line in ipairs(block.lines) do
            local formatted = self:format_line(line)
            table.insert(lines, formatted)
        end
        -- Add blank line between blocks
        table.insert(lines, "")
    end
    
    return lines
end

---Merge overlapping diagnostic contexts
---@param file_diagnostics FileDiagnostics
---@return table[] Array of merged context blocks
function FormatterService:merge_diagnostic_contexts(file_diagnostics)
    -- Create line map from all diagnostic contexts
    local line_map = {}
    
    for _, diagnostic in ipairs(file_diagnostics.diagnostics) do
        if diagnostic.context then
            for _, line in ipairs(diagnostic.context.lines) do
                local line_num = line.number + 1  -- Convert to 1-based
                
                if not line_map[line_num] then
                    line_map[line_num] = {
                        content = line.content,
                        diagnostics = {},
                        is_diagnostic = line.is_diagnostic
                    }
                end
                
                -- Add diagnostic to line if it's the diagnostic line
                if line.is_diagnostic then
                    table.insert(line_map[line_num].diagnostics, diagnostic)
                end
            end
        end
    end
    
    -- Convert to sorted blocks
    return self:create_continuous_blocks(line_map)
end

---Create continuous blocks from line map
---@param line_map table<number, table> Map of line numbers to line data
---@return table[] Array of continuous blocks
function FormatterService:create_continuous_blocks(line_map)
    local blocks = {}
    local line_numbers = vim.tbl_keys(line_map)
    table.sort(line_numbers)
    
    local current_block = nil
    for _, line_num in ipairs(line_numbers) do
        if not current_block or line_num > current_block.end_line + 1 then
            if current_block then
                table.insert(blocks, current_block)
            end
            current_block = {
                start_line = line_num,
                end_line = line_num,
                lines = {}
            }
        end
        
        current_block.end_line = line_num
        table.insert(current_block.lines, {
            number = line_num,
            content = line_map[line_num].content,
            diagnostics = line_map[line_num].diagnostics
        })
    end
    
    if current_block then
        table.insert(blocks, current_block)
    end
    
    return blocks
end

---Format a single line with diagnostics
---@param line table Line data with number, content, and diagnostics
---@return string Formatted line
function FormatterService:format_line(line)
    local content = utils.truncate_string(line.content, self.config.max_line_length)
    
    -- Add diagnostics if present
    if line.diagnostics and #line.diagnostics > 0 then
        local diag_messages = {}
        for _, diag in ipairs(line.diagnostics) do
            table.insert(diag_messages, diag:format_inline())
        end
        content = content .. "  " .. table.concat(diag_messages, "  ")
    end
    
    -- Add line number if configured
    if self.config.show_line_numbers then
        content = string.format("%4d: %s", line.number, content)
    end
    
    return content
end

return FormatterService
