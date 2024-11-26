local log = require("ai-diagnostics.log")
local M = {}

-- Buffer name for the diagnostics window
local BUFFER_NAME = "AI-Diagnostics"

-- Store window state
M.state = {
    win_id = nil,
    position = nil,  -- Remembers last position used
    is_open = false
}

---Create or get the diagnostics buffer
---@return number Buffer number
local function create_or_get_buffer()
    -- Check for existing buffer
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(bufnr):match(BUFFER_NAME) then
            return bufnr
        end
    end
    
    -- Create new buffer with name
    local bufnr = vim.api.nvim_create_buf(false, true)
    
    -- Try to set buffer name, ignore errors if it already exists
    pcall(vim.api.nvim_buf_set_name, bufnr, BUFFER_NAME)
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
    
    -- Add keymapping to quit window
    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'q', ':lua require("ai-diagnostics.ui").close_window()<CR>', {
        noremap = true,
        silent = true,
        nowait = true
    })
    
    return bufnr
end

---Open diagnostics window in specified position
---@param position string|nil "bottom" or "right" (defaults to "bottom")
function M.open_window(position)
    position = position or 'bottom'
    
    -- Validate position
    if position ~= 'bottom' and position ~= 'right' then
        vim.notify("Invalid position. Use 'bottom' or 'right'", vim.log.levels.ERROR)
        return
    end
    
    -- Store position preference
    M.state.position = position
    
    -- If window exists, focus it
    if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
        vim.api.nvim_set_current_win(M.state.win_id)
        return
    end
    
    local bufnr = create_or_get_buffer()
    
    -- Create split
    local cmd = position == 'bottom' and 'botright split' or 'botright vsplit'
    vim.cmd(cmd)
    
    -- Store window state
    M.state.win_id = vim.api.nvim_get_current_win()
    M.state.is_open = true
    
    -- Set window options
    vim.api.nvim_win_set_buf(M.state.win_id, bufnr)
    vim.api.nvim_win_set_option(M.state.win_id, 'number', false)
    vim.api.nvim_win_set_option(M.state.win_id, 'relativenumber', false)
    vim.api.nvim_win_set_option(M.state.win_id, 'wrap', false)
    
    -- Set window height/width
    if position == 'bottom' then
        vim.api.nvim_win_set_height(M.state.win_id, 10)
    else
        vim.api.nvim_win_set_width(M.state.win_id, 80)
    end
end

---Close the diagnostics window if it exists
function M.close_window()
    if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
        vim.api.nvim_win_close(M.state.win_id, true)
    end
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
    return M.state.is_open and M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id)
end

---Update the content of the diagnostics buffer
---@param content string The formatted diagnostic content to display
function M.update_content(content)
    if type(content) ~= "string" then
        log.error("Content must be a string, got: " .. type(content))
        return
    end

    log.debug(string.format("Updating content (length: %d)", #content))
    log.debug("Content preview: " .. string.sub(content, 1, 100))
    
    if #content == 0 then
        log.warn("Attempting to update with empty content")
    end
    
    local bufnr = create_or_get_buffer()
    log.debug(string.format("Using buffer: %d", bufnr))
    
    -- Add buffer state logging
    log.debug(string.format("Buffer modifiable before: %s", 
        vim.api.nvim_buf_get_option(bufnr, 'modifiable')))
    
    -- Make buffer modifiable
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    
    -- Update content
    local lines = vim.split(content, "\n")
    log.debug(string.format("Setting %d lines in buffer", #lines))
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    
    -- Make buffer non-modifiable again
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

return M
