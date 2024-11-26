local M = {}

M.default_config = {
    -- Number of context lines to show before/after diagnostic
    before_lines = 2,
    after_lines = 2,
    -- Maximum length for truncated lines
    max_line_length = 120,
    -- Enable live updates of diagnostics window
    live_updates = true,
    -- Format strings
    file_header_format = "File: %s",
    line_number_format = "%4d: %s",
    -- Sanitization options
    sanitize_filenames = true,
    -- Logging options
    log = {
        enabled = true,
        level = "INFO",
        file = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h") .. "/logs/ai-diagnostics.log",
        max_size = 1024 * 1024, -- 1MB
    },
}

return M
