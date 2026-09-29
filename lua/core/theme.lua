-- THEME
--------------------------------------------------
-- Feeds the palette to base16-nvim, applies the handful of
-- groups worth naming ourselves, then strips backgrounds so
-- the terminal shows through.
--
-- The palette itself is read in lua/core/palette.lua.

local palette = require("core.palette")

local M = {}

-- "light" or "dark" while a reader theme (lua/core/reader.lua)
-- is on, nil otherwise. The desktop palette waits until it
-- is turned off.
M.reader = nil

-- TRANSPARENCY
--------------------------------------------------

vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
	pattern = "*",
	desc = "Force transparent background for UI elements",
	callback = function()
		-- Runs under a reader theme too: its page is the
		-- terminal's background, set by OSC 11 in reader.lua

		-- Drop the background only, keep fg and styles
		local function set_transparent(group)
			---@type any
			local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
			if not hl or vim.tbl_isempty(hl) then
				return
			end
			hl.bg = nil
			hl.ctermbg = nil
			hl.force = true
			vim.api.nvim_set_hl(0, group, hl)
		end

		-- Core, UI and plugin groups
		local groups = {
			"Normal",
			"NormalNC",
			"StatusLine",
			"StatusLineNC",
			"EndOfBuffer",
			"CmpItemAbbr",
			"CmpItemAbbrDeprecated",
			"CmpItemAbbrMatch",
			"CmpDocumentation",
			"CmpDocumentationBorder",
			"NormalFloat",
			"FloatBorder",
			"Pmenu",
			"PmenuBorder",
			"TelescopeNormal",
			"FidgetNormal",
			"FidgetBorder",
			"WhichKey",
			"WhichKeyFloat",
			"WhichKeyGroup",
			"LazyNormal",
			"MasonNormal",
			"DiagnosticVirtualTextError",
			"DiagnosticVirtualTextWarn",
			"DiagnosticVirtualTextInfo",
			"DiagnosticVirtualTextHint",
			"TreesitterContext",
			"TreesitterContextLineNumber",
			"SignColumn",
			"ColorColumn",
			"CursorLineSign",
			"FoldColumn",
			-- Diff* groups stay out: clearing them here would
			-- leave diffs with no colour at all
			--"DiffAdd", "DiffChange", "DiffDelete", "DiffText",
		}

		-- Generate every gitsigns group combination
		local git_prefixes = { "GitSigns", "GitSignsStaged" }
		local git_actions = { "Add", "Change", "Delete", "Untracked", "Changedelete", "Topdelete" }
		local git_suffixes = { "", "Nr", "Ln", "Cul" }

		for _, prefix in ipairs(git_prefixes) do
			for _, action in ipairs(git_actions) do
				for _, suffix in ipairs(git_suffixes) do
					table.insert(groups, prefix .. action .. suffix)
				end
			end
		end

		for _, group in ipairs(groups) do
			set_transparent(group)
		end

		-- Links between groups
		local links = {
			LazyButtonActive = "Visual",
			LazyH1 = "Title",
			LazySpecial = "Constant",
			PmenuSel = "Visual",
			TelescopeSelection = "Visual",
		}

		for from, to in pairs(links) do
			vim.api.nvim_set_hl(0, from, { link = to })
		end

		-- Telescope: clear the background only, not the text
		local telescope_groups = {
			"TelescopeBorder",
			"TelescopeResultsBorder",
			"TelescopeResultsTitle",
			"TelescopePromptBorder",
			"TelescopePromptTitle",
			"TelescopePreviewBorder",
			"TelescopePreviewTitle",
			"TelescopePromptNormal",
			"TelescopePreviewNormal",
			"TelescopeResultsNormal",
			"TelescopePromptPrefix",
		}

		for _, group in ipairs(telescope_groups) do
			vim.api.nvim_set_hl(0, group, { bg = nil, ctermbg = nil })
		end
	end,
})

-- HIGHLIGHTS
--------------------------------------------------

-- --- Editor and syntax ---
-- base16-nvim covers the bulk; these are the groups the old
-- generated file used to set by hand, now derived from the
-- palette instead of being hardcoded hex.
local function syntax(p)
	local hl = vim.api.nvim_set_hl

	hl(0, "Visual", { bg = p.sel, fg = p.fg, bold = true })
	hl(0, "LineNr", { fg = p.muted })
	hl(0, "CursorLineNr", { fg = p.accent, bold = true })

	hl(0, "Statement", { fg = p.third, bold = true })
	hl(0, "Keyword", { link = "Statement" })
	hl(0, "Repeat", { link = "Statement" })
	hl(0, "Conditional", { link = "Statement" })

	hl(0, "Function", { fg = p.accent, bold = true })
	hl(0, "Macro", { fg = p.accent, italic = true })
	hl(0, "@function.macro", { link = "Macro" })

	hl(0, "Type", { fg = p.cyan, bold = true, italic = true })
	hl(0, "Structure", { link = "Type" })

	hl(0, "String", { fg = p.green, italic = true })

	hl(0, "Operator", { fg = p.fg_dim })
	hl(0, "Delimiter", { fg = p.fg_dim })
	hl(0, "@punctuation.bracket", { link = "Delimiter" })
	hl(0, "@punctuation.delimiter", { link = "Delimiter" })

	hl(0, "Comment", { fg = p.muted, italic = true })
end

-- --- Markdown ---
-- Two named groups carry the whole markdown look, so the
-- specs in lua/plugins/markdown.lua never mention a colour:
--
--   MdHeading headings, icon and text alike: the loudest
--             colour of the theme, in bold
--   MdAccent  bullets, numbered markers and checkboxes: the
--             same colour without the weight, so a list of
--             items does not read as a wall of headings
--   MdSoft    bold and italic: halfway between the accent and
--             the body text, so emphasis reads as emphasis
--             without competing with the headings
--   MdHighlight `==text==`: body text on a light accent wash,
--             the one background in markdown. It used to take
--             the inline code colour, and the two looked alike.
--
-- Code keeps no background of its own, inline or fenced: the
-- editor is transparent, and a panel behind a snippet fights
-- with whatever the terminal shows through. Only the text is
-- coloured, by treesitter.
function M.markdown(p)
	local hl = vim.api.nvim_set_hl

	hl(0, "MdHeading", { fg = p.accent, bold = true })
	hl(0, "MdAccent", { fg = p.accent })
	hl(0, "MdSoft", { fg = p.accent_mid })
	hl(0, "MdHighlight", { fg = p.fg, bg = p.mark })

	-- Rule under headings 1-3, drawn by the terminal's underline
	-- in the heading colour: solid, long dashes, short dots.
	-- Styles and colour need a terminfo declaring Smulx and
	-- Setulc (module.nix switches WezTerm to its own); without
	-- one, nvim falls back to a plain underline in the text
	-- colour. Levels 4-6 get none.
	hl(0, "MdHeadingRule1", { underline = true, sp = p.accent })
	hl(0, "MdHeadingRule2", { underdashed = true, sp = p.accent })
	hl(0, "MdHeadingRule3", { underdotted = true, sp = p.accent })
	hl(0, "MdHeadingNoRule", {})

	-- Heading text. render-markdown links its own RenderMarkdownHn
	-- to these, so pointing them here colours icon and text alike.
	for level = 1, 6 do
		hl(0, ("@markup.heading.%d.markdown"):format(level), { link = "MdHeading" })
	end

	-- Raw list markers, visible wherever anti-conceal is on
	hl(0, "@markup.list.markdown", { link = "MdAccent" })

	-- Emphasis keeps its attribute and takes the soft colour
	hl(0, "@markup.strong.markdown_inline", { fg = p.accent_mid, bold = true })
	hl(0, "@markup.italic.markdown_inline", { fg = p.accent_mid, italic = true })

	-- `bg = "NONE"` rather than an empty table: these two link
	-- to ColorColumn by default, and a link would drag its
	-- background back in on the next colorscheme pass
	hl(0, "RenderMarkdownCode", { bg = "NONE" })
	hl(0, "RenderMarkdownCodeInline", { bg = "NONE", fg = p.code })

	-- Both halves of inline code, or it changes colour as the
	-- cursor moves: render-markdown draws the extmark above,
	-- but anti-conceal drops it on the cursor line and the
	-- text falls back to the treesitter capture below.
	hl(0, "@markup.raw.markdown_inline", { fg = p.code })
end

-- --- Statusline ---
-- A lualine theme built from the palette, every section
-- transparent.
--
-- lualine's own `auto` theme reads the colorscheme at the
-- moment it is built, and lualine loads before the palette is
-- applied, so it was picking up the stock Neovim greys: the
-- bar never matched the desktop and never would have.
--
-- Only a, b and c are listed because lualine mirrors them --
-- z reuses a, y reuses b, x reuses c -- so six sections come
-- out of three definitions.
function M.lualine()
	local p = M.colors or palette.load()
	local function section(mode)
		return {
			a = { fg = mode, bg = "NONE", gui = "bold" },
			b = { fg = p.fg_dim, bg = "NONE" },
			c = { fg = p.muted, bg = "NONE" },
		}
	end
	return {
		normal = section(p.accent),
		insert = section(p.green),
		visual = section(p.third),
		replace = section(p.red),
		command = section(p.yellow),
		inactive = section(p.muted),
	}
end

-- Apply the palette from scratch.
function M.apply()
	local p = palette.load()
	M.colors = p

	local ok, base16 = pcall(require, "base16-colorscheme")
	if ok then
		base16.setup(palette.base16(p))
	end

	-- Run the transparency pass before the overrides below,
	-- so nothing it clears can undo them
	vim.cmd("doautocmd ColorScheme")

	syntax(p)
	M.markdown(p)
end

-- FOLLOWING THE DESKTOP
--------------------------------------------------
-- matugen replaces the file rather than editing it in place,
-- so the inode the watcher holds dies with the first change:
-- it has to be restarted after every event or the palette
-- only ever updates once.

local watcher

local function watch()
	local uv = vim.uv or vim.loop
	local path = palette.file()
	if vim.fn.filereadable(path) ~= 1 then
		return
	end
	if watcher then
		pcall(function()
			watcher:stop()
		end)
	end
	watcher = uv.new_fs_event()
	watcher:start(
		path,
		{},
		vim.schedule_wrap(function()
			-- A reader theme stays put: the new palette is read
			-- when it is turned off
			if not M.reader then
				M.apply()
			end
			watch()
		end)
	)
end

M.apply()
watch()

return M
