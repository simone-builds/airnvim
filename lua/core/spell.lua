-- SPELL CHECKING
--------------------------------------------------
-- Off everywhere by default. `:SpellToggle` turns it on for
-- the current buffer and the current session only: nothing is
-- written to disk.
--
-- Code is excluded by the Treesitter spell captures, half from
-- neovim's own markdown queries and half from
-- queries/markdown/highlights.scm. It only works while
-- Treesitter highlighting is attached to the buffer.

local M = {}

-- Dictionaries live in spell/ and are set from Nix --
local function languages()
	local langs = nixInfo({ "it", "en" }, "settings", "spell", "languages")
	if type(langs) ~= "table" or vim.tbl_isempty(langs) then
		return "en"
	end
	return table.concat(langs, ",")
end

-- Filetypes `:SpellToggle` accepts --
local function filetypes()
	local fts = nixInfo({ "markdown" }, "settings", "spell", "filetypes")
	return type(fts) == "table" and fts or { "markdown" }
end

function M.toggle(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	if not require("core.setting").bool(true, "settings", "spell", "enable") then
		vim.notify("Spell checking is disabled in the Nix config", vim.log.levels.WARN)
		return
	end

	local ft = vim.bo[bufnr].filetype
	if not vim.tbl_contains(filetypes(), ft) then
		vim.notify(
			("Spell checking is only available for: %s"):format(table.concat(filetypes(), ", ")),
			vim.log.levels.WARN
		)
		return
	end

	local win = vim.api.nvim_get_current_win()
	local on = not vim.wo[win].spell

	vim.wo[win].spell = on
	if on then
		vim.bo[bufnr].spelllang = languages()
		-- Do not flag camelCase halves as separate words
		vim.bo[bufnr].spelloptions = "camel"
	end

	vim.notify(("Spell checking %s (%s)"):format(on and "on" or "off", languages()))
end

vim.api.nvim_create_user_command("SpellToggle", function()
	M.toggle(0)
end, { desc = "Toggle spell checking for this buffer" })

vim.keymap.set("n", "<leader>z", M.toggle, { desc = "Toggle spell checking" })

return M
