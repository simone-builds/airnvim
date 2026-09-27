-- MARKDOWN COMMANDS
--------------------------------------------------
-- `:PreviewMd` drives live-preview.nvim, `:PasteImage` and
-- <leader>ip drive img-clip.nvim. Both plugins load on first
-- use; only the commands are registered here.

local M = {}

-- BROWSER PREVIEW
--------------------------------------------------
-- `:PreviewMd` previews the current buffer, restarting on it
-- if another file was being shown; `:PreviewMd stop` ends
-- it. The server lives inside nvim and dies with it.
vim.api.nvim_create_user_command("PreviewMd", function(args)
	vim.cmd(args.args == "stop" and "LivePreview close" or "LivePreview start")
end, {
	nargs = "?",
	complete = function()
		return { "stop" }
	end,
	desc = "Live markdown preview in the browser",
})

-- IMAGE PASTE
--------------------------------------------------
-- Images land in assets/ beside the current file, named
-- `YYYY-MM-DD_HH-MM-SS_<name>.png`. The stamp keeps names
-- unique and sorted; the name, asked in a popup, says what
-- the picture is. An empty name leaves the stamp alone.

local STAMP = "%Y-%m-%d_%H-%M-%S"

-- Only characters safe in a path and in a markdown link:
-- spaces become dashes, anything else is dropped. It also
-- keeps `%` out, which os.date would read as a format.
local function sanitize(name)
	return (vim.trim(name):gsub("%s+", "-"):gsub("[^%w%-_.]", ""))
end

-- One-line input in a centred float --
-- <CR> confirms, <Esc> or leaving the window cancels.
local function prompt(title, on_done)
	local width = 50
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = 1,
		row = math.floor((vim.o.lines - 3) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " " .. title .. " ",
		title_pos = "center",
		footer = " <CR> save · <Esc> cancel ",
		footer_pos = "center",
	})
	vim.bo[buf].bufhidden = "wipe"

	local done = false
	local function finish(value)
		if done then
			return
		end
		done = true
		vim.cmd.stopinsert()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		-- After the float is gone, so the text goes into the
		-- window the paste was started from
		vim.schedule(function()
			on_done(value)
		end)
	end

	local opts = { buffer = buf, nowait = true }
	vim.keymap.set({ "i", "n" }, "<CR>", function()
		finish(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "")
	end, opts)
	vim.keymap.set({ "i", "n" }, "<Esc>", function()
		finish(nil)
	end, opts)
	vim.api.nvim_create_autocmd("WinLeave", {
		buffer = buf,
		once = true,
		callback = function()
			finish(nil)
		end,
	})

	vim.cmd.startinsert()
end

function M.paste_image()
	local clipboard = require("img-clip.clipboard")

	-- Not an image (a copied path or URL, or plain text):
	-- img-clip decides what to do, no name is needed
	if not clipboard.get_clip_cmd() or not clipboard.content_is_image() then
		require("img-clip").paste_image()
		return
	end

	prompt("Image name", function(name)
		if name == nil then
			return
		end
		name = sanitize(name)
		require("img-clip").paste_image({
			file_name = name == "" and STAMP or (STAMP .. "_" .. name),
			prompt_for_file_name = false,
		})
	end)
end

return M
