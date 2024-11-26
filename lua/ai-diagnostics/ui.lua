local log = require("ai-diagnostics.log")
local M = {}

-- Single state object
M.state = {
    buf_id = nil,    -- Will be set once and reused
    win_id = nil,    -- Current window ID, nil when closed
    position = nil   -- Current position
}

-- Create the persistent buffer only once
local function ensure_buffer()
    -- If we have a valid buffer and reuse is enabled, return it
    if M.state.buf_id and vim.api.nvim_buf_is_valid(M.state.buf_id) then
        log.debug("Returning existing valid buffer: " .. M.state.buf_id)
        return M.state.buf_id
    end

    -- Create new buffer with proper options
    local buf = vim.api.nvim_create_buf(false, true)
    log.debug("Created new buffer: " .. buf)
    
    -- Set buffer options
    local options = {
        buftype = 'nofile',
        bufhidden = require("ai-diagnostics").config.bufhidden or 'hide',
        swapfile = false,
        buflisted = false,
        modifiable = true,
        filetype = 'ai-diagnostics'
    }
    
    for opt, val in pairs(options) do
        vim.api.nvim_buf_set_option(buf, opt, val)
    end

    -- Update state
    M.state.buf_id = buf
    log.debug("Buffer created and state updated. buf_id=" .. buf)
    
    return buf
end

function M.setup()
    -- Setup cleanup on exit
    vim.api.nvim_create_autocmd('VimLeavePre', {
        callback = function()
            if M.state.buf_id and vim.api.nvim_buf_is_valid(M.state.buf_id) then
                vim.api.nvim_buf_delete(M.state.buf_id, { force = true })
            end
        end,
    })

    -- Add buffer cleanup on window close
    vim.api.nvim_create_autocmd('WinClosed', {
        callback = function(args)
            local win_id = tonumber(args.match)
            if win_id == M.state.win_id then
                M.state.win_id = nil
            end
        end,
    })
end

function M.is_open()
    return M.state.win_id ~= nil and vim.api.nvim_win_is_valid(M.state.win_id)
end

function M.open_window(position)
    position = position or M.state.position or "right"
    
    -- Ensure we have our buffer
    local bufnr = ensure_buffer()
    
    -- If window exists but position changed, close it
    if M.is_open() and M.state.position ~= position then
        vim.api.nvim_win_close(M.state.win_id, true)
        M.state.win_id = nil
    end

    -- Create window if needed
    if not M.is_open() then
        local cmd = position == "bottom" and "botright new" or "vertical botright new"
        vim.cmd(cmd)
        
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, bufnr)
        
        -- Set window options
        vim.wo[win].number = false
        vim.wo[win].relativenumber = false
        vim.wo[win].wrap = false
        vim.wo[win].winfixwidth = true
        vim.wo[win].winfixheight = true

        -- Set size
        if position == "bottom" then
            vim.api.nvim_win_set_height(win, 10)
        else
            vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * 0.3))
        end

        M.state.win_id = win
        M.state.position = position
    end
end

function M.close_window()
    if M.is_open() then
        local win_id = M.state.win_id
        log.debug("Closing window - Initial state: is_open=" .. tostring(M.is_open()) .. ", win_id=" .. tostring(win_id) .. ", buf_id=" .. tostring(M.state.buf_id))
        
        -- Close the window
        vim.api.nvim_win_close(win_id, true)
        
        -- Reset state
        M.state.win_id = nil
        
        log.debug("Window closed - Final state: is_open=" .. tostring(M.is_open()) .. ", win_id=" .. tostring(M.state.win_id) .. ", buf_id=" .. tostring(M.state.buf_id) .. ", old_win_id=" .. tostring(win_id))
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
    
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    local lines = vim.split(content or "No diagnostics", "\n", { plain = true })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

return M
