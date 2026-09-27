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

-- STANDALONE IMAGES
--------------------------------------------------
-- A line holding nothing but an image. Text on the line next
-- to it belongs to the same paragraph: the reflow pulls it onto
-- the image line, and pandoc only makes a figure, with the alt
-- text as caption, of an image alone in its paragraph. Such a
-- line therefore gets a blank line on both sides.
-- Pandoc attributes may follow: `![](x.png){ width=15cm }`.
local function is_image_line(line)
	return line:match("^!%[.-%]%(.-%)%s*$") ~= nil
		or line:match("^!%[.-%]%(.-%)%b{}%s*$") ~= nil
		or line:match("^!%[%[.-%]%]%s*$") ~= nil
end

-- HEADINGS MISSING THEIR SPACE
--------------------------------------------------
-- `##Title` is paragraph text until it gets its space: the
-- reflow pulled it into the lines around it, and rumdl's MD018
-- then made a heading of the whole merged line. Two to six
-- marks followed by a letter (accented ones too) get the
-- space here. A single `#word` is an Obsidian tag, an ordinary
-- word wherever it lands, so it is never touched; MD018 is
-- disabled in module.nix for the same reason.
local function fix_heading(line)
	local marks, rest = line:match("^(#+)([%a\128-\255].*)$")
	if marks and #marks >= 2 and #marks <= 6 then
		return marks .. " " .. rest
	end
end

-- Last line of the YAML front matter, 0 when there is none
local function front_matter_end(lines)
	if lines[1] ~= "---" then
		return 0
	end
	for i = 2, #lines do
		if lines[i] == "---" or lines[i] == "..." then
			return i
		end
	end
	return 0
end

-- Fenced code, for the line-by-line passes: given the fence
-- open before `line`, returns the one open after it and
-- whether `line` is prose. A fence closes on the same
-- character, at least as long.
local function track_fence(line, fence)
	local mark = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
	if fence then
		if mark and mark:sub(1, 1) == fence:sub(1, 1) and #mark >= #fence and line:match("^%s*[`~]+%s*$") then
			return nil, false
		end
		return fence, false
	elseif mark then
		return mark, false
	end
	return nil, true
end

-- Copy of `lines` with headings fixed and blanks added around
-- them and around images. Fenced code and front matter are
-- left alone: syntax shown as an example stays as it is, and
-- `##` is a comment in YAML.
local function space_blocks(lines)
	local out, fence = {}, nil
	local front = front_matter_end(lines)
	for i, line in ipairs(lines) do
		local outside
		fence, outside = track_fence(line, fence)

		local prose = i > front and outside
		local heading = prose and fix_heading(line)
		local alone = heading or (prose and is_image_line(line))
		if alone and #out > 0 and out[#out]:match("%S") then
			table.insert(out, "")
		end
		table.insert(out, heading or line)
		if alone and lines[i + 1] and lines[i + 1]:match("%S") then
			table.insert(out, "")
		end
	end
	return out
end

-- Trailing runs of three or more spaces cut to two, outside
-- fenced code. rumdl's MD009 fix deletes such a run whole and
-- the hard break goes with it (`verse,   ` joined the next
-- line); two spaces it keeps. core/rumdl.lua runs this before
-- its first rumdl pass.
function M.normalize_breaks(bufnr)
	local fence, outside
	for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		fence, outside = track_fence(line, fence)
		if outside and line:match("%S   +$") then
			vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { (line:gsub("  +$", "  ")) })
		end
	end
end

-- WRITING BACK
--------------------------------------------------
-- Only the hunks that changed are written. Replacing the whole
-- buffer collapsed every extmark in it, image.nvim's included:
-- the space kept under an image vanished, text was drawn over
-- the picture, and the render on save aimed at a line that no
-- longer existed (E966). Bottom-up, so earlier hunks keep their
-- line numbers. All of it is still a single undo step.
local diff = (vim.text and vim.text.diff) or vim.diff

local function apply(bufnr, old, new)
	local hunks = diff(table.concat(old, "\n") .. "\n", table.concat(new, "\n") .. "\n", { result_type = "indices" })
	for i = #hunks, 1, -1 do
		local a_start, a_count, b_start, b_count = unpack(hunks[i])
		local replacement = vim.list_slice(new, b_start, b_start + b_count - 1)
		-- An insertion reports the line it goes after
		local first = a_count == 0 and a_start or a_start - 1
		vim.api.nvim_buf_set_lines(bufnr, first, first + a_count, false, replacement)
	end
end

-- REFLOWING EXISTING TEXT
--------------------------------------------------

-- An Obsidian callout header, `> [!note]` or `> > [!tip]- Title`.
-- Treesitter sees plain quote text, and joining the body onto
-- this line made the body the callout's title.
local function is_callout(line)
	return line:match("^%s*>[%s>]*%[!%w[%w-]*%][+-]?") ~= nil
end

-- Split a block on its hard breaks. Each segment carries the
-- marker of the line that closes it, so it can be restored once
-- the segment has been reflowed. Callout headers and display
-- math (`$$` lines and what they enclose) are left out of every
-- segment: never joined to their neighbours, never wrapped.
local function segments(out, lines, first, last)
	local start, math = first, false
	for row = first, last do
		local line = lines[row]
		local dollars = line:match("^%s*%$%$")
		if math or dollars or is_callout(line) then
			if start < row then
				table.insert(out, { start, row - 1 })
			end
			start = row + 1
			-- A line holding both `$$` (`$$ x $$ text`) opens nothing
			local _, pairs = line:gsub("%$%$", "")
			if dollars and pairs < 2 then
				math = not math
			end
		else
			local marker = hard_break(line)
			if marker then
				table.insert(out, { start, row, marker })
				start = row + 1
			end
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
				-- A lone image has nothing to wrap, and `gq` would
				-- break a long alt text across lines
				local lone_image = erow == srow and is_image_line(lines[srow + 1])
				if erow >= srow and not lone_image then
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

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local spaced = space_blocks(lines)

	-- The spaced text is parsed as a string: it is not in the
	-- buffer yet, and the result is written back in one go
	local ok, parser = pcall(vim.treesitter.get_string_parser, table.concat(spaced, "\n"), "markdown")
	if not ok or not parser then
		return
	end
	local tree = (parser:parse() or {})[1]
	if not tree then
		return
	end

	local ranges = {}
	collect(tree:root(), ranges, spaced)
	-- A fixed heading may change a line without adding one
	if #ranges == 0 and vim.deep_equal(spaced, lines) then
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
	vim.api.nvim_buf_set_lines(scratch, 0, -1, false, spaced)

	-- Copy the options `gq` reads. Setting `filetype` instead
	-- would fire FileType and attach Treesitter all over again.
	local tw = width()
	vim.bo[scratch].textwidth = tw
	vim.bo[scratch].formatoptions = vim.bo[bufnr].formatoptions
	-- `j`: the join below drops the `>` leaders of quote lines
	vim.bo[scratch].formatoptions = vim.bo[scratch].formatoptions:gsub("j", "") .. "j"
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

			-- Joined into one line first: `gq` takes any line of
			-- its range matching formatlistpat for a new list
			-- item, so a wrapped line opening with "1954. " got a
			-- hanging indent and a quote came out as `> >    `.
			-- Joined, only the first line's real marker is seen.
			local before = vim.api.nvim_buf_line_count(scratch)
			if last > first then
				vim.cmd(("silent keepjumps %d,%djoin"):format(first, last))
			end
			vim.cmd(("silent keepjumps normal! %dGgqq"):format(first))
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

	apply(bufnr, lines, wrapped)

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
