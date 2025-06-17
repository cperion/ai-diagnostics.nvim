return {
	"cperion/ai-diagnostics.nvim",
	lazy = true,
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("ai-diagnostics").setup({
			log = {
				enabled = true,
				level = "WARN", -- String values: "DEBUG", "INFO", "WARN", "ERROR"
			},
			severity = vim.diagnostic.severity.ERROR,
			-- Optional: Add other config options
			before_lines = 2,
			after_lines = 2,
			max_line_length = 120,
			show_line_numbers = false,
			live_updates = true,
		})

		-- Add keymaps
		vim.keymap.set("n", "<leader>ad", function()
			require("ai-diagnostics").toggle_diagnostics_window("right")
		end, { desc = "Toggle AI Diagnostics window" })

	end,
}
