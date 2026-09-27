-- GLOBAL KEYMAPS
--------------------------------------------------
-- A plugin's own maps live in its spec; filetype-local ones
-- live in core/autocmds.lua.

-- Line navigation: H to the start, L to the end.
-- Works in operator pending too (dL, yH).
vim.keymap.set({ "n", "x", "o" }, "H", "^", { desc = "Go to start of line" })
vim.keymap.set({ "n", "x", "o" }, "L", "$", { desc = "Go to end of line" })

-- MARKDOWN EMPHASIS
--------------------------------------------------
-- Wrap the visual selection. `<C-b>` costs the page-back
-- scroll in visual mode, which `<C-u>` still covers.
-- `<C-i>` is the same byte as `<Tab>`, so Tab italicises too;
-- `<C-`>` is not an ASCII control code and needs a terminal
-- speaking the kitty keyboard protocol.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function(args)
		local emphasis = {
			{ "<C-b>", "**", "bold" },
			{ "<C-i>", "*", "italic" },
			{ "<C-`>", "`", "inline code" },
		}
		for _, e in ipairs(emphasis) do
			vim.keymap.set("x", e[1], "c" .. e[2] .. '<C-r>"' .. e[2] .. "<Esc>", {
				buffer = args.buf,
				silent = true,
				desc = "Markdown: " .. e[3] .. " selection",
			})
		end

		-- Table of contents: the same list as the builtin `gO`,
		-- whose map (from the markdown ftplugin) it replays
		vim.keymap.set("n", "<leader>t", "gO", {
			buffer = args.buf,
			remap = true,
			desc = "Markdown: table of contents",
		})

		-- Links (core/mdlink.lua) --
		-- <CR> follows the link under the cursor; anywhere else it
		-- keeps its plain meaning, one line down.
		local link = require("core.mdlink")
		vim.keymap.set("n", "<CR>", function()
			return link.follow() and "" or "<CR>"
		end, { buffer = args.buf, expr = true, desc = "Markdown: follow link" })

		-- Ctrl+click: the default would jump to a tag, which means
		-- nothing in prose. A plain click places the cursor first:
		-- getmousepos() counts the columns render-markdown hides,
		-- so past the first link it pointed at the wrong one.
		vim.keymap.set("n", "<C-LeftMouse>", function()
			return "<LeftMouse><Cmd>lua require('core.mdlink').follow()<CR>"
		end, { buffer = args.buf, expr = true, desc = "Markdown: follow link" })

		-- gx on a link resolves its path from this note, not from
		-- the cwd; elsewhere it does what it always did
		vim.keymap.set("n", "gx", function()
			if not link.follow({ external = true }) then
				for _, url in ipairs(vim.ui._get_urls()) do
					vim.ui.open(url)
				end
			end
		end, { buffer = args.buf, desc = "Markdown: open link externally" })

		vim.keymap.set({ "n", "x" }, "<leader>il", function()
			link.insert(vim.fn.mode():find("^[vV]") ~= nil)
		end, { buffer = args.buf, desc = "Markdown: insert link to a note" })
	end,
})
