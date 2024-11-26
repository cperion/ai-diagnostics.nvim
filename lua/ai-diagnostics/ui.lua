local log = require("ai-diagnostics.log")
local M = {}

-- Buffer name for the diagnostics window
local BUFFER_NAME = "AI-Diagnostics"

-- Initialize state without depending on config
M.state = {
    win_id = nil,
    buf_id = nil,
    position = nil,
    is_open = false
}

function M.setup()
    -- Create augroup for cleanup
    local augroup = vim.api.nvim_create_augroup('AIDiagnosticsCleanup', { clear = true })
    
    -- Register VimLeavePre autocmd
    vim.api.nvim_create_autocmd('VimLeavePre', {
        group = augroup,
        callback = function()
            if M.state.buf_id and vim.api.nvim_buf_is_valid(M.state.buf_id) then
                pcall(vim.api.nvim_buf_delete, M.state.buf_id, { force = true })
            end
            M.state = {
                win_id = nil,
                buf_id = nil,
                position = nil,
                is_open = false
            }
        end,
    })

    -- Create new buffer if none exists
    local buf = vim.api.nvim_create_buf(false, true)
    
    -- Set buffer options
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf }) -- Change from 'hide' to 'wipe'
    vim.api.nvim_set_option_value('swapfile', false, { buf = buf })
    vim.api.nvim_set_option_value('buflisted', false, { buf = buf })
    vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
    vim.api.nvim_set_option_value('filetype', 'ai-diagnostics', { buf = buf }) -- Add filetype
end

-- Helper function to defer and safely execute a function
local function defer_fn(fn)
	vim.schedule(function()
		pcall(fn)
	end)
end


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
---@return number|nil Buffer number
local function create_or_get_buffer()
    log.debug("Attempting to create or get buffer")

    -- If we have a valid buffer in state, use it
    if M.state.buf_id and vim.api.nvim_buf_is_valid(M.state.buf_id) then
        log.debug(string.format("Using existing buffer from state: %s", tostring(M.state.buf_id)))
        return M.state.buf_id
    end

    -- Create new buffer
    local buf = vim.api.nvim_create_buf(false, true)
    log.debug(string.format("Created new buffer: %s", tostring(buf)))
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'buflisted', false)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'ai-diagnostics')

    -- Set buffer name
    local full_name = vim.fn.getcwd() .. '/' .. BUFFER_NAME
    vim.api.nvim_buf_set_name(buf, full_name)

    M.state.buf_id = buf
    log.debug(string.format("Buffer created and state updated. buf_id=%s", tostring(M.state.buf_id)))
    return buf
end

---Open diagnostics window in specified position
---@param position string|nil "bottom" or "right" (defaults to last position or "bottom")
function M.open_window(position)
    position = position or M.state.position or "bottom"
    
    if position ~= "bottom" and position ~= "right" then
        vim.notify("Invalid position. Use 'bottom' or 'right'", vim.log.levels.ERROR)
        return
    end

    -- Log initial state
    log.debug(string.format("Opening window - Current state: is_open=%s, position=%s, win_id=%s, buf_id=%s", 
        tostring(M.state.is_open), 
        tostring(M.state.position), 
        tostring(M.state.win_id), 
        tostring(M.state.buf_id)))

    -- Get or create buffer first
    local bufnr = create_or_get_buffer()
    log.debug(string.format("Buffer for window: %s", tostring(bufnr)))

    -- If window exists but position changed, close it
    if M.state.is_open and M.state.position ~= position then
        log.debug(string.format("Position changed from %s to %s, closing existing window", 
            tostring(M.state.position), tostring(position)))
        M.close_window()
    end

    -- Create window if needed
    if not M.state.is_open then
        local cmd = position == "bottom" and "botright new" or "vertical botright new"
        log.debug(string.format("Creating new window with command: %s", cmd))
        vim.cmd(cmd)
        
        local win_id = vim.api.nvim_get_current_win()
        M.state.win_id = win_id
        
        log.debug(string.format("Window created: %s", tostring(win_id)))
        
        -- Set window options
        vim.api.nvim_win_set_buf(win_id, bufnr)
        vim.wo[win_id].number = false
        vim.wo[win_id].relativenumber = false
        vim.wo[win_id].wrap = false
        vim.wo[win_id].winfixwidth = true
        vim.wo[win_id].winfixheight = true

        -- Set window size
        if position == "bottom" then
            vim.api.nvim_win_set_height(win_id, 10)
            log.debug("Set window height to 10")
        else
            vim.api.nvim_win_set_width(win_id, math.floor(vim.o.columns * 0.3))
            log.debug("Set window width to 30% of columns")
        end

        M.state.is_open = true
        M.state.position = position

        log.debug(string.format("Window opened - Final state: is_open=%s, position=%s, win_id=%s, buf_id=%s", 
            tostring(M.state.is_open), 
            tostring(M.state.position), 
            tostring(M.state.win_id), 
            tostring(M.state.buf_id)))
    end
end

---Close the diagnostics window if it exists
function M.close_window()
    log.debug(string.format("Closing window - Initial state: is_open=%s, win_id=%s, buf_id=%s", 
        tostring(M.state.is_open), 
        tostring(M.state.win_id), 
        tostring(M.state.buf_id)))

    -- Store buffer ID before closing
    local buf_id = M.state.buf_id

    if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
        log.debug(string.format("Closing window: %s", tostring(M.state.win_id)))
        -- Close window
        vim.api.nvim_win_close(M.state.win_id, true)
    end

    -- Clean up the buffer if it exists and is valid
    if buf_id and vim.api.nvim_buf_is_valid(buf_id) then
        log.debug(string.format("Cleaning up buffer: %s", tostring(buf_id)))
        -- Force delete the buffer
        pcall(vim.api.nvim_buf_delete, buf_id, { force = true })
    end

    -- Reset all state
    M.state = {
        win_id = nil,
        buf_id = nil,
        position = nil,
        is_open = false
    }
end

---Toggle the diagnostics window
---@param position string|nil "bottom" or "right" (defaults to last used position or "bottom")
function M.toggle_window(position)
    log.debug(string.format("Checking window open status: is_open=%s, state.is_open=%s, win_id=%s, win_valid=%s", 
        tostring(M.is_open()),
        tostring(M.state.is_open), 
        tostring(M.state.win_id),
        tostring(M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id))))

    -- If window is open, close it
    if M.is_open() then
        M.close_window()
        return
    end

    -- If we have a valid buffer but no window, clean it up first
    if M.state.buf_id and vim.api.nvim_buf_is_valid(M.state.buf_id) then
        pcall(vim.api.nvim_buf_delete, M.state.buf_id, { force = true })
        M.state.buf_id = nil
    end

    -- Determine position
    position = position or M.state.position or "bottom"
    
    -- Create new buffer
    local bufnr = create_or_get_buffer()
    
    if not bufnr then
        log.error("Failed to create or get buffer")
        return
    end

    -- Create window
    local cmd = position == "bottom" and "botright new" or "vertical botright new"
    vim.cmd(cmd)
    
    local win_id = vim.api.nvim_get_current_win()
    
    -- Set the buffer for this window
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

    -- Update state
    M.state.win_id = win_id
    M.state.buf_id = bufnr
    M.state.is_open = true
    M.state.position = position
    
    -- Ensure buffer is populated
    M.update_content(require("ai-diagnostics").get_workspace_diagnostics())
end

---Check if diagnostics window is currently open
---@return boolean
function M.is_open()
    local is_open = not not (M.state.is_open and M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id))
    log.debug(string.format("Checking window open status: is_open=%s, state.is_open=%s, win_id=%s, win_valid=%s", 
        tostring(is_open),
        tostring(M.state.is_open), 
        tostring(M.state.win_id),
        tostring(M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id))))
    return is_open
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
