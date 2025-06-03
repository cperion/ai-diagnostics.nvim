---@mod ai-diagnostics.migrate Migration helper for AI Diagnostics
local M = {}

---Check for breaking changes in user config/code
---@return table[] List of issues found
function M.check_breaking_changes()
    local issues = {}
    
    -- Check if user is calling removed functions
    local init = require("ai-diagnostics")
    if init.close_window then
        table.insert(issues, {
            type = "removed_function",
            message = "init.close_window() has been removed. Use close_diagnostics_window() instead."
        })
    end
    
    -- Check for deprecated config options
    if init.config.min_diagnostic_severity then
        table.insert(issues, {
            type = "deprecated_config",
            message = "min_diagnostic_severity is deprecated. Use 'severity' instead."
        })
    end
    
    return issues
end

---Migrate old config to new format
---@param old_config table Old configuration
---@return table New configuration
function M.migrate_config(old_config)
    local new_config = vim.tbl_deep_extend("force", {}, old_config)
    
    -- Migrate min_diagnostic_severity to severity
    if new_config.min_diagnostic_severity then
        new_config.severity = new_config.min_diagnostic_severity
        new_config.min_diagnostic_severity = nil
    end
    
    -- Ensure log config has proper structure
    if new_config.log and type(new_config.log) == "boolean" then
        new_config.log = {
            enabled = new_config.log,
            level = "INFO"
        }
    end
    
    return new_config
end

---Display migration report
function M.show_report()
    local issues = M.check_breaking_changes()
    
    if #issues == 0 then
        vim.notify("AI Diagnostics: No migration issues found", vim.log.levels.INFO)
        return
    end
    
    local lines = {"AI Diagnostics Migration Report", ""}
    
    for _, issue in ipairs(issues) do
        table.insert(lines, string.format("- [%s] %s", issue.type, issue.message))
    end
    
    -- Create a floating window to show the report
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    
    local width = 60
    local height = #lines
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    
    vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " Migration Report ",
        title_pos = "center",
    })
end

return M
