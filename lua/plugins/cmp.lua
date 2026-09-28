-- COMPLETION
--------------------------------------------------

return {
	{
		"nvim-cmp",

		enabled = true,
		auto_enable = false,
		lazy = false,

		after = function()
			local cmp = require("cmp")
			local luasnip = require("luasnip")
			luasnip.config.setup({})

			-- Load vscode-format snippets (friendly-snippets)
			pcall(function()
				require("luasnip.loaders.from_vscode").lazy_load()
			end)

			-- Nerd Font `nf-md` glyphs only (U+F0000 and up): the
			-- ones below U+F8FF were lost once in a copy, as spaces
			local kind_icons = {
				Text = "󰦨",
				Method = "󰆧",
				Function = "󰊕",
				Constructor = "󱁤",
				Field = "󰇽",
				Variable = "󰂡",
				Class = "󰠱",
				Interface = "󰠲",
				Module = "󰏗",
				Property = "󰜢",
				Unit = "󰑭",
				Value = "󰎠",
				Enum = "󰉺",
				Keyword = "󰌋",
				Snippet = "󰆐",
				Color = "󰏘",
				File = "󰈙",
				Reference = "󰈇",
				Folder = "󰉋",
				EnumMember = "󰉻",
				Constant = "󰏿",
				Struct = "󰙅",
				Event = "󱐋",
				Operator = "󰆕",
				TypeParameter = "󰅲",
			}

			local format_func = function(entry, vim_item)
				if kind_icons[vim_item.kind] then
					vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind], vim_item.kind)
				end

				vim_item.menu = ({
					nvim_lsp = "[LSP]",
					luasnip = "[Snip]",
					buffer = "[Buf]",
					path = "[Path]",
					cmdline = "",
				})[entry.source.name]

				if entry.source.name == "cmdline" or entry.source.name == "path" then
					vim_item.kind = ""
				end

				return vim_item
			end

			local function get_mappings()
				return {
					["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
					["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
					["<C-u>"] = cmp.mapping.scroll_docs(-4),
					["<C-d>"] = cmp.mapping.scroll_docs(4),
					["<C-y>"] = cmp.mapping.confirm({ select = true }),
					["<CR>"] = cmp.mapping.confirm({ select = false }),
					["<C-e>"] = cmp.mapping.abort(),
					["<C-Space>"] = cmp.mapping.complete({}),
				}
			end

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				window = {
					completion = {
						border = "rounded",
						scrollbar = true,
						winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None",
					},
					documentation = {
						border = "rounded",
						winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None",
					},
				},
				mapping = cmp.mapping.preset.insert(get_mappings()),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "render-markdown" },
					{ name = "path" },
				}, {
					{ name = "buffer", keyword_length = 5 },
				}),
				formatting = {
					fields = { "kind", "abbr", "menu" },
					format = format_func,
				},
			})

			cmp.setup.cmdline({ "/", "?" }, {
				mapping = cmp.mapping.preset.cmdline(get_mappings()),
				sources = { { name = "buffer" } },
				formatting = {
					fields = { "abbr" },
				},
			})

			cmp.setup.cmdline(":", {
				mapping = cmp.mapping.preset.cmdline(get_mappings()),
				sources = cmp.config.sources({
					{ name = "path" },
				}, {
					{ name = "cmdline" },
				}),
				formatting = {
					fields = { "abbr", "kind" },
					format = format_func,
				},
				matching = { disallow_symbol_nonprefix_matching = false },
			})
		end,
	},
	{
		"luasnip",
		enabled = true,
		auto_enable = true,
		lazy = true,
		dep_of = { "nvim-cmp" },
	},
	{
		"friendly-snippets",
		enabled = true,
		auto_enable = true,
		lazy = true,
		dep_of = { "luasnip" },
	},
	{
		"cmp_luasnip",
		enabled = true,
		auto_enable = true,
		lazy = true,
		dep_of = { "nvim-cmp" },
	},
	{
		"cmp-nvim-lsp",
		enabled = true,
		auto_enable = true,
		lazy = true,
		dep_of = { "nvim-cmp", "nvim-lspconfig" },
	},
	{
		"cmp-path",
		enabled = true,
		auto_enable = true,
		lazy = true,
		dep_of = { "nvim-cmp" },
	},
	{
		"cmp-buffer",
		enabled = true,
		auto_enable = true,
		lazy = true,
		dep_of = { "nvim-cmp" },
	},
	{
		"cmp-cmdline",
		enabled = true,
		auto_enable = true,
		lazy = true,
		dep_of = { "nvim-cmp" },
	},
}
