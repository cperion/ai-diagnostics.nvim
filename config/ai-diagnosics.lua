return {
  "cperion/ai-diagnostics.nvim",
  config = function()
    require("ai-diagnostics").setup({
      log = {
        enabled = true,
        level = "DEBUG", -- Set to DEBUG to see all logs while debugging
        file = vim.fn.stdpath("cache") .. "/ai-diagnostics.log",
      },
    })

    -- Add keymaps
    vim.keymap.set("n", "<leader>ad", function()
      require("ai-diagnostics").toggle_diagnostics_window("right")
    end, { desc = "Toggle AI Diagnostics window" })
  end,
}
