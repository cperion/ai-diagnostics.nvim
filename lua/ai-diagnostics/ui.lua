local log = require("ai-diagnostics.log")
local M = {}

-- Helper function for cleanup during shutdown
local function cleanup()
    -- Safely delete our buffer if it exists
    if M.state.buf_id and vim.api.nvim_buf_is_valid(M.state.buf_id) then
        pcall(vim.api.nvim_buf_delete, M.state.buf_id, { force = true })
    end
    
    -- Clear state
    M.state = {
        win_id = nil,
        buf_id = nil,
        position = nil,
        is_open = false,
    }
end

-- Setup function to register cleanup autocmd
function M.setup()
    -- Create augroup for cleanup
    local augroup = vim.api.nvim_create_augroup('AIDiagnosticsCleanup', { clear = true })
    
    -- Register VimLeavePre autocmd
    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = augroup,
        callback = cleanup,
        desc = 'Cleanup AI Diagnostics buffers and windows'
    })
end

-- Helper function to defer and safely execute a function
local function defer_fn(fn)
	vim.schedule(function()
		pcall(fn)
	end)
end

-- Buffer name for the diagnostics window
local BUFFER_NAME = "AI-Diagnostics"

-- Store window state
M.state = {
	win_id = nil,
	buf_id = nil,  -- Add buffer tracking
	position = nil,
	is_open = false,
}

-- Helper function to check if buffer is in use
local function is_buffer_in_use(bufnr)
	-- Check if buffer is loaded in any window
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == bufnr then
			return true
		end
	end
	return false
end

-- Helper function to safely delete buffer
local function safely_delete_buffer(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	-- Only attempt to delete if buffer is not in use
	if not is_buffer_in_use(bufnr) then
		pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
	end
end

-- Store window state
M.state = {
	win_id = nil,
	position = nil, -- Remembers last position used
	is_open = false,
}

---Create or get the diagnostics buffer
---@return number Buffer number
local function create_or_get_buffer()
    -- First check if we have a valid buffer in state
    if M.state.buf_id and vim.api.nvim_buf_is_valid(M.state.buf_id) then
        log.debug("Reusing existing buffer: " .. M.state.buf_id)
        return M.state.buf_id
    end

    -- Create a new buffer
    local bufnr = vim.api.nvim_create_buf(false, true)
    log.debug("Created new buffer: " .. bufnr)

    -- Set buffer options
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "hide"  -- Changed from "wipe" to "hide"
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].modifiable = true

    -- Set buffer name
    local name = BUFFER_NAME
    pcall(vim.api.nvim_buf_set_name, bufnr, name)

    -- Store buffer ID in state
    M.state.buf_id = bufnr
    return bufnr
end

---Open diagnostics window in specified position
---@param position string|nil "bottom" or "right" (defaults to last position or "bottom")
function M.open_window(position)
    position = position or M.state.position or "bottom"

    if position ~= "bottom" and position ~= "right" then
        vim.notify("Invalid position. Use 'bottom' or 'right'", vim.log.levels.ERROR)
        return
    end

    -- Close existing window if it's in a different position
    if M.state.is_open and M.state.position ~= position then
        M.close_window()
    end

    -- Get or create buffer
    local bufnr = create_or_get_buffer()
    log.debug("Using buffer " .. bufnr .. " for window")

    -- Create split window if not already open
    if not M.state.is_open then
        if position == "bottom" then
            vim.cmd('botright new')
        else
            vim.cmd('vertical botright new')
        end

        -- Get the newly created window ID
        local win_id = vim.api.nvim_get_current_win()
        M.state.win_id = win_id

        -- Set buffer for the window
        vim.api.nvim_win_set_buf(win_id, bufnr)

        -- Set window options
        vim.wo[win_id].number = false
        vim.wo[win_id].relativenumber = false
        vim.wo[win_id].wrap = false
        vim.wo[win_id].winfixwidth = true
        vim.wo[win_id].winfixheight = true

        -- Set window size
        if position == "bottom" then
            vim.api.nvim_win_set_height(win_id, 10)
        else
            vim.api.nvim_win_set_width(win_id, math.floor(vim.o.columns * 0.3))
        end
    end

    -- Update state
    M.state.is_open = true
    M.state.position = position
end

---Close the diagnostics window if it exists
function M.close_window()
    if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
        -- Close window but keep buffer
        vim.api.nvim_win_close(M.state.win_id, true)
    end

    -- Reset window state but keep buffer_id
    M.state.win_id = nil
    M.state.is_open = false
end

---Toggle the diagnostics window
---@param position string|nil "bottom" or "right" (defaults to last used position or "bottom")
function M.toggle_window(position)
	if M.state.is_open then
		M.close_window()
	else
		M.open_window(position or M.state.position)
	end
end

---Check if diagnostics window is currently open
---@return boolean
function M.is_open()
	return not not (M.state.is_open and M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id))
end

---Update the content of the diagnostics buffer
---@param content string The formatted diagnostic content to display
function M.update_content(content)
	if type(content) ~= "string" then
		log.error("Content must be a string, got: " .. type(content))
		return
	end

	defer_fn(function()
		-- Get or create buffer
		local bufnr = create_or_get_buffer()

		-- Ensure buffer exists and is valid
		if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
			log.error("Invalid buffer")
			return
		end

		-- Check if buffer is in use
		if is_buffer_in_use(bufnr) and bufnr ~= vim.api.nvim_win_get_buf(M.state.win_id) then
			log.debug("Buffer in use by another window")
			return
		end

		-- Make buffer modifiable
		pcall(vim.api.nvim_buf_set_option, bufnr, "modifiable", true)

		-- Clear existing content
		pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, {})

		-- Split content into lines and update buffer
		local lines = vim.split(content, "\n", { plain = true })
		if #lines > 0 then
			pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, lines)
		else
			-- If no content, show a message
			pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, { "No diagnostics found" })
		end

		-- Make buffer non-modifiable again
		pcall(vim.api.nvim_buf_set_option, bufnr, "modifiable", false)

		-- Ensure window exists and shows the buffer
		if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
			-- Defer the buffer switch to avoid race conditions
			defer_fn(function()
				if vim.api.nvim_win_is_valid(M.state.win_id) then
					pcall(vim.api.nvim_win_set_buf, M.state.win_id, bufnr)
				end
			end)
		end
	end)
end

return M
