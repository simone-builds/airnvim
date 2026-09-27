-- BUILT-IN REFERENCE SHEETS
--------------------------------------------------
-- `:MdGuide` (markdown syntax) and `:NvCheat` (Neovim and
-- airnvim keys). The files live in guides/, which ships
-- with the config in the Nix store, so they are found
-- through core.paths and never through stdpath("config").

local alias = require("core.cmdalias").set

local function open(file)
	local path = vim.fs.joinpath(require("core.paths").config(), "guides", file)
	if vim.fn.filereadable(path) == 0 then
		vim.notify("Guide not found: " .. path, vim.log.levels.ERROR)
		return
	end

	-- An empty window (dashboard, fresh buffer) is reused;
	-- otherwise the sheet opens beside the current file
	local buf = vim.api.nvim_get_current_buf()
	local empty = vim.api.nvim_buf_get_name(buf) == "" or vim.bo[buf].buftype ~= ""
	vim.cmd((empty and "edit " or "vsplit ") .. vim.fn.fnameescape(path))

	-- Reference, not a draft: in the store it could not be
	-- written anyway, and outside it this is the repo copy
	vim.bo.readonly = true
	vim.bo.modifiable = false
	-- `:close` refuses the last window, so there the buffer
	-- goes instead
	vim.keymap.set("n", "q", function()
		local splits = vim.tbl_filter(function(win)
			return vim.api.nvim_win_get_config(win).relative == ""
		end, vim.api.nvim_tabpage_list_wins(0))
		vim.cmd(#splits > 1 and "close" or "bdelete")
	end, { buffer = true, desc = "Close the guide" })
end

vim.api.nvim_create_user_command("MdGuide", function()
	open("markdown-guide.md")
end, { desc = "Open the markdown syntax guide" })

vim.api.nvim_create_user_command("NvCheat", function()
	open("nvim-cheatsheet.md")
end, { desc = "Open the Neovim cheatsheet" })

alias("mdguide", "MdGuide")
alias("nvcheat", "NvCheat")
