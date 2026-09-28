-- USER INTERFACE
--------------------------------------------------
-- Statusline, dashboard, icons, notifications, colours.

return {
	-- Statusline --
	{
		"lualine.nvim",

		enabled = true,
		auto_enable = false,
		lazy = false,

		after = function()
			local function setup()
				require("lualine").setup({
					options = {
						icons_enabled = true,
						theme = require("core.theme").lualine(),
						component_separators = "",
						section_separators = { left = "", right = "" },
					},
					sections = {
						lualine_a = {
							{ "mode", right_padding = 2 },
						},
						lualine_b = {
							"filename",
							"branch",
							"diff",
							"diagnostics",
						},
						lualine_c = {
							{ "filename", path = 1 },
							"%=",
						},
						lualine_y = { "progress" },
						lualine_z = { { "location", left_padding = 2 } },
					},
					inactive_sections = {
						lualine_a = { "filename" },
						lualine_b = {},
						lualine_c = {},
						lualine_x = {},
						lualine_y = {},
						lualine_z = { "location" },
					},
					tabline = {},
					extensions = { "oil" },
				})
			end

			setup()

			-- No statusline in floating windows. Since 0.12 a float
			-- shows one when its local 'statusline' is set, and
			-- lualine sets it on every window it refreshes: Oil's
			-- preview grew a `[No Name]` bar and stood one row
			-- taller than the list beside it. A nil result leaves
			-- the float with the empty statusline `style=minimal`
			-- gave it.
			local lualine = require("lualine")
			local draw = lualine.statusline
			lualine.statusline = function(...)
				if vim.api.nvim_win_get_config(0).relative ~= "" then
					return nil
				end
				return draw(...)
			end

			-- lualine caches its highlight groups, so a new
			-- palette needs the whole config rebuilt. core/theme
			-- fires ColorScheme after every reload.
			vim.api.nvim_create_autocmd("ColorScheme", {
				desc = "Rebuild the statusline on a palette change",
				callback = setup,
			})
		end,
	},

	-- Dashboard --
	{
		"alpha-nvim",

		enabled = true,
		auto_enable = false,
		lazy = false,

		after = function()
			-- Skip the dashboard when opening a file
			if vim.fn.argc() > 0 or vim.fn.line2byte(vim.fn.line("$")) ~= -1 then
				return
			end

			local alpha = require("alpha")
			local dashboard = require("alpha.themes.dashboard")

			local function get_cow_header()
				local fallback_header = {
					"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⢠⢀⡐⢄⢢⡐⢢⢁⠂⠄⠠⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
					"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⠀⠀⠀⠀⡄⣌⠰⣘⣆⢧⡜⣮⣱⣎⠷⣌⡞⣌⡒⠤⣈⠠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
					"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠒⠊⠀⠀⠀⠀⢀⠢⠱⡜⣞⣳⠝⣘⣭⣼⣾⣷⣶⣶⣮⣬⣥⣙⠲⢡⢂⠡⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
					"⠀⠀⠀⠀⠀⠀⠀⠃⠀⠀⠀⠀⠀⠀⢀⠢⣑⢣⠝⣪⣵⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣯⣻⢦⣍⠢⢅⢂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
					"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⢆⡱⠌⣡⢞⣵⣿⣿⣿⠿⠛⠛⠉⠉⠛⠛⠿⢷⣽⣻⣦⣎⢳⣌⠆⡱⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
					"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠂⠠⠌⢢⢃⡾⣱⣿⢿⡾⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⢻⣏⠻⣷⣬⡳⣤⡂⠜⢠⡀⣀⠀⠀⡀⠀⠀⠀⠀⠀⠀",
					"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⢀⠂⣌⢃⡾⢡⣿⢣⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⡇⡊⣿⣿⣾⣽⣛⠶⣶⣬⣭⣥⣙⣚⢷⣶⠦⡤⢀",
					"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⢁⠂⠰⡌⡼⠡⣼⢃⡿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣾⡿⠿⣛⣯⡴⢏⠳⠁⠀",
					"⠀⠀⠀⠀⠀⠀⠀⠀⠠⠑⡌⠀⣉⣾⣩⣼⣿⣾⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣀⣠⣤⣤⣿⣿⣿⣿⡿⢛⣛⣯⣭⠶⣞⠻⣉⠒⠀⠂⠀⠀⠀",
					"⠀⠀⠀⠀⠀⠀⢀⣀⡶⢝⣢⣾⣿⣼⣿⣿⣿⣿⣿⣀⣼⣀⣀⣀⣤⣴⣶⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⣿⠿⡛⠏⠍⠂⠁⢠⠁⠀⠀⠀⠀⠀⠀⠀",
					"⠀⠠⢀⢥⣰⣾⣿⣯⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⣽⠟⣿⠐⠨⠑⡀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
					"⡐⢢⣟⣾⣿⣿⣟⣛⣿⣿⣿⣿⢿⣝⠻⠿⢿⣯⣛⢿⣿⣿⣿⡛⠻⠿⣛⠻⠛⡛⠩⢁⣴⡾⢃⣾⠇⢀⠡⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
					"⠈⠁⠊⠙⠉⠩⠌⠉⠢⠉⠐⠈⠂⠈⠁⠉⠂⠐⠉⣻⣷⣭⠛⠿⣶⣦⣤⣤⣴⣴⡾⠟⣫⣾⣿⡏⠀⠂⠐⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
					"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⢻⢿⢶⣤⣬⣉⣉⣭⣤⣴⣿⣿⡿⠃⠄⡈⠁⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
					"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠘⢊⠳⠭⡽⣿⠿⠿⠟⠛⠉⠀⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
					"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠀⠁⠈⠐⠀⠘⠀⠈⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
					"                         Neovim                       ",
					"                                                      ",
					"                       [airnvim]                      ",
				}

				-- Without fortune/cowsay use the static header
				if vim.fn.executable("fortune") == 0 or vim.fn.executable("cowsay") == 0 then
					return fallback_header
				end

				local safe_cows = {
					"default",
					"bud-frogs",
					"bunny",
					"cheese",
					"cower",
					"daemon",
					"dragon-and-cow",
					"elephant",
					"eyes",
					"flaming-sheep",
					"hellokitty",
					"kitty",
					"koala",
					"kosh",
					"milk",
					"moose",
					"pony",
					"ren",
					"sheep",
					"skeleton",
					"snowman",
					"stegosaurus",
					"stimpy",
					"supermilker",
					"three-eyes",
					"turkey",
					"turtle",
					"tux",
					"vader",
					"vader-koala",
					"www",
				}

				local status, output_str = pcall(function()
					math.randomseed(os.time())
					local random_cow = safe_cows[math.random(#safe_cows)]
					local cmd = string.format("fortune | cowsay -f %s -W 30 2>/dev/null", random_cow)
					local handle = io.popen(cmd)
					if not handle then
						return nil
					end
					local out = handle:read("*a")
					handle:close()
					return out
				end)

				if not status or not output_str or output_str == "" then
					return fallback_header
				end

				local lines = vim.split(output_str, "\n", { trimempty = true })

				if #lines == 0 then
					return fallback_header
				end

				return lines
			end

			local version = vim.version()
			local version_text = "v" .. version.major .. "." .. version.minor .. "." .. version.patch
			local version_widget = {
				type = "text",
				val = "Neovim " .. version_text,
				opts = {
					position = "center",
					hl = "Comment",
				},
			}

			local theme_colors = {
				"String",
				"Function",
				"Type",
				"Keyword",
				"Constant",
				"Number",
				"Identifier",
				"Statement",
				"Title",
				"Operator",
			}
			math.randomseed(os.time())
			local random_hl = theme_colors[math.random(#theme_colors)]

			dashboard.section.header.val = get_cow_header()
			dashboard.section.header.opts.hl = random_hl

			dashboard.section.buttons.val = {
				dashboard.button("n", "󰻭  New File", ":enew<CR>"),
				dashboard.button("f", "󰱽  Find File", ":Telescope find_files<CR>"),
				dashboard.button("g", "󰈭  Find Word", ":Telescope live_grep<CR>"),
				dashboard.button("r", "󰋚  Recent Files", ":Telescope oldfiles<CR>"),
				dashboard.button(
					"s",
					"󰢻  Settings",
					":Telescope find_files cwd=" .. require("core.paths").config() .. "<CR>"
				),
				dashboard.button("q", "➜  Quit", ":qa<CR>"),
			}

			local function footer()
				return "⚡ Neovim initialized"
			end
			dashboard.section.footer.val = footer()
			dashboard.section.footer.opts.hl = "Comment"

			dashboard.config.layout = {
				{ type = "padding", val = 2 },
				dashboard.section.header,
				{ type = "padding", val = 2 },
				dashboard.section.buttons,
				{ type = "padding", val = 1 },
				dashboard.section.footer,
				{ type = "padding", val = 1 },
				version_widget,
			}

			alpha.setup(dashboard.config)
		end,
	},

	-- Icons --
	{
		"nvim-web-devicons",

		enabled = require("core.setting").bool(true, "settings", "nerd_font", "enable"),
		auto_enable = true,
		lazy = true,

		dep_of = { "alpha-nvim", "oil.nvim", "telescope.nvim", "lualine.nvim", "render-markdown.nvim" },
	},

	-- LSP progress notifications --
	{
		"fidget.nvim",

		enabled = true,
		auto_enable = false,
		lazy = true,

		event = "LspAttach",

		after = function(plugin)
			require("fidget").setup(plugin.opts)
		end,
		opts = {
			notification = {
				window = {
					winblend = 0,
				},
			},
		},
	},

	-- Inline rendering of hex colours --
	{
		"nvim-colorizer.lua",

		enabled = true,
		auto_enable = false,
		lazy = true,

		-- On buffer read only: BufEnter was costing CPU
		event = { "BufReadPost" },

		after = function(plugin)
			require("colorizer").setup(plugin.opts)
		end,
		opts = {},
	},

	-- Highlighting for TODO/FIX/NOTE comments --
	{
		"todo-comments.nvim",

		enabled = true,
		auto_enable = false,
		lazy = true,

		event = "BufReadPost",

		after = function(plugin)
			require("todo-comments").setup(plugin.opts)
		end,
		opts = {
			colors = {
				error = { "DiagnosticError", "ErrorMsg", "#DC2626" },
				warning = { "DiagnosticWarn", "WarningMsg", "#FBBF24" },
				info = { "DiagnosticInfo", "#2563EB" },
				todo = { "DiagnosticInfo", "#2563EB" },
				hint = { "DiagnosticHint", "#10B981" },
				default = { "Identifier", "#7C3AED" },
				my_todo = { "#FF00FF" },
			},

			keywords = {
				FIX = { icon = "󰨰 ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
				TODO = { icon = "󰄴 ", color = "my_todo" },
				HACK = { icon = "󰈸 ", color = "warning" },
				WARN = { icon = "󰀪 ", color = "warning", alt = { "WARNING", "XXX" } },
				PERF = { icon = "󰓅 ", color = "default", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
				NOTE = { icon = "󰎛 ", color = "hint", alt = { "INFO" } },
				TEST = { icon = "⏲ ", color = "default", alt = { "TESTING", "PASSED", "FAILED" } },
			},
		},
	},
}
