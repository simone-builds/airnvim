-- CSV
--------------------------------------------------
-- Column view for csv/tsv, on as soon as one opens; nothing loads
-- before that. :CsvViewToggle shows the raw text.

local FILETYPES = { "csv", "tsv" }

return {
	{
		"csvview.nvim",

		enabled = true,
		auto_enable = false,
		lazy = true,

		ft = FILETYPES,
		cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle", "CsvViewInfo" },

		after = function(plugin)
			local csvview = require("csvview")
			csvview.setup(plugin.opts)

			local function enable(buf)
				if not csvview.is_enabled(buf) then
					csvview.enable(buf)
				end
			end

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("csvview_auto", { clear = true }),
				pattern = FILETYPES,
				callback = function(args)
					enable(args.buf)
				end,
			})

			-- The FileType event that loaded the plugin has already
			-- gone by: catch the buffers it was fired for
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(buf) and vim.tbl_contains(FILETYPES, vim.bo[buf].filetype) then
					enable(buf)
				end
			end
		end,
		opts = {
			view = {
				display_mode = "border",
			},
			-- Buffer-local, and only while the view is on --
			keymaps = {
				textobject_field_inner = { "if", mode = { "o", "x" } },
				textobject_field_outer = { "af", mode = { "o", "x" } },
				jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
				jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
				jump_next_row = { "<Enter>", mode = { "n", "v" } },
				jump_prev_row = { "<S-Enter>", mode = { "n", "v" } },
			},
		},
	},
}
