-- LSP
--------------------------------------------------
-- The specs below are not plugins: the first element is
-- the server name and the config lives in the `lsp` field.
-- Always on: nix, lua, markdown. The others are switched
-- on from module.nix (settings.langs.*).

return {
	{
		"nvim-lspconfig",
		enabled = true,
		auto_enable = true,
		lazy = false,

		lsp = function(plugin)
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
			if ok_cmp then
				capabilities = vim.tbl_deep_extend("force", capabilities, cmp_lsp.default_capabilities())
			end

			local config = vim.tbl_deep_extend("force", {
				capabilities = capabilities,
			}, plugin.lsp or {})

			vim.lsp.config(plugin.name, config)
			vim.lsp.enable(plugin.name)
		end,

		before = function()
			-- Diagnostic appearance --
			vim.diagnostic.config({
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = "󰅚 ",
						[vim.diagnostic.severity.WARN] = "󰀪 ",
						[vim.diagnostic.severity.HINT] = "󰠠 ",
						[vim.diagnostic.severity.INFO] = "󰋽 ",
					},
				},
				virtual_text = {
					prefix = "●",
				},
				float = {
					border = "rounded",
					source = true,
					header = "Diagnostic:",
					prefix = " ● ",
				},
				underline = true,
				update_in_insert = false,
				severity_sort = true,
			})

			-- Keymaps active only in buffers with an LSP --
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("airnvim-lsp-attach", { clear = true }),
				callback = function(event)
					local client = vim.lsp.get_client_by_id(event.data.client_id)
					local bufnr = event.buf

					local nmap = function(keys, func, desc)
						if desc then
							desc = "LSP: " .. desc
						end
						vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
					end

					nmap("gd", "<cmd>Telescope lsp_definitions<CR>", "[G]oto [D]efinition")
					nmap("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
					nmap("gr", "<cmd>Telescope lsp_references<CR>", "[G]oto [R]eferences")
					nmap("gI", "<cmd>Telescope lsp_implementations<CR>", "[G]oto [I]mplementation")
					nmap("<leader>D", "<cmd>Telescope lsp_type_definitions<CR>", "Type [D]efinition")
					nmap("<leader>ds", "<cmd>Telescope lsp_document_symbols<CR>", "[D]ocument [S]ymbols")
					nmap("<leader>ws", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", "[W]orkspace [S]ymbols")
					nmap("<leader>wa", vim.lsp.buf.add_workspace_folder, "[W]orkspace [A]dd Folder")
					nmap("<leader>wr", vim.lsp.buf.remove_workspace_folder, "[W]orkspace [R]emove Folder")
					nmap("<leader>e", vim.diagnostic.open_float, "Show diagnostic [E]rror")
					nmap("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
					-- NOTE: `<leader>ca` is owned by actions-preview.nvim
					nmap("K", vim.lsp.buf.hover, "Hover Documentation")
					nmap("<C-k>", vim.lsp.buf.signature_help, "Signature Documentation")

					nmap("<leader>wl", function()
						print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
					end, "[W]orkspace [L]ist Folders")

					-- Buffer-local :Format command
					vim.api.nvim_buf_create_user_command(bufnr, "Format", function(_)
						vim.lsp.buf.format()
					end, { desc = "Format current buffer with LSP" })

					-- Highlight other uses of the symbol under the cursor
					if client and client.server_capabilities.documentHighlightProvider then
						local highlight_augroup =
							vim.api.nvim_create_augroup("airnvim-lsp-highlight", { clear = false })
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = bufnr,
							group = highlight_augroup,
							callback = vim.lsp.buf.document_highlight,
						})
						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = bufnr,
							group = highlight_augroup,
							callback = vim.lsp.buf.clear_references,
						})
					end
				end,
			})
		end,
	},

	-- --- Nix ---
	{
		"nixd",
		ft = { "nix" },
		lsp = {
			root_markers = { "flake.nix", ".git" },
			settings = {
				nixd = {
					formatting = { command = { "nixfmt" } },
				},
				options = {},
			},
			on_init = function(client)
				local root = client.root_dir or vim.fn.getcwd()
				client.settings = vim.tbl_deep_extend("force", client.settings, {
					nixd = {
						nixpkgs = {
							expr = 'import (builtins.getFlake "' .. root .. '").inputs.nixpkgs { }',
						},
					},
				})
				client:notify("workspace/didChangeConfiguration", {
					settings = client.settings,
				})
			end,
		},
	},

	-- --- Lua ---
	{
		"lua_ls",
		ft = { "lua" },
		lsp = {
			settings = {
				Lua = {
					signatureHelp = { enabled = true },
					completion = { callSnippet = "Replace" },
					diagnostics = { globals = { "nixInfo", "vim" }, disable = { "missing-fields" } },
				},
			},
		},
	},

	-- --- Markdown: style rules (rumdl, written in rust) ---
	-- Replaces both markdownlint-cli2 and markdown-oxide.
	{
		"rumdl",
		ft = { "markdown" },
		lsp = {
			cmd = { "rumdl", "server" },
			filetypes = { "markdown" },
			root_markers = { ".rumdl.toml", "rumdl.toml", ".git" },
			-- The only way to apply the rules where no project
			-- configuration file exists
			settings = {
				rumdl = {
					configPath = require("core.rumdl").config_path(),
				},
			},
		},
	},

	-- --- Python (settings.langs.python.enable) ---
	{
		"ruff",
		enabled = vim.fn.executable("ruff") == 1,
		ft = { "python" },
		lsp = {
			cmd = { "ruff", "server" },
			filetypes = { "python" },
		},
	},

	-- --- Web (settings.langs.web.enable) ---
	{
		"ts_ls",
		enabled = vim.fn.executable("typescript-language-server") == 1,
		ft = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
		lsp = {},
	},
	{
		"html",
		enabled = vim.fn.executable("vscode-html-language-server") == 1,
		ft = { "html", "templ" },
		lsp = {
			cmd = { "vscode-html-language-server", "--stdio" },
			init_options = {
				configurationSection = { "html", "css", "javascript" },
				embeddedLanguages = { css = true, javascript = true },
				provideFormatter = true,
			},
		},
	},
}
