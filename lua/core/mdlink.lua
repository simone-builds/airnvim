-- MARKDOWN LINKS
--------------------------------------------------
-- Follow a link with <CR> or Ctrl+click, create one with
-- <leader>il. The maps are set per buffer in core/keymaps.lua.
--
-- Paths are relative to the note holding the link, never to
-- nvim's cwd: that is how pandoc, rumdl and every markdown
-- viewer read them. Spaces travel as %20.

local M = {}

-- FINDING THE LINK
--------------------------------------------------

-- Destination of the link under the cursor, or nil. The link
-- lives in the injected markdown_inline tree, so injections
-- have to be parsed and searched.
local function destination()
	local ok, parser = pcall(vim.treesitter.get_parser, 0, "markdown")
	if not ok or not parser then
		return nil
	end
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	parser:parse({ row, row + 1 })

	local node = vim.treesitter.get_node({ ignore_injections = false })
	while node do
		local kind = node:type()
		if kind == "inline_link" or kind == "image" then
			for child in node:iter_children() do
				if child:type() == "link_destination" then
					return vim.treesitter.get_node_text(child, 0)
				end
			end
			return nil
		elseif kind == "uri_autolink" then
			return vim.treesitter.get_node_text(node, 0):sub(2, -2)
		end
		node = node:parent()
	end
end

-- HEADINGS
--------------------------------------------------

-- Anchor form of a heading, close to GitHub's and pandoc's:
-- lowercase, punctuation dropped, spaces as dashes. Both the
-- heading and the anchor typed in the link go through it, so
-- small differences in how they were written still match.
local function slug(text)
	return (text:lower():gsub("[^%w%s%-_\128-\255]", ""):gsub("%s+", "-"))
end

local function jump_to_heading(anchor)
	local want = slug(vim.uri_decode(anchor))
	for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		local text = line:match("^#+%s+(.-)%s*#*%s*$")
		if text and slug(text) == want then
			vim.api.nvim_win_set_cursor(0, { i, 0 })
			vim.cmd("normal! zz")
			return
		end
	end
	vim.notify("Heading not found: #" .. anchor, vim.log.levels.WARN)
end

-- OPENING IT
--------------------------------------------------

local TEXT = { md = true, markdown = true, txt = true }

local function open(dest, external)
	-- Web addresses and mail go to the system
	if dest:match("^%a[%w+.-]*:") then
		vim.ui.open(dest)
		return
	end

	local path, anchor = dest:match("^([^#]*)#?(.*)$")
	if path == "" then
		if anchor ~= "" then
			jump_to_heading(anchor)
		end
		return
	end

	path = vim.uri_decode(path)
	if not path:match("^[/~]") then
		path = vim.fs.joinpath(vim.fn.expand("%:p:h"), path)
	end
	path = vim.fs.normalize(path)

	local ext = (path:match("%.(%w+)$") or ""):lower()
	if external or (ext ~= "" and not TEXT[ext]) then
		vim.ui.open(path)
		return
	end

	if vim.fn.filereadable(path) == 0 then
		local choice = vim.fn.confirm(
			("Note does not exist:\n%s\nCreate it?"):format(vim.fn.fnamemodify(path, ":~")),
			"&Yes\n&No",
			2
		)
		if choice ~= 1 then
			return
		end
		-- Written at once, so the link is not dangling even if
		-- the new note is left without saving
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		vim.fn.writefile({}, path)
	end

	vim.cmd.edit(vim.fn.fnameescape(path))
	if anchor ~= "" then
		jump_to_heading(anchor)
	end
end

-- Follow the link under the cursor. Returns false when there
-- is none, so <CR> can keep its usual meaning.
function M.follow(opts)
	local dest = destination()
	if not dest or dest == "" then
		return false
	end
	-- Out of the keymap: opening a buffer is not allowed while
	-- an <expr> map is being evaluated
	vim.schedule(function()
		open(dest, opts and opts.external)
	end)
	return true
end

-- INSERTING ONE
--------------------------------------------------

-- `target` as seen from directory `from`, with `../` where
-- needed: vim.fs.relpath only handles descendants.
local function relative(from, target)
	local a = vim.split(vim.fs.normalize(from), "/", { trimempty = true })
	local b = vim.split(vim.fs.normalize(target), "/", { trimempty = true })
	local i = 1
	while a[i] and b[i] and a[i] == b[i] do
		i = i + 1
	end
	local parts = {}
	for _ = i, #a do
		table.insert(parts, "..")
	end
	for j = i, #b do
		table.insert(parts, b[j])
	end
	return table.concat(parts, "/")
end

-- Pick a note and write `[text](path)`. With a selection, the
-- selected words become the text; otherwise the brackets stay
-- empty and the cursor waits inside them.
function M.insert(visual)
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local here = vim.fn.expand("%:p:h")
	if here == "" then
		here = vim.fn.getcwd()
	end

	-- The range to replace, read before the picker takes focus
	-- Only a selection on one line: link text does not span lines
	local range, text = nil, ""
	if visual then
		local mode = vim.fn.mode()
		local s, e = vim.fn.getpos("v"), vim.fn.getpos(".")
		if s[2] > e[2] or (s[2] == e[2] and s[3] > e[3]) then
			s, e = e, s
		end
		if s[2] == e[2] then
			local line = vim.api.nvim_buf_get_lines(buf, s[2] - 1, s[2], false)[1]
			local first, last = s[3], e[3] + #vim.fn.matchstr(line:sub(e[3]), ".") - 1
			if mode == "V" then
				first, last = 1, #line
			end
			last = math.min(last, #line)
			range = { s[2] - 1, first - 1, s[2] - 1, last }
			text = line:sub(first, last)
		end
		vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
	end

	-- Same root as `\sf`, the directory nvim was started in,
	-- unless the note lies outside it
	local cwd = vim.fn.getcwd()
	local root = vim.startswith(here .. "/", cwd .. "/") and cwd or here

	require("lze").trigger_load("telescope.nvim")
	local actions = require("telescope.actions")
	local state = require("telescope.actions.state")

	require("telescope.builtin").find_files({
		cwd = root,
		prompt_title = "Link a note · " .. vim.fn.fnamemodify(root, ":~"),
		results_title = "[Nota B](nota-b.md#heading-level-1)",
		find_command = { "fd", "--type", "f", "--extension", "md", "--extension", "markdown" },
		attach_mappings = function(prompt)
			actions.select_default:replace(function()
				local entry = state.get_selected_entry()
				actions.close(prompt)
				if not entry then
					return
				end
				local target = vim.fs.joinpath(root, entry.value or entry[1])
				local path = relative(here, target):gsub(" ", "%%20")
				local link = ("[%s](%s)"):format(text, path)

				-- After telescope has finished closing, which would
				-- otherwise undo the switch to insert mode
				vim.schedule(function()
					vim.api.nvim_set_current_win(win)
					if range then
						vim.api.nvim_buf_set_text(buf, range[1], range[2], range[3], range[4], { link })
						return
					end
					local row, col = unpack(vim.api.nvim_win_get_cursor(win))
					-- After the cursor, like `a`, unless the line is empty
					local line = vim.api.nvim_get_current_line()
					local at = line == "" and 0 or col + #vim.fn.matchstr(line:sub(col + 1), ".")
					vim.api.nvim_buf_set_text(buf, row - 1, at, row - 1, at, { link })
					vim.api.nvim_win_set_cursor(win, { row, at + 1 })
					vim.cmd.startinsert()
				end)
			end)
			return true
		end,
	})
end

return M
