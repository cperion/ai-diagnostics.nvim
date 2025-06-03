---@class WindowService
---@field buf_id number|nil Buffer ID
---@field win_id number|nil Window ID
---@field position string|nil Current position (right/bottom)
local WindowService = {}
WindowService.__index = WindowService

---Create a new WindowService instance
---@return WindowService
function WindowService:new()
    local instance = setmetatable({
        buf_id = nil,
        win_id = nil,
        position = nil,
    }, self)
    
    -- Setup cleanup on exit
    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            instance:cleanup()
        end,
    })
    
    return instance
end

---Ensure buffer exists
---@return number Buffer ID
function WindowService:ensure_buffer()
    -- If we have a valid buffer, return it
    if self.buf_id and vim.api.nvim_buf_is_valid(self.buf_id) then
        return self.buf_id
    end

    -- Create new buffer with proper options
    local buf = vim.api.nvim_create_buf(false, true)

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

    -- Store buffer ID
    self.buf_id = buf
    return buf
end

---Check if window is open
---@return boolean
function WindowService:is_open()
    return self.win_id ~= nil and vim.api.nvim_win_is_valid(self.win_id)
end

---Open window
---@param position string|nil "bottom" or "right" (defaults to "right")
function WindowService:open(position)
    position = position or self.position or "right"

    -- Ensure we have our persistent buffer
    local bufnr = self:ensure_buffer()

    -- If window exists and is valid, just focus it
    if self.win_id and vim.api.nvim_win_is_valid(self.win_id) then
        if self.position == position then
            vim.api.nvim_set_current_win(self.win_id)
            return
        else
            -- Close existing window if position changed
            self:close()
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

    -- Store the new window id
    self.win_id = vim.api.nvim_get_current_win()
    self.position = position

    -- Set the buffer in the window
    vim.api.nvim_win_set_buf(self.win_id, bufnr)

    -- Set window options
    local win_opts = {
        number = false,
        relativenumber = false,
        wrap = false,
        winfixwidth = true,
        winfixheight = true,
    }

    for opt, val in pairs(win_opts) do
        vim.api.nvim_win_set_option(self.win_id, opt, val)
    end
end

---Close window
function WindowService:close()
    if self.win_id and vim.api.nvim_win_is_valid(self.win_id) then
        -- Store current window
        local current_win = vim.api.nvim_get_current_win()

        -- Close the window but keep the buffer
        vim.api.nvim_win_close(self.win_id, true)

        -- Return to previous window if it's still valid
        if current_win ~= self.win_id and vim.api.nvim_win_is_valid(current_win) then
            vim.api.nvim_set_current_win(current_win)
        end

        -- Clear window ID but keep buffer ID
        self.win_id = nil
    end
end

---Toggle window
---@param position string|nil "bottom" or "right"
function WindowService:toggle(position)
    if self:is_open() then
        self:close()
    else
        self:open(position)
    end
end

---Update buffer content
---@param content string Content to display
function WindowService:update_content(content)
    local bufnr = self:ensure_buffer()

    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    local lines = vim.split(content or "No diagnostics", "\n", { plain = true })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

    -- If window is open, make sure it shows the buffer
    if self:is_open() then
        vim.api.nvim_win_set_buf(self.win_id, bufnr)
    end
end

---Cleanup resources
function WindowService:cleanup()
    if self.buf_id and vim.api.nvim_buf_is_valid(self.buf_id) then
        vim.api.nvim_buf_delete(self.buf_id, { force = true })
    end
end

return WindowService
