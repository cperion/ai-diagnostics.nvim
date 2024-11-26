local M = {}

M.default_config = {
	-- Number of context lines to show before/after diagnostic
	before_lines = 2,
	after_lines = 2,
	-- Maximum length for truncated lines
	max_line_length = 120,
	-- Enable live updates of diagnostics window
	live_updates = true,
}

return M
