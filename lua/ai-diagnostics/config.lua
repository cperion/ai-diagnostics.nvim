local M = {}

M.default_config = {
	-- Number of context lines to show before/after diagnostic
	before_lines = 2,
	after_lines = 2,
	-- Maximum length for truncated lines
	max_line_length = 120,
	-- Minimum severity level to include (1=ERROR, 2=WARN, 3=INFO, 4=HINT)
	severity = vim.diagnostic.severity.HINT, -- Show all severities by default
	-- Enable live updates of diagnostics window
	live_updates = true,
	-- Format strings
	file_header_format = "File: %s",
	line_number_format = "%4d: %s",
	-- Sanitization options
	sanitize_filenames = true,
	-- Line number display option
	show_line_numbers = false,
	-- Logging options
	log = {
		enabled = true,
		level = "INFO",
		file = nil, -- Will default to stdpath("state")/log/ai-diagnostics.log
		max_size = 1024 * 1024, -- 1MB
	},
}

return M
