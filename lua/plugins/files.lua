-- FILE MANAGER AND SEARCH
--------------------------------------------------

-- Oil preview: text files only --
-- The preview reads a file as text. An image, a PDF or an
-- archive has few or no newlines, so "the first screenful of
-- lines" is most of the file: slow for a large one, and
-- garbage on screen anyway. Known binary extensions are
-- refused outright; anything else is sniffed for a NUL byte
-- in its first 8 KB, the test git and grep use.
local BINARY = {}
for ext in
	([[png jpg jpeg gif webp avif bmp ico tif tiff heic psd xcf
	pdf epub djvu mp3 flac ogg opus wav m4a aac mp4 mkv webm mov
	avi zip gz tgz xz zst bz2 tar 7z rar iso dmg deb rpm ttf otf
	woff woff2 so o a exe dll bin class jar pyc wasm sqlite db
	doc docx xls xlsx ppt pptx odt ods odp]]):gmatch("%S+")
do
	BINARY[ext] = true
end

local function not_text(path)
	local ext = path:match("%.(%w+)$")
	if ext and BINARY[ext:lower()] then
		return true
	end
	local file = io.open(path, "rb")
	if not file then
		return false
	end
	local head = file:read(8192) or ""
	file:close()
	return head:find("\0", 1, true) ~= nil
end

return {
	-- Oil: the filesystem as an editable buffer --
	{
		"oil.nvim",

		enabled = true,
		-- auto_enable must be off when setup lives in `after`
		auto_enable = false,
		-- NOTE: with lazy = true, `nvim .` would not open oil
		lazy = false,

		keys = {
			{
				"-",
				function()
					-- `settings.oil.preview` opens the preview with
					-- the list; otherwise `^p` toggles it
					local preview = require("core.setting").bool(false, "settings", "oil", "preview")
					require("oil").open_float(nil, preview and { preview = {} } or nil)
				end,
				desc = "Open Oil float",
			},
		},

		after = function()
			require("oil").setup({
				default_file_explorer = true,
				columns = {
					"icon",
				},
				buf_options = {
					buflisted = false,
					bufhidden = "hide",
				},
				win_options = {
					wrap = false,
					signcolumn = "no",
					cursorcolumn = false,
					foldcolumn = "0",
					spell = false,
					list = false,
					conceallevel = 3,
					concealcursor = "nvic",
				},
				delete_to_trash = false,
				skip_confirm_for_simple_edits = false,
				prompt_save_on_select_new_entry = true,
				cleanup_delay_ms = 2000,
				lsp_file_methods = {
					timeout_ms = 1000,
					autosave_changes = false,
				},
				constrain_cursor = "editable",
				-- Continuously watching the filesystem costs CPU
				experimental_watch_for_changes = false,
				keymaps = {
					["g?"] = "actions.show_help",
					["<C-h>"] = "actions.select_split",
					["<C-t>"] = "actions.select_tab",
					["<C-p>"] = "actions.preview",
					["<C-c>"] = "actions.close",
					["<C-l>"] = "actions.refresh",
					["-"] = "actions.select",
					["."] = "actions.parent",
					["_"] = "actions.open_cwd",
					["`"] = "actions.cd",
					["~"] = "actions.tcd",
					["gs"] = "actions.change_sort",
					["gx"] = "actions.open_external",
					["g."] = "actions.toggle_hidden",
					["g\\"] = "actions.toggle_trash",
				},
				use_default_keymaps = true,
				view_options = {
					show_hidden = true,
					is_hidden_file = function(name, _)
						return vim.startswith(name, ".")
					end,
					is_always_hidden = function(_, _)
						return false
					end,
					natural_order = true,
					sort = {
						{ "type", "asc" },
						{ "name", "asc" },
					},
				},
				extra_scp_args = {},
				git = {
					add = function(_)
						return false
					end,
					mv = function(_, _)
						return false
					end,
					rm = function(_)
						return false
					end,
				},
				float = {
					border = "rounded",
					-- `settings.oil.width`, a percentage: wide enough
					-- to share with the preview (`^p`), which opens
					-- on the right of the list
					max_width = nixInfo(75, "settings", "oil", "width") / 100,
					max_height = 0.6,
					preview_split = "right",
					override = function(conf)
						return conf
					end,
				},
				-- `fast_scratch` reads only the first screenful of
				-- lines, highlighted by treesitter with no LSP or
				-- plugin attached: a long file costs what a short
				-- one does, and the wheel scrolls that much of it
				preview_win = {
					update_on_cursor_moved = true,
					preview_method = "fast_scratch",
					disable_preview = not_text,
				},
				preview = {
					max_width = 0.9,
					min_width = { 40, 0.4 },
					width = nil,
					max_height = 0.9,
					min_height = { 5, 0.1 },
					height = nil,
					border = "rounded",
					win_options = {
						winblend = 0,
					},
				},
				progress = {
					max_width = 0.9,
					min_width = { 40, 0.4 },
					width = nil,
					max_height = { 10, 0.9 },
					min_height = { 5, 0.1 },
					height = nil,
					border = "rounded",
					minimized_border = "none",
					win_options = {
						winblend = 0,
					},
				},
				ssh = {
					border = "rounded",
				},
				keymaps_help = {
					border = "rounded",
				},
			})

			-- Mouse wheel in the preview --
			-- Oil opens its preview as a non-focusable float, so
			-- mouse events fall through to the window behind it.
			-- The float is made once and every previewed file is
			-- loaded into it from inside, which is when this fires;
			-- `mouse` lets the wheel scroll it while the cursor
			-- stays in the list.
			vim.api.nvim_create_autocmd("BufWinEnter", {
				group = vim.api.nvim_create_augroup("OilPreviewMouse", { clear = true }),
				callback = function()
					local win = vim.api.nvim_get_current_win()
					if vim.w[win].oil_preview then
						vim.api.nvim_win_set_config(win, { mouse = true })
					end
				end,
			})
		end,
	},

	-- Telescope: fuzzy finding --
	{
		"telescope.nvim",

		enabled = true,
		auto_enable = false,
		lazy = true,

		cmd = { "Telescope" },
		keys = {
			{ "<leader>sh", "<cmd>Telescope help_tags<CR>", desc = "[S]earch [H]elp" },
			{ "<leader>sk", "<cmd>Telescope keymaps<CR>", desc = "[S]earch [K]eymaps" },
			{ "<leader>sf", "<cmd>Telescope find_files<CR>", desc = "[S]earch [F]iles" },
			{ "<leader>ss", "<cmd>Telescope builtin<CR>", desc = "[S]earch [S]elect Telescope" },
			{ "<leader>sw", "<cmd>Telescope grep_string<CR>", desc = "[S]earch current [W]ord" },
			{ "<leader>sg", "<cmd>Telescope live_grep<CR>", desc = "[S]earch by [G]rep" },
			{ "<leader>sd", "<cmd>Telescope diagnostics<CR>", desc = "[S]earch [D]iagnostics" },
			{ "<leader>sr", "<cmd>Telescope resume<CR>", desc = "[S]earch [R]esume" },
			{ "<leader>s.", "<cmd>Telescope oldfiles<CR>", desc = "[S]earch Recent Files" },
			{ "<leader><leader>", "<cmd>Telescope buffers<CR>", desc = "[ ] Find existing buffers" },
			{ "<leader>sb", "<cmd>Telescope buffers<CR>", desc = "[S]earch existing [B]uffers" },
			{ "<leader>sc", "<cmd>Telescope commands<CR>", desc = "[S]earch [C]ommands" },
			{ "<leader>gc", "<cmd>Telescope git_commits<CR>", desc = "[G]it [C]ommits" },
			{ "<leader>gs", "<cmd>Telescope git_status<CR>", desc = "[G]it [S]tatus" },
			{ "<leader>gb", "<cmd>Telescope git_branches<CR>", desc = "[G]it [B]ranches" },
			{
				"<leader>/",
				function()
					require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
						winblend = 0,
						previewer = false,
					}))
				end,
				desc = "[/] Fuzzily search in current buffer",
			},
			{
				"<leader>sn",
				function()
					require("telescope.builtin").find_files({ cwd = require("core.paths").config() })
				end,
				desc = "[S]earch [N]eovim files",
			},
		},

		-- obsidian.nvim resolves its picker at setup time:
		-- without this dependency it falls back to the builtin
		dep_of = { "codecompanion.nvim", "obsidian.nvim" },
		branch = "0.1.x",

		after = function()
			local telescope = require("telescope")
			local actions = require("telescope.actions")

			telescope.setup({
				defaults = {
					mappings = {
						i = {
							["<C-y>"] = actions.select_default,
						},
						n = {
							["q"] = actions.close,
						},
					},
				},
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown(),
					},
				},
			})

			-- Dependencies have already been loaded by lze
			pcall(telescope.load_extension, "fzf")
			pcall(telescope.load_extension, "ui-select")
		end,
	},
	{
		"telescope-fzf-native.nvim",
		enabled = true,
		auto_enable = true,
		lazy = true,
		dep_of = { "telescope.nvim" },
	},
	{
		"telescope-ui-select.nvim",
		enabled = true,
		auto_enable = true,
		lazy = true,
		dep_of = { "telescope.nvim" },
	},
}
