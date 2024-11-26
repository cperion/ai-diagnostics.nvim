local M = {}

-- Buffer name for the diagnostics window
local BUFFER_NAME = "AI-Diagnostics"

-- Store the window ID to manage it
M.win_id = nil

-- Create or get the diagnostics buffer
local function create_or_get_buffer()
    -- Check for existing buffer
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(bufnr):match(BUFFER_NAME) then
            return bufnr
        end
    end
    
    -- Create new buffer
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, BUFFER_NAME)
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
    
    return bufnr
end

-- Open diagnostics window
function M.open_window(position)
    position = position or 'bottom' -- 'bottom' or 'right'
    
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

-- Close diagnostics window
function M.close_window()
    if M.win_id and vim.api.nvim_win_is_valid(M.win_id) then
        vim.api.nvim_win_close(M.win_id, true)
    end
    M.win_id = nil
end

-- Update diagnostics content
function M.update_content(content)
    local bufnr = create_or_get_buffer()
    
    -- Make buffer modifiable
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    
    -- Update content
    local lines = vim.split(content, "\n")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    
    -- Make buffer non-modifiable again
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

return M
