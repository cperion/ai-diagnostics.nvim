return {
	"cperion/ai-diagnostics.nvim",
	lazy = true,
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("ai-diagnostics").setup({
			log = {
				enabled = true,
				level = vim.log.levels.WARN, -- Set to DEBUG to see all logs while debugging
			},
			severity = vim.diagnostic.severity.ERROR,
		})

		-- Add keymaps
		vim.keymap.set("n", "<leader>ad", function()
			require("ai-diagnostics").toggle_window("right")
		end, { desc = "Toggle AI Diagnostics window" })
	end,
}
