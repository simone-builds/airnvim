-- READER THEMES
--------------------------------------------------
-- `:ReaderLight` / `:ReaderDark` put Gruvbox on, opaque, for
-- long reading sessions; `:ReaderOff` goes back to the desktop
-- palette. Global (a colorscheme is), for this session only.
--
-- The desktop palette is not touched: core/theme.lua skips
-- its transparency pass and its file watcher while a reader
-- theme is on, and rebuilds everything from scratch on the
-- way out. Markdown keeps its own look (MdHeading & co.),
-- recoloured from Gruvbox by the same rules.

local M = {}

-- 'background' before the first reader theme, restored on
-- the way out: palette.load() picks its variant from it.
local saved_background

-- Gruvbox under the palette's names, so theme.markdown() and
-- theme.lualine() take it as they take the desktop one.
-- Mirrors the plugin's own light/dark mapping.
local function colours(variant)
	local g = require("gruvbox").palette
	local dark = variant == "dark"
	return require("core.palette").derive({
		bg = dark and g.dark0 or g.light0,
		fg = dark and g.light1 or g.dark1,
		fg_dim = dark and g.light4 or g.dark4,
		muted = g.gray,
		accent = dark and g.bright_orange or g.faded_orange,
		third = dark and g.bright_purple or g.faded_purple,
		green = dark and g.bright_green or g.faded_green,
		red = dark and g.bright_red or g.faded_red,
		yellow = dark and g.bright_yellow or g.faded_yellow,
	})
end

-- Terminal colours --
-- The grid is nvim's, but the terminal's padding around it
-- and the strip under the last row are painted with the
-- terminal's own background: a cream page got a dark frame,
-- and the cursor kept the desktop colour. OSC 11 and 12 set
-- background and cursor; 111 and 112 give the terminal its
-- own back. Without a UI (headless) nothing is sent.
local function terminal(p)
	if not vim.api.nvim_ui_send then
		return
	end
	if p then
		vim.api.nvim_ui_send(("\027]11;%s\027\\\027]12;%s\027\\"):format(p.bg, p.fg))
	else
		vim.api.nvim_ui_send("\027]111\027\\\027]112\027\\")
	end
end

-- Leaving or suspending nvim must not leave the shell cream
vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, {
	desc = "Give the terminal its colours back",
	callback = function()
		if require("core.theme").reader then
			terminal(nil)
		end
	end,
})

vim.api.nvim_create_autocmd("VimResume", {
	desc = "Repaint the terminal for the reader theme",
	callback = function()
		local theme = require("core.theme")
		if theme.reader then
			terminal(theme.colors)
		end
	end,
})

-- Nvim sets 'background' from every OSC 11 reply, and the TUI
-- asks again on resume: the terminal, just given its own dark
-- colour back, answered "dark" and gruvbox reloaded dark over
-- :ReaderLight, markdown groups gone. The reader's variant is
-- put back whenever something else changes it.
vim.api.nvim_create_autocmd("OptionSet", {
	pattern = "background",
	desc = "Keep the reader theme's variant",
	callback = function()
		local theme = require("core.theme")
		if theme.reader and vim.v.option_new ~= theme.reader then
			vim.schedule(function()
				if theme.reader then
					M.on(theme.reader)
				end
			end)
		end
	end,
})

function M.on(variant)
	local theme = require("core.theme")
	require("lze").trigger_load("gruvbox.nvim")

	if not theme.reader then
		saved_background = vim.o.background
	end
	theme.reader = variant
	-- Before the ColorScheme event: lualine rebuilds from it
	theme.colors = colours(variant)

	-- base16 sets no colors_name, so gruvbox would not clear
	-- what base16 left behind: groups it does not define
	-- would keep the desktop colours
	vim.cmd("highlight clear")
	vim.g.colors_name = nil
	vim.o.background = variant
	vim.cmd.colorscheme("gruvbox")

	theme.markdown(theme.colors)
	terminal(theme.colors)
end

function M.off()
	local theme = require("core.theme")
	if not theme.reader then
		return
	end
	theme.reader = nil

	-- Clear first: base16 overwrites only its own groups, and
	-- with colors_name still "gruvbox" setting 'background'
	-- would load gruvbox again
	vim.cmd("highlight clear")
	vim.g.colors_name = nil
	vim.o.background = saved_background
	theme.apply()
	terminal(nil)
end

vim.api.nvim_create_user_command("ReaderLight", function()
	M.on("light")
end, { desc = "Gruvbox light, for reading" })

vim.api.nvim_create_user_command("ReaderDark", function()
	M.on("dark")
end, { desc = "Gruvbox dark, for reading" })

vim.api.nvim_create_user_command("ReaderOff", M.off, {
	desc = "Back to the desktop palette",
})

return M
