-- FORMAT ON SAVE
--------------------------------------------------

return {
	"conform.nvim",

	enabled = true,
	auto_enable = false,
	lazy = true,

	event = { "BufWritePre" },

	after = function(plugin)
		local opts = plugin.opts
		if type(opts) == "function" then
			opts = opts()
		end
		require("conform").setup(opts)
	end,

	opts = function()
		local by_ft = {
			markdown = { "rumdl" },
			lua = { "stylua" },
			sh = { "shfmt" },
			bash = { "shfmt" },
			python = { "ruff_format" },
		}

		-- Web formatting, only when settings.langs.web.formatter
		-- put biome on the PATH. It covers all of these on its
		-- own, so it replaces the LSP fallback on ts/js and html
		-- and is the only thing reaching css and json.
		if vim.fn.executable("biome") == 1 then
			for _, ft in ipairs({
				"javascript",
				"javascriptreact",
				"typescript",
				"typescriptreact",
				"json",
				"jsonc",
				"css",
				"html",
			}) do
				by_ft[ft] = { "biome" }
			end
		end

		return {
			formatters_by_ft = by_ft,
			formatters = {
				-- Biome ships its html formatter switched off and
				-- offers no way to enable it but a config file or
				-- this flag. It is inert for the other languages.
				biome = {
					append_args = { "--html-formatter-enabled=true" },
				},
				-- rumdl fixes style violations but does not rewrap
				-- text: `textwidth` + `gq` handle that.
				-- It reads stdin and writes diagnostics to stderr,
				-- so the buffer stays clean.
				rumdl = {
					command = "rumdl",
					args = function(_, ctx)
						local args = require("core.rumdl").args()
						vim.list_extend(args, {
							"fmt",
							"--stdin",
							"--stdin-filename",
							ctx.filename,
							"--quiet",
						})
						return args
					end,
					stdin = true,
				},
			},
			-- Markdown runs its own pipeline (core/rumdl.lua):
			-- rumdl does not rewrap text, so mdwrap sits between
			-- two rumdl passes. nil: nothing is left to conform.
			format_on_save = function(bufnr)
				if vim.bo[bufnr].filetype == "markdown" then
					require("core.rumdl").format(bufnr)
					return nil
				end
				return {
					timeout_ms = 3000,
					-- Nix keeps LSP-side formatting (nixfmt)
					lsp_format = "fallback",
				}
			end,
		}
	end,
}
