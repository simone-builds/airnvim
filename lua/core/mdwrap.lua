-- TEXT WRAPPING IN MARKDOWN FILES
--------------------------------------------------
-- `textwidth` only wraps while you type. This module adds
-- reflowing of text already written, skipping code blocks and
-- tables through Treesitter.

local M = {}

local group = vim.api.nvim_create_augroup("MarkdownWrap", { clear = true })

-- `inline` is the actual text of a paragraph or a list item.
-- Reflowing one node at a time is what keeps indentation
-- correct, nested lists included.
local WRAPPABLE = {
	inline = true,
}

-- Nodes never to touch, not even inside
local SKIP = {
	fenced_code_block = true,
	indented_code_block = true,
	pipe_table = true,
	html_block = true,
	atx_heading = true,
	setext_heading = true,
	link_reference_definition = true,
}

local function width()
	return nixInfo(75, "settings", "markdown", "line_length")
end

-- HARD LINE BREAKS
--------------------------------------------------
-- A markdown hard break is two trailing spaces or a trailing
-- backslash: it keeps the line to itself when the document is
-- exported (pandoc, typst) without turning it into its own
-- paragraph. Reflowing across one would erase that, so a block
-- is split into one segment per break and each is wrapped on
-- its own.
local function hard_break(line)
	local spaces = line and line:match("(  +)$")
	if spaces then
		-- Normalised to exactly two: MD009 allows no more
		return "  "
	end
	return line and line:match([[(\)$]])
end

-- WRAP COLUMN
--------------------------------------------------

-- True when the cursor sits inside a code block
local function in_code_block()
	local ok, node = pcall(vim.treesitter.get_node, { ignore_injections = true })
	if not ok or not node then
		return false
	end
	while node do
		local t = node:type()
		if t == "fenced_code_block" or t == "indented_code_block" or t == "code_span" then
			return true
		end
		node = node:parent()
	end
	return false
end

-- REFLOWING EXISTING TEXT
--------------------------------------------------

-- Split a block on its hard breaks. Each segment carries the
-- marker of the line that closes it, so it can be restored once
-- the segment has been reflowed.
local function segments(out, lines, first, last)
	local start = first
	for row = first, last do
		local marker = hard_break(lines[row])
		if marker then
			table.insert(out, { start, row, marker })
			start = row + 1
		end
	end
	if start <= last then
		table.insert(out, { start, last })
	end
end

-- Collect prose blocks without descending into children
local function collect(node, out, lines)
	for child in node:iter_children() do
		local t = child:type()
		if child:named() and not SKIP[t] then
			if WRAPPABLE[t] then
				local srow, _, erow, ecol = child:range()
				-- A node ending at column 0 does not include its
				-- last line
				if ecol == 0 then
					erow = erow - 1
				end
				if erow >= srow then
					segments(out, lines, srow + 1, erow + 1)
				end
			else
				collect(child, out, lines)
			end
		end
	end
end

-- Reflow every prose block in the buffer to `textwidth`
function M.wrap(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	if vim.bo[bufnr].filetype ~= "markdown" then
		return
	end

	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")
	if not ok or not parser then
		return
	end
	local tree = (parser:parse() or {})[1]
	if not tree then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local ranges = {}
	collect(tree:root(), ranges, lines)
	if #ranges == 0 then
		return
	end

	-- Bottom-up, so the line numbers of the ranges still
	-- pending stay valid
	table.sort(ranges, function(a, b)
		return a[1] > b[1]
	end)

	-- Reflow in a scratch buffer and write the result back in a
	-- single edit. Running `gq` on the real buffer costs a full
	-- Treesitter reparse per node, and there is one node per
	-- paragraph: on a 500-line document that was 126 reparses
	-- and ~3.4s, against ~0.1s here. It also collapses the
	-- reflow into one undo step instead of one per paragraph.
	local scratch = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)

	-- Copy the options `gq` reads. Setting `filetype` instead
	-- would fire FileType and attach Treesitter all over again.
	local tw = width()
	vim.bo[scratch].textwidth = tw
	vim.bo[scratch].formatoptions = vim.bo[bufnr].formatoptions
	vim.bo[scratch].formatlistpat = vim.bo[bufnr].formatlistpat
	vim.bo[scratch].comments = vim.bo[bufnr].comments
	vim.bo[scratch].expandtab = vim.bo[bufnr].expandtab
	vim.bo[scratch].shiftwidth = vim.bo[bufnr].shiftwidth
	vim.bo[scratch].tabstop = vim.bo[bufnr].tabstop
	-- `gq` must fall to vim's internal formatter: an attached LSP
	-- claims `formatexpr` and rumdl does not wrap prose, while
	-- Treesitter's `indentexpr` would re-indent the generated
	-- lines and lose list indentation.
	vim.bo[scratch].formatexpr = ""
	vim.bo[scratch].indentexpr = ""

	local function line_at(row)
		return vim.api.nvim_buf_get_lines(scratch, row - 1, row, false)[1] or ""
	end
	local function set_line(row, text)
		vim.api.nvim_buf_set_lines(scratch, row - 1, row, false, { text })
	end

	vim.api.nvim_buf_call(scratch, function()
		for _, range in ipairs(ranges) do
			local first, last, marker = range[1], range[2], range[3]

			-- `gq` drops trailing whitespace and would leave the
			-- marker in the middle of the joined text, so it is
			-- taken off first. The segment also wraps short by its
			-- width, since MD013 counts those columns too.
			if marker then
				local text = line_at(last)
				set_line(last, (text:sub(1, #text - #marker):gsub("%s+$", "")))
			end
			vim.bo[scratch].textwidth = marker and (tw - #marker) or tw

			local before = vim.api.nvim_buf_line_count(scratch)
			vim.cmd(("silent keepjumps normal! %dGgq%dG"):format(first, last))
			last = last + vim.api.nvim_buf_line_count(scratch) - before

			if marker then
				set_line(last, line_at(last) .. marker)
			end
		end
	end)

	local wrapped = vim.api.nvim_buf_get_lines(scratch, 0, -1, false)
	vim.api.nvim_buf_delete(scratch, { force = true })

	if vim.deep_equal(lines, wrapped) then
		return
	end

	local win = vim.fn.bufwinid(bufnr)
	local view = win ~= -1 and vim.api.nvim_win_call(win, vim.fn.winsaveview) or nil

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, wrapped)

	if view then
		vim.api.nvim_win_call(win, function()
			vim.fn.winrestview(view)
		end)
	end
end

vim.api.nvim_create_user_command("MdWrap", function()
	M.wrap(0)
end, { desc = "Reflow markdown prose to textwidth" })

-- AUTOCOMMANDS
--------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
	group = group,
	pattern = "markdown",
	callback = function(args)
		vim.opt_local.textwidth = width()
		vim.opt_local.formatoptions:append("t")
		-- `n` plus formatlistpat: lists keep their indentation
		vim.opt_local.formatoptions:append("n")
		vim.opt_local.formatlistpat = [[^\s*\%(\d\+[.)]\|[-*+]\)\s\+]]
		-- The markdown ftplugin registers `-`, `*` and `+` as
		-- comment markers, so `gq` treats them as comments and
		-- loses list indentation. Keep only the `>` quote.
		vim.opt_local.comments = "n:>"

		-- Auto-wrap must be off inside code blocks. The check runs
		-- on line change only, not on every keystroke.
		vim.api.nvim_create_autocmd({ "InsertEnter", "CursorMovedI" }, {
			group = group,
			buffer = args.buf,
			desc = "No auto-wrap inside code blocks",
			callback = function()
				local line = vim.api.nvim_win_get_cursor(0)[1]
				if vim.b.md_wrap_line == line then
					return
				end
				vim.b.md_wrap_line = line

				if in_code_block() then
					vim.opt_local.formatoptions:remove("t")
				else
					vim.opt_local.formatoptions:append("t")
				end
			end,
		})
	end,
})

-- `gq` must be left to vim's internal formatter, the only one
-- that rewraps prose. Both the LSP server (which claims
-- `formatexpr` on attach) and Treesitter (which claims
-- `indentexpr`) are cleared out of the way here.
vim.api.nvim_create_autocmd({ "LspAttach", "BufWinEnter" }, {
	group = group,
	callback = function(args)
		if vim.bo[args.buf].filetype == "markdown" then
			vim.bo[args.buf].formatexpr = ""
			vim.bo[args.buf].indentexpr = ""
		end
	end,
})

return M
