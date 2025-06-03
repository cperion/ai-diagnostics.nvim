local log = require("ai-diagnostics.log")
local M = {}

-- Single persistent state object at module level
local state = {
	buf_id = nil, -- Persistent buffer ID
	win_id = nil, -- Persistent window ID
	position = nil, -- Current position (right/bottom)
}

-- Create the persistent buffer only once
local function ensure_buffer()
	-- If we have a valid buffer, return it
	if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
		log.debug("Reusing existing buffer: " .. state.buf_id)
		return state.buf_id
	end

	-- Create new buffer with proper options
	local buf = vim.api.nvim_create_buf(false, true)
	log.debug("Created new persistent buffer: " .. buf)

	-- Set buffer options
	local options = {
		buftype = "nofile",
		bufhidden = "hide", -- Keep buffer alive
		swapfile = false,
		buflisted = false,
		modifiable = true,
		filetype = "ai-diagnostics",
	}

	for opt, val in pairs(options) do
		vim.api.nvim_buf_set_option(buf, opt, val)
	end

	-- Store buffer ID in persistent state
	state.buf_id = buf
	return buf
end

function M.setup()
	-- Setup cleanup on exit
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			if state.buf_id and vim.api.nvim_buf_is_valid(state.buf_id) then
				vim.api.nvim_buf_delete(state.buf_id, { force = true })
			end
		end,
	})

	-- Add 'q' mapping to close window
	vim.keymap.set("n", "q", function()
		if M.is_open() then
			M.close_window()
		end
	end)
end

function M.is_open()
	return state.win_id ~= nil and vim.api.nvim_win_is_valid(state.win_id)
end

function M.open_window(position)
	position = position or state.position or "right"

	-- Ensure we have our persistent buffer
	local bufnr = ensure_buffer()

	-- If window exists and is valid, just focus it
	if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
		if state.position == position then
			vim.api.nvim_set_current_win(state.win_id)
			return
		else
			-- Close existing window if position changed
			M.close_window()
		end
	end

	-- Save current window
	local current_win = vim.api.nvim_get_current_win()

	-- Create new split
	if position == "right" then
		vim.cmd("botright vsplit")
		-- Set width to exactly 50% of the editor width
		local width = math.floor(vim.o.columns / 2)
		vim.api.nvim_win_set_width(vim.api.nvim_get_current_win(), width)
	else
		vim.cmd("botright split")
		-- Set height to exactly 50% of the editor height
		local height = math.floor(vim.o.lines / 2)
		vim.api.nvim_win_set_height(vim.api.nvim_get_current_win(), height)
	end

	-- Store the new window id in persistent state
	state.win_id = vim.api.nvim_get_current_win()
	state.position = position

	-- Set the buffer in the window
	vim.api.nvim_win_set_buf(state.win_id, bufnr)

	-- Set window options
	local win_opts = {
		number = false,
		relativenumber = false,
		wrap = false,
		winfixwidth = true,
		winfixheight = true,
	}

	for opt, val in pairs(win_opts) do
		vim.api.nvim_win_set_option(state.win_id, opt, val)
	end
end

function M.close_window()
	if state.win_id and vim.api.nvim_win_is_valid(state.win_id) then
		-- Store current window
		local current_win = vim.api.nvim_get_current_win()

		log.debug(
			string.format(
				"Closing window - state: win_id=%s, buf_id=%s",
				tostring(state.win_id),
				tostring(state.buf_id)
			)
		)

		-- Close the window but keep the buffer
		vim.api.nvim_win_close(state.win_id, true)

		-- Return to previous window if it's still valid
		if current_win ~= state.win_id and vim.api.nvim_win_is_valid(current_win) then
			vim.api.nvim_set_current_win(current_win)
		end

		-- Clear window ID but keep buffer ID
		state.win_id = nil

		log.debug(
			string.format(
				"Window closed - final state: win_id=%s, buf_id=%s",
				tostring(state.win_id),
				tostring(state.buf_id)
			)
		)
	end
end

function M.toggle_window(position)
	if M.is_open() then
		M.close_window()
	else
		M.open_window(position)
	end
end

function M.update_content(content)
	local bufnr = ensure_buffer()

	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
	local lines = vim.split(content or "No diagnostics", "\n", { plain = true })
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

	-- If window is open, make sure it shows the buffer
	if M.is_open() then
		vim.api.nvim_win_set_buf(state.win_id, bufnr)
	end
end

return M
