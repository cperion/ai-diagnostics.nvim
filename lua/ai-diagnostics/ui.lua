local M = {}

-- Buffer name for the diagnostics window
local BUFFER_NAME = "AI-Diagnostics"

-- Store the window ID to manage it
M.win_id = nil

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
    
    -- If window exists, focus it
    if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
        vim.api.nvim_set_current_win(M.win_id)
        return
    end
    
    local bufnr = create_or_get_buffer()
    
    -- Create split
    local cmd = position == 'bottom' and 'botright split' or 'botright vsplit'
    vim.cmd(cmd)
    
    -- Store window ID
    M.win_id = vim.api.nvim_get_current_win()
    
    -- Set window options
    vim.api.nvim_win_set_buf(M.win_id, bufnr)
    vim.api.nvim_win_set_option(M.win_id, 'number', false)
    vim.api.nvim_win_set_option(M.win_id, 'relativenumber', false)
    vim.api.nvim_win_set_option(M.win_id, 'wrap', false)
    
    -- Set window height/width
    if position == 'bottom' then
        vim.api.nvim_win_set_height(M.win_id, 10)
    else
        vim.api.nvim_win_set_width(M.win_id, 80)
    end
end

---Close the diagnostics window if it exists
function M.close_window()
    if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
        vim.api.nvim_win_close(M.win_id, true)
    end
    M.win_id = nil
end

---Update the content of the diagnostics buffer
---@param content string The formatted diagnostic content to display
function M.update_content(content)
    if type(content) ~= "string" then
        vim.notify("Content must be a string", vim.log.levels.ERROR)
        return
    end

    local bufnr = create_or_get_buffer()
    
    -- Save window view
    local win_view = nil
    if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
        win_view = vim.api.nvim_win_call(M.win_id, vim.fn.winsaveview)
    end
    
    -- Make buffer modifiable
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    
    -- Update content
    local lines = vim.split(content, "\n")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    
    -- Make buffer non-modifiable again
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
    
    -- Restore window view
    if win_view and M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
        vim.api.nvim_win_call(M.win_id, function()
            vim.fn.winrestview(win_view)
        end)
    end
end

return M
