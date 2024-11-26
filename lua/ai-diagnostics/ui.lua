local log = require("ai-diagnostics.log")
local M = {}

-- Buffer name for the diagnostics window
local BUFFER_NAME = "AI-Diagnostics"

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
    position = nil,  -- Remembers last position used
    is_open = false
}

---Create or get the diagnostics buffer
---@return number Buffer number
local function create_or_get_buffer()
    -- First try to find existing buffer
    local existing_bufnr
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and 
           vim.api.nvim_buf_get_name(buf):match(BUFFER_NAME .. "$") then
            existing_bufnr = buf
            break
        end
    end
    
    -- If found and valid, return it
    if existing_bufnr and vim.api.nvim_buf_is_valid(existing_bufnr) then
        return existing_bufnr
    end
    
    -- Create new buffer with deferred naming
    local bufnr = vim.api.nvim_create_buf(false, true)
    
    -- Set buffer options first
    vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    
    -- Defer buffer naming using vim.schedule
    vim.schedule(function()
        local ok, err = pcall(vim.api.nvim_buf_set_name, bufnr, BUFFER_NAME)
        if not ok then
            -- If naming fails, try with numbered suffix
            local i = 1
            while not ok and i < 100 do -- Add safety limit
                ok, err = pcall(vim.api.nvim_buf_set_name, bufnr, BUFFER_NAME .. i)
                i = i + 1
            end
        end
    end)
    
    return bufnr
end

---Open diagnostics window in specified position
---@param position string|nil "bottom" or "right" (defaults to "bottom")
function M.open_window(position)
    position = position or 'bottom'
    
    if position ~= 'bottom' and position ~= 'right' then
        vim.notify("Invalid position. Use 'bottom' or 'right'", vim.log.levels.ERROR)
        return
    end
    
    -- Close existing window properly
    M.close_window()
    
    -- Create buffer first
    local bufnr = create_or_get_buffer()
    
    -- Defer window creation slightly to ensure buffer is ready
    vim.schedule(function()
        -- Create split
        local cmd = position == 'bottom' and 'botright split' or 'botright vsplit'
        vim.cmd(cmd)
        
        -- Store window state
        M.state.win_id = vim.api.nvim_get_current_win()
        M.state.is_open = true
        M.state.position = position
        
        -- Set window options
        if vim.api.nvim_win_is_valid(M.state.win_id) then
            pcall(vim.api.nvim_win_set_buf, M.state.win_id, bufnr)
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
    end)
end

---Close the diagnostics window if it exists
function M.close_window()
    if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
        local bufnr = vim.api.nvim_win_get_buf(M.state.win_id)
        
        -- Close window first
        pcall(vim.api.nvim_win_close, M.state.win_id, true)
        
        -- Schedule buffer deletion to avoid "in use" errors
        vim.schedule(function()
            safely_delete_buffer(bufnr)
        end)
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

    -- Get or create buffer
    local bufnr = create_or_get_buffer()
    
    -- Ensure buffer exists
    if not vim.api.nvim_buf_is_valid(bufnr) then
        log.error("Invalid buffer")
        return
    end
    
    -- Make buffer modifiable
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    
    -- Clear existing content
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    
    -- Split content into lines and update buffer
    local lines = vim.split(content, "\n", { plain = true })
    if #lines > 0 then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    else
        -- If no content, show a message
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {"No diagnostics found"})
    end
    
    -- Make buffer non-modifiable again
    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
    
    -- Ensure window exists and shows the buffer
    if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
        vim.api.nvim_win_set_buf(M.state.win_id, bufnr)
    end
end

return M
