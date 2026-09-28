-- FORMAT A DIRECTORY OF MARKDOWN FILES
--------------------------------------------------
-- `:MdFormatDir [dir]` runs on every `.md` file of a directory
-- what `:w` runs on a markdown buffer: core.rumdl.format(),
-- i.e. rumdl, mdwrap, rumdl. Subdirectories are left alone;
-- `:MdFormatDirRecursive [dir]` goes down into them too. With
-- no argument both take the current file's directory, the one
-- Oil is showing, or `:pwd`. Hidden files and directories are
-- skipped, and so is anything not ending in `.md`.
--
-- One file per event-loop turn, so the progress float redraws
-- and `q` can cancel between files. A file is written only if
-- its text changed, so clean files keep their mtime. A file
-- open here with unsaved changes, or open in another nvim
-- (swap file), is skipped instead of written.

local M = {}

local BAR = 30
local running = false
-- Set while a file is being read, for the SwapExists hook
local loading = nil

-- FILES
--------------------------------------------------

local function default_dir()
	if vim.bo.filetype == "oil" then
		local ok, oil = pcall(require, "oil")
		local dir = ok and oil.get_current_dir()
		if dir then
			return dir
		end
	end
	local name = vim.api.nvim_buf_get_name(0)
	if name ~= "" and vim.bo.buftype == "" then
		return vim.fs.dirname(name)
	end
	return vim.fn.getcwd()
end

-- Visible `.md` files of `dir`, and with `recursive` of its
-- visible subdirectories. Symlinked directories are not
-- followed, so a link pointing up cannot loop.
local function markdown_files(dir, recursive)
	local found = {}
	local opts = {
		depth = recursive and math.huge or 1,
		-- `.git`, `.obsidian`, `.trash` and the like
		skip = function(sub)
			return not vim.fs.basename(sub):match("^%.")
		end,
	}
	-- With depth, `name` is relative to `dir`: sub/note.md
	for name, kind in vim.fs.dir(dir, opts) do
		local path = vim.fs.joinpath(dir, name)
		local base = vim.fs.basename(name)
		if
			(kind == "file" or kind == "link")
			and base:match("%.md$")
			and not base:match("^%.")
			and vim.fn.isdirectory(path) == 0
		then
			found[#found + 1] = path
		end
	end
	table.sort(found)
	return found
end

-- ONE FILE
--------------------------------------------------
-- Returns "changed", "unchanged" or "skipped", or raises.

local function text(bufnr)
	return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

local function format_file(path)
	local bufnr = vim.fn.bufnr(path)
	local was_open = bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr)
	if was_open and vim.bo[bufnr].modified then
		return "skipped"
	end
	if bufnr == -1 then
		bufnr = vim.fn.bufadd(path)
	end

	local ok, result = pcall(function()
		if not was_open then
			loading = path
			vim.cmd(("silent call bufload(%d)"):format(bufnr))
			loading = nil
		end
		if vim.bo[bufnr].readonly then
			return "skipped"
		end
		if vim.bo[bufnr].filetype ~= "markdown" then
			-- Inside the buffer, so the FileType options that
			-- mdwrap sets with opt_local land on this one
			vim.api.nvim_buf_call(bufnr, function()
				vim.bo.filetype = "markdown"
			end)
		end

		-- The same pipeline as `:w`
		local before = text(bufnr)
		require("core.rumdl").format(bufnr)
		if text(bufnr) == before then
			return "unchanged"
		end

		-- noautocmd: BufWritePre would format a second time
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("noautocmd silent keepalt write")
		end)
		return "changed"
	end)
	loading = nil

	if not was_open and vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end
	if not ok then
		error(result, 0)
	end
	return result
end

-- PROGRESS FLOAT
--------------------------------------------------

local function open_float(state)
	local width = BAR + 14
	state.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[state.buf].bufhidden = "wipe"
	state.win = vim.api.nvim_open_win(state.buf, true, {
		relative = "editor",
		anchor = "SE",
		row = vim.o.lines - 2,
		col = vim.o.columns,
		width = width,
		height = 3,
		style = "minimal",
		border = "rounded",
		title = (" %s "):format(state.command),
		title_pos = "center",
		footer = " q cancel ",
		footer_pos = "center",
	})

	local function cancel()
		state.cancelled = true
	end
	for _, lhs in ipairs({ "q", "<Esc>", "<C-c>" }) do
		vim.keymap.set("n", lhs, cancel, { buffer = state.buf, nowait = true })
	end
	-- Closing the float by hand cancels too. In state.group,
	-- which finish() deletes before closing it itself.
	vim.api.nvim_create_autocmd("WinClosed", {
		group = state.group,
		pattern = tostring(state.win),
		once = true,
		callback = cancel,
	})
end

local ns = vim.api.nvim_create_namespace("MdFormatDir")

-- Path shown for a file: relative to the starting directory,
-- since two subdirectories can each hold a notes.md
local function label(state, path)
	return vim.fs.relpath(state.root, path) or path
end

local function render(state)
	if not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
	local total = #state.files
	local done = state.index - 1
	local fill = math.floor(done / total * BAR)
	local current = state.files[state.index]
	local counts = ("changed %d · unchanged %d"):format(state.count.changed, state.count.unchanged)
	local issues = state.count.skipped + state.count.failed
	if issues > 0 then
		counts = counts .. (" · skipped %d"):format(issues)
	end

	local bar = ("█"):rep(fill) .. ("░"):rep(BAR - fill)
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, {
		(" %s %3d%%"):format(bar, math.floor(done / total * 100)),
		(" %d/%d · %s"):format(math.min(state.index, total), total, current and label(state, current) or "done"),
		" " .. counts,
	})
	vim.api.nvim_buf_clear_namespace(state.buf, ns, 0, -1)
	vim.api.nvim_buf_set_extmark(state.buf, ns, 0, 1, {
		end_col = 1 + #("█"):rep(fill),
		hl_group = "MdAccent",
	})
	vim.cmd.redraw()
end

-- RUN
--------------------------------------------------

local function finish(state)
	running = false
	vim.api.nvim_del_augroup_by_id(state.group)
	if vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end

	local c = state.count
	local total = c.changed + c.unchanged + c.skipped + c.failed
	local msg = ("%s: %d files, %d changed, %d unchanged"):format(state.command, total, c.changed, c.unchanged)
	if state.cancelled then
		msg = msg .. (" (cancelled, %d not reached)"):format(#state.files - total)
	end
	local level = vim.log.levels.INFO
	if #state.problems > 0 then
		msg = msg .. "\n" .. table.concat(state.problems, "\n")
		level = vim.log.levels.WARN
	end
	vim.notify(msg, level)
end

-- `root` is the directory the files were collected from, and
-- `command` names the run in the float and the report
function M.run(files, root, command)
	if running then
		vim.notify("A markdown format run is already going", vim.log.levels.WARN)
		return
	end
	running = true
	require("lze").trigger_load("conform.nvim")

	local state = {
		files = files,
		root = root or vim.fs.dirname(files[1]),
		command = command or "MdFormatDir",
		index = 1,
		count = { changed = 0, unchanged = 0, skipped = 0, failed = 0 },
		problems = {},
		group = vim.api.nvim_create_augroup("MdFormatDir", { clear = true }),
	}

	-- A file open in another nvim is opened read-only here
	-- instead of stopping the run on the ATTENTION prompt
	vim.api.nvim_create_autocmd("SwapExists", {
		group = state.group,
		callback = function()
			if loading then
				vim.v.swapchoice = "o"
			end
		end,
	})

	open_float(state)

	local function step()
		if state.cancelled or state.index > #files then
			render(state)
			return finish(state)
		end
		render(state)

		local path = files[state.index]
		local ok, result = pcall(format_file, path)
		local name = label(state, path)
		if not ok then
			state.count.failed = state.count.failed + 1
			state.problems[#state.problems + 1] = ("  failed  %s: %s"):format(name, result)
		else
			state.count[result] = state.count[result] + 1
			if result == "skipped" then
				state.problems[#state.problems + 1] = ("  skipped %s: unsaved changes or open elsewhere"):format(name)
			end
		end

		state.index = state.index + 1
		-- A timer, not vim.schedule: it lets typed keys (q) in
		-- between two files
		vim.defer_fn(step, 0)
	end
	step()
end

function M.running()
	return running
end

-- COMMANDS
--------------------------------------------------

local function command(name, recursive)
	return function(args)
		local dir = args.args ~= "" and vim.fn.expand(args.args) or default_dir()
		dir = vim.fs.normalize(vim.fn.fnamemodify(dir, ":p"))
		if vim.fn.isdirectory(dir) == 0 then
			vim.notify(("%s: not a directory: %s"):format(name, dir), vim.log.levels.ERROR)
			return
		end

		local files = markdown_files(dir, recursive)
		local where = vim.fn.fnamemodify(dir, ":~")
		if #files == 0 then
			vim.notify(("%s: no markdown files in %s"):format(name, where))
			return
		end

		if recursive then
			local dirs = {}
			for _, path in ipairs(files) do
				dirs[vim.fs.dirname(path)] = true
			end
			where = ("%d directories under %s"):format(vim.tbl_count(dirs), where)
		end
		local question = ("Format %d markdown files in %s?\nCommit first: they are rewritten in place."):format(
			#files,
			where
		)
		if vim.fn.confirm(question, "&Yes\n&No", 2) == 1 then
			M.run(files, dir, name)
		end
	end
end

vim.api.nvim_create_user_command("MdFormatDir", command("MdFormatDir", false), {
	nargs = "?",
	complete = "dir",
	desc = "Format every markdown file of a directory",
})

vim.api.nvim_create_user_command("MdFormatDirRecursive", command("MdFormatDirRecursive", true), {
	nargs = "?",
	complete = "dir",
	desc = "Format every markdown file of a directory tree",
})

return M
