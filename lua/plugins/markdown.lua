-- MARKDOWN
--------------------------------------------------
-- In-buffer rendering, inline images, browser preview and
-- clipboard images. The preview is live-preview.nvim, pure
-- lua at 4 MB: markdown-preview.nvim was dropped because it
-- pulls in about 300 MB of nodejs. The user commands for
-- both live in lua/tools/markdown.lua.
--
-- No colour is named here. `MdAccent`, `MdSoft` and the rest come from
-- lua/core/theme.lua, which derives them from the desktop
-- palette, so the buffer follows the wallpaper.

-- Level-1 headings in a buffer, stopping at two: all that
-- heading_number() needs. Counted once per buffer change, not
-- once per heading drawn. Through Treesitter, so a `#` in code
-- or a `#tag` is not a heading.
-- Only the direct children of the top-level sections are read:
-- an ATX H1 opens one, and a setext H1 (`===`) sits inside one.
-- A query over the whole tree took 66 ms on a 635 KB file, on
-- every change; this reads a few dozen nodes.
local h1_cache = {}

local function is_h1(node)
	local t = node:type()
	local mark = t == "atx_heading" and node:named_child(0)
		or t == "setext_heading" and node:named_child(node:named_child_count() - 1)
	return mark and (mark:type() == "atx_h1_marker" or mark:type() == "setext_h1_underline")
end

local function h1_count(buf)
	local tick = vim.api.nvim_buf_get_changedtick(buf)
	local hit = h1_cache[buf]
	if hit and hit.tick == tick then
		return hit.count
	end

	local count = 0
	local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
	local tree = ok and parser and parser:parse()[1]
	for section in tree and tree:root():iter_children() or function() end do
		if section:type() == "section" then
			for child in section:iter_children() do
				if is_h1(child) then
					count = count + 1
				end
			end
		end
		if count > 1 then
			break
		end
	end
	h1_cache[buf] = { tick = tick, count = count }
	return count
end

vim.api.nvim_create_autocmd("BufWipeout", {
	callback = function(args)
		h1_cache[args.buf] = nil
	end,
})

-- Heading numbers. Drawn in place of the `#` marks as 1, 1.1,
-- 1.2.1 and so on: rendered only, never written to the file,
-- since the PDF export numbers headings itself and would
-- number them twice. `sections` holds the count at each level;
-- a skipped level stays as 0 (1.0.1) on purpose, next to
-- rumdl's MD001 warning, so it gets fixed in the source rather
-- than hidden here. That includes a document with no level-1
-- heading at all: 0.1, 0.2.
-- A single level-1 heading is the document's title: it gets no
-- number, and the levels below count from it (1, 2, 2.1 rather
-- than 1.1, 1.2, 1.2.1). With two or more, level 1 is a
-- chapter and is numbered. `ctx.buf` comes from a patch to
-- render-markdown in module.nix: upstream passes no buffer.
local function heading_number(ctx)
	local sections = ctx.sections
	if ctx.buf and h1_count(ctx.buf) == 1 then
		if ctx.level == 1 then
			return ""
		end
		sections = vim.list_slice(sections, 2)
	end
	return table.concat(sections, ".") .. " "
end

-- Checkbox icons. The icon is drawn over `[ ] ` and whatever it
-- does not cover is concealed, list marker included: an empty
-- icon made `- [ ] task` render as a bare `task`. Nerd Font
-- glyphs from one family, plain Unicode without the font.
local nerd_font = require("core.setting").bool(true, "settings", "nerd_font", "enable")
local checkbox_icons = nerd_font and { unchecked = "󰄱 ", checked = "󰱒 " }
	or { unchecked = "☐ ", checked = "☑ " }

-- WezTerm image ghosts --
-- WezTerm attaches kitty images to text cells. When nvim
-- scrolls the screen, the cells move and take the image with
-- them; image.nvim then draws it again in the right place,
-- but WezTerm ignores its delete-by-id, so torn strips of the
-- old copy stay behind the text. `:mode` clears every cell,
-- which does remove them, and the images are placed again.
-- Only on a scroll or a change in line count: typing inside a
-- line moves nothing. kitty keeps images on a layer of their
-- own and needs none of this.
local function wezterm_image_redraw()
	if vim.env.TERM_PROGRAM ~= "WezTerm" then
		return
	end

	local timer = assert(vim.uv.new_timer())
	local line_count = {}

	-- Waits for the scroll to settle: a wheel spin sends a burst
	-- of events, and a full redraw between two of them is lag
	local function redraw()
		timer:stop()
		timer:start(
			120,
			0,
			vim.schedule_wrap(function()
				local images = require("image").get_images()
				if #images == 0 then
					return
				end
				vim.cmd("mode")
				for _, image in ipairs(images) do
					-- Through the backend, not `image:clear()`: that
					-- also deletes the extmark holding the blank
					-- lines under the image, and nvim, losing them,
					-- undid every scroll across the picture.
					-- Shallow keeps the data in the terminal.
					image.global_state.backend.clear(image.id, true)
					image:render()
				end
			end)
		)
	end

	local group = vim.api.nvim_create_augroup("WeztermImageRedraw", { clear = true })
	vim.api.nvim_create_autocmd("WinScrolled", { group = group, callback = redraw })
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(args)
			local count = vim.api.nvim_buf_line_count(args.buf)
			if line_count[args.buf] ~= count then
				line_count[args.buf] = count
				redraw()
			end
		end,
	})
end

-- Mouse wheel over images --
-- `scrolloff` keeps the cursor 10 lines from the edges. When a
-- wheel step drags the cursor onto an image line, whose blank
-- lines are taller than that margin allows, nvim moves the view
-- to make room: one step went backwards, another jumped 14
-- lines instead of 5. The wheel therefore scrolls with no
-- margin, and the global one comes back once it stops. Setting
-- it again does not move the view; only the next cursor motion
-- honours it. The keyboard keeps its margin throughout.
local function wheel_without_margin()
	local timer = assert(vim.uv.new_timer())
	local marginless = {}

	local function restore()
		for win in pairs(marginless) do
			if vim.api.nvim_win_is_valid(win) then
				-- -1 falls back to the global value
				vim.api.nvim_set_option_value("scrolloff", -1, { scope = "local", win = win })
			end
		end
		marginless = {}
	end

	local function map(buf)
		for _, key in ipairs({ "<ScrollWheelDown>", "<ScrollWheelUp>" }) do
			vim.keymap.set({ "n", "i", "v" }, key, function()
				-- The wheel scrolls the window under the pointer,
				-- which need not be the current one
				local win = vim.fn.getmousepos().winid
				win = win ~= 0 and win or vim.api.nvim_get_current_win()
				vim.api.nvim_set_option_value("scrolloff", 0, { scope = "local", win = win })
				marginless[win] = true
				timer:stop()
				timer:start(400, 0, vim.schedule_wrap(restore))
				return key
			end, { buffer = buf, expr = true, replace_keycodes = true, desc = "Scroll without margin" })
		end
	end

	-- The plugin loads on the first markdown buffer, so that
	-- FileType has already fired
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[buf].filetype == "markdown" then
			map(buf)
		end
	end
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("MarkdownWheel", { clear = true }),
		pattern = "markdown",
		callback = function(args)
			map(args.buf)
		end,
	})
end

-- Centred column --
-- The text stops at line_length, so on a full screen it filled
-- the left half and left the right one empty. no-neck-pain adds
-- an empty window on each side instead. The text window stays a
-- plain split: image.nvim, Oil's float and the LSP see nothing
-- new. The width adds the number and sign columns plus some
-- slack: 85 at 75 columns, what a tiled half of the screen
-- gives, so a line never wraps on screen.
local CENTRE_WIDTH = nixInfo(75, "settings", "markdown", "line_length") + 10
-- Narrowest side window worth having; the plugin opens none
-- below it and closes them when the terminal shrinks, and opens
-- them again when it grows. At 1920 px a full-screen nvim is
-- ~170 columns, sides of ~43; a tiled half is ~85, no room at
-- all. 20 needs about 125 columns before centring.
local CENTRE_MIN_SIDE = 20

-- On while every file window of the tab shows markdown. The
-- width is the plugin's business (above): "on" in a narrow
-- window just means no side windows yet. Floats (Oil,
-- telescope), help and the side windows themselves have no
-- say, so opening them or moving focus never flips the layout.
-- nil: nothing to decide.
local function centre_wanted()
	local markdown = false
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.api.nvim_win_get_config(win).relative == "" and vim.bo[buf].buftype == "" then
			if vim.bo[buf].filetype ~= "markdown" then
				return false
			end
			markdown = true
		end
	end
	return markdown or nil
end

local function centre_active()
	local state = _G.NoNeckPain and _G.NoNeckPain.state
	return state ~= nil
		and state.enabled == true
		and state.tabs ~= nil
		and state.tabs[vim.api.nvim_get_current_tabpage()] ~= nil
end

-- A vertical separator belongs to the window on its left: the
-- left side window draws the line before the text, and the text
-- window the one after it, towards the right side window. The
-- side windows blank theirs through the plugin's `wo`; a window
-- touching the right side window gets `vert: ` here, and its own
-- value back once the side windows go. Splits between two files
-- keep their line.
local function centre_separators()
	local wins = vim.tbl_filter(function(win)
		return vim.api.nvim_win_get_config(win).relative == ""
	end, vim.api.nvim_tabpage_list_wins(0))

	local sides = {}
	for _, win in ipairs(wins) do
		if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "no-neck-pain" then
			sides[vim.api.nvim_win_get_position(win)[2]] = true
		end
	end

	for _, win in ipairs(wins) do
		-- Text spans col .. col+width-1, the separator col+width,
		-- and the window beyond it starts one column further
		local col = vim.api.nvim_win_get_position(win)[2] + vim.api.nvim_win_get_width(win) + 1
		local saved = vim.w[win].centre_fillchars
		local opt = { scope = "local", win = win }
		if sides[col] then
			if saved == nil then
				-- A window keeps its options per buffer: `:e` back
				-- to a note brings back the `vert: ` added before
				local function without_vert(value)
					return vim.tbl_filter(function(item)
						return not vim.startswith(item, "vert:")
					end, vim.split(value, ",", { trimempty = true }))
				end
				local own = without_vert(vim.api.nvim_get_option_value("fillchars", opt))
				vim.w[win].centre_fillchars = table.concat(own, ",")
				-- An empty local value means "use the global one"
				local items = #own > 0 and own or without_vert(vim.go.fillchars)
				table.insert(items, "vert: ")
				vim.api.nvim_set_option_value("fillchars", table.concat(items, ","), opt)
			end
		elseif saved ~= nil then
			vim.api.nvim_set_option_value("fillchars", saved, opt)
			vim.w[win].centre_fillchars = nil
		end
	end
end

local function centre_markdown()
	local nnp = require("no-neck-pain")
	local timer = assert(vim.uv.new_timer())
	local busy = false

	local function apply()
		-- enable() and disable() finish on a timer; calling them
		-- again meanwhile would find the state half built
		if busy then
			return
		end
		local want = centre_wanted()
		if want == nil or want == centre_active() then
			return
		end
		busy = true
		-- disable() ends by focusing the markdown window it was
		-- centring: `:split x.lua` left the cursor off the new file
		local win = vim.api.nvim_get_current_win()
		if want then
			nnp.enable()
		else
			nnp.disable()
		end
		-- Then look again: events that came in while busy
		-- were dropped
		vim.defer_fn(function()
			busy = false
			if not want and vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_set_current_win(win)
			end
			apply()
		end, 50)
	end

	-- Opening a file fires a burst of events: decide once, and
	-- after the plugin's own reactions to them. Its layout
	-- refresh runs on a 2 ms timer and fails if disable() has
	-- already dropped the tab.
	local function schedule()
		timer:stop()
		timer:start(30, 0, vim.schedule_wrap(apply))
	end

	local group = vim.api.nvim_create_augroup("MarkdownCentre", { clear = true })
	vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "WinClosed", "TabEnter" }, {
		group = group,
		callback = schedule,
	})
	-- Side windows opening or closing resize the text window
	vim.api.nvim_create_autocmd({ "WinResized", "WinNew", "WinClosed", "TabEnter" }, {
		group = group,
		callback = vim.schedule_wrap(centre_separators),
	})
	schedule()
end

return {
	-- Colours, icons and layout inside the buffer --
	{
		"render-markdown.nvim",

		enabled = true,
		auto_enable = false,
		lazy = true,

		ft = { "markdown" },

		-- Emphasis colours used to be set from a ColorScheme
		-- autocmd registered here. It never fired: this runs
		-- when the first .md buffer opens, long after the
		-- colorscheme was applied. They live in core/theme.lua now.
		after = function(plugin)
			require("render-markdown").setup(plugin.opts or {})
		end,

		opts = {
			heading = {
				enabled = true,
				sign = true,
				-- The number is wider than the `#` it replaces:
				-- inline hides the marks and puts the number in
				-- front of the text instead of over it
				position = "inline",
				icons = heading_number,
				signs = { "󰫎 " },
				-- The "background" is the rule under the heading
				-- (MdHeadingRuleN in core/theme.lua, an underline
				-- with no colour fill). `block` with no padding
				-- or minimum makes it exactly as long as the
				-- number plus the text, ending on the last letter.
				width = "block",
				left_margin = 0,
				left_pad = 0,
				right_pad = 0,
				min_width = 0,
				border = false,
				border_virtual = false,
				border_prefix = false,
				above = "▁",
				below = "▔",
				backgrounds = {
					"MdHeadingRule1",
					"MdHeadingRule2",
					"MdHeadingRule3",
					"MdHeadingNoRule",
					"MdHeadingNoRule",
					"MdHeadingNoRule",
				},
				-- All six levels share one group: the number
				-- already says which level it is
				foregrounds = {
					"MdHeading",
					"MdHeading",
					"MdHeading",
					"MdHeading",
					"MdHeading",
					"MdHeading",
				},
			},
			paragraph = {
				enabled = false,
				left_margin = 0,
				min_width = 0,
			},
			code = {
				enabled = true,
				sign = true,
				style = "full",
				position = "left",
				language_pad = 0,
				language_name = true,
				disable_background = { "diff" },
				width = "full",
				left_margin = 0,
				left_pad = 0,
				right_pad = 0,
				min_width = 0,
				border = "thick",
				above = "▄",
				below = "▀",
				highlight = "RenderMarkdownCode",
				highlight_info = "RenderMarkdownCode",
				highlight_language = nil,
				highlight_border = false,
				highlight_fallback = "RenderMarkdownCodeFallback",
				highlight_inline = "RenderMarkdownCodeInline",
			},
			dash = {
				enabled = true,
				icon = "─",
				width = "full",
				highlight = "RenderMarkdownDash",
			},
			bullet = {
				enabled = true,
				-- One glyph per nesting level. These were four
				-- spaces: the marker was drawn as blank, so the
				-- `-` looked missing everywhere except under the
				-- cursor and inside a visual selection, the two
				-- places anti-conceal turns rendering off.
				-- Plain Unicode, no Nerd Font needed. The second
				-- level is U+2B29 BLACK SMALL DIAMOND, not the
				-- full-size U+25C6: it has to match the weight
				-- of the bullet above it, not outshout it.
				icons = { "•", "⬩", "-", "-" },
				ordered_icons = function(ctx)
					local value = vim.trim(ctx.value)
					local index = tonumber(value:sub(1, #value - 1))
					return string.format("%d.", index > 1 and index or ctx.index)
				end,
				left_pad = 0,
				right_pad = 0,
				highlight = "MdAccent",
			},
			checkbox = {
				enabled = true,
				unchecked = {
					icon = checkbox_icons.unchecked,
					highlight = "MdAccent",
				},
				checked = {
					icon = checkbox_icons.checked,
					highlight = "MdAccent",
				},
				custom = {
					todo = { raw = "[-]", rendered = "󰥔 ", highlight = "MdSoft", scope_highlight = nil },
					important = { raw = "[~]", rendered = "󰓎 ", highlight = "DiagnosticWarn" },
				},
			},
			quote = {
				enabled = true,
				icon = "▋",
				repeat_linebreak = true,
				highlight = "RenderMarkdownQuote",
			},
			pipe_table = {
				enabled = true,
				preset = "round",
				style = "full",
				cell = "padded",
				padding = 1,
				min_width = 0,
				alignment_indicator = "━",
				head = "RenderMarkdownTableHead",
				row = "RenderMarkdownTableRow",
			},
			-- `==text==`: its default links to the inline code
			-- colour, and the two could not be told apart
			inline_highlight = {
				enabled = true,
				highlight = "MdHighlight",
			},
			callout = {},
			link = {
				enabled = true,
				footnote = {
					superscript = true,
					prefix = "",
					suffix = "",
				},
				image = "󰥶 ",
				email = "󰀓 ",
				hyperlink = "󰌹 ",
				highlight = "RenderMarkdownLink",
				wiki = { icon = "󱗖 ", highlight = "RenderMarkdownWikiLink" },
				custom = {
					web = { pattern = "^http", icon = "󰖟 " },
					youtube = { pattern = "youtube%.com", icon = "󰗃 " },
					github = { pattern = "github%.com", icon = "󰊤 " },
					-- No neovim.io entry: its logo exists only below
					-- U+F8FF, a range once lost in a copy as spaces
					stackoverflow = { pattern = "stackoverflow%.com", icon = "󰓌 " },
					discord = { pattern = "discord%.com", icon = "󰙯 " },
					reddit = { pattern = "reddit%.com", icon = "󰑍 " },
				},
			},
			sign = {
				enabled = true,
				highlight = "RenderMarkdownSign",
			},
			indent = {
				enabled = false,
				per_level = 2,
				skip_level = 1,
				skip_heading = true,
			},
			-- Rendering formulas would need an external
			-- converter that is not in the build
			latex = {
				enabled = false,
			},
		},
	},

	-- Inline images (requires imagemagick) --
	{
		"image.nvim",

		enabled = require("core.setting").bool(true, "settings", "markdown", "images", "enable"),
		auto_enable = false,
		lazy = true,

		ft = { "markdown" },

		event = {
			"BufReadPre *.png",
			"BufReadPre *.jpg",
			"BufReadPre *.jpeg",
			"BufReadPre *.gif",
			"BufReadPre *.webp",
			"BufReadPre *.avif",
		},

		after = function(plugin)
			require("image").setup(plugin.opts)
			wezterm_image_redraw()
			wheel_without_margin()
		end,

		opts = {
			-- `kitty` also covers WezTerm: same protocol
			backend = nixInfo("kitty", "settings", "render-backend"),
			processor = "magick_cli",
			integrations = {
				markdown = {
					enabled = true,
					clear_in_insert_mode = false,
					download_remote_images = false,
					-- Every image stays drawn below its link,
					-- not only the one under the cursor
					only_render_image_at_cursor = false,
					floating_windows = false,
					filetypes = { "markdown" },
					resolve_image_path = function(document_path, image_path, fallback)
						return fallback(document_path, image_path)
					end,
				},
				html = { enabled = false },
				css = { enabled = false },
			},
			-- In terminal cells, not pixels: the text column
			-- is the natural limit, so an image is never wider
			-- than the prose around it. Smaller images keep
			-- their own size.
			max_width = nixInfo(75, "settings", "markdown", "line_length"),
			max_height = nil,
			max_width_window_percentage = nil,
			-- A tall image must not fill the whole window. At
			-- 50% a 16:9 picture stopped at ~50 columns: the
			-- height cap won before the width one
			max_height_window_percentage = nixInfo(80, "settings", "markdown", "images", "max_height"),
			-- Hides images under floats (telescope, cmp):
			-- WezTerm otherwise leaves them drawn on top
			window_overlap_clear_enabled = true,
			window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "snacks_notif", "scrollview", "scrollview_sign" },
			editor_only_render_when_focused = false,
			tmux_show_only_in_active_window = false,
			hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
		},
	},

	-- Live preview in the browser --
	-- Started by `:PreviewMd` (lua/tools/markdown.lua). Follows
	-- unsaved edits and the cursor. Rendered by markdown-it
	-- with GitHub's stylesheet: Obsidian callouts and wikilinks
	-- are not understood and show as quotes and plain text.
	{
		"live-preview.nvim",

		enabled = true,
		auto_enable = false,
		lazy = true,

		cmd = { "LivePreview" },

		after = function(plugin)
			require("livepreview.config").set(plugin.opts)
		end,

		opts = {
			-- Served from the file's own directory, so links
			-- into assets/ resolve wherever nvim was started.
			-- Paths climbing above it (`../img.png`) do not.
			dynamic_root = true,
			sync_scroll = true,
			-- "default" goes through vim.ui.open, hence
			-- through settings.open.browser
			browser = "default",
		},
	},

	-- Paste images from the clipboard --
	-- `:PasteImage` and <leader>ip ask for a name, then save
	-- assets/YYYY-MM-DD_HH-MM-SS_<name>.png beside the file
	-- and insert the link. Dropping an image file onto the
	-- terminal inserts a link to it as well.
	{
		"img-clip.nvim",

		enabled = true,
		auto_enable = false,
		lazy = true,

		cmd = { "PasteImage" },
		keys = {
			{
				"<leader>ip",
				function()
					require("tools.markdown").paste_image()
				end,
				mode = "n",
				desc = "Paste image from clipboard",
			},
		},

		after = function(plugin)
			require("img-clip").setup(plugin.opts)
			-- The plugin's own :PasteImage prompts for the whole
			-- file name; ours adds the timestamp
			vim.api.nvim_create_user_command("PasteImage", function()
				require("tools.markdown").paste_image()
			end, { desc = "Paste image from clipboard" })
		end,

		opts = {
			default = {
				dir_path = "assets",
				relative_to_current_file = true,
				extension = "png",
				file_name = "%Y-%m-%d_%H-%M-%S",
				prompt_for_file_name = false,
				-- Cursor lands in the alt text, which pandoc
				-- turns into the caption
				insert_mode_after_paste = true,
			},
			filetypes = {
				markdown = {
					-- The width is a pandoc attribute: it sizes the
					-- image in the PDF, the editor ignores it
					template = (function()
						local width = nixInfo("", "settings", "markdown", "images", "paste_width")
						local attr = width ~= "" and ("{ width=%s }"):format(width) or ""
						return "![$CURSOR]($FILE_PATH)" .. attr
					end)(),
				},
			},
		},
	},

	-- Centred column on wide screens --
	-- See centre_markdown() above. Nothing to toggle by hand:
	-- the layout follows the files shown and the screen width.
	{
		"no-neck-pain.nvim",

		enabled = require("core.setting").bool(true, "settings", "markdown", "center", "enable"),
		auto_enable = false,
		lazy = true,

		ft = { "markdown" },

		after = function(plugin)
			require("no-neck-pain").setup(plugin.opts)
			centre_markdown()
		end,

		opts = {
			width = CENTRE_WIDTH,
			-- The plugin drops a side at or below this; ours
			-- demands at least CENTRE_MIN_SIDE, so both agree
			minSideBufferWidth = CENTRE_MIN_SIDE - 1,
			autocmds = {
				-- Focus never lands in an empty side window
				skipEnteringNoNeckPainBuffer = true,
			},
			buffers = {
				-- No `~` down the empty windows, and no line
				-- between the left one and the text
				wo = { fillchars = "eob: ,vert: " },
			},
		},
	},
}
