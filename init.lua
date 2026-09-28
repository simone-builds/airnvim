-- BOOTSTRAP
--------------------------------------------------
-- Order: nix bridge -> lze handlers -> base config ->
-- plugin specs -> theme.

vim.loader.enable()

-- Bridge between Lua and the Nix wrapper info --
do
	local ok
	ok, _G.nixInfo = pcall(require, vim.g.nix_info_plugin_name)
	if not ok then
		-- Outside the wrapper: a stub always returning the default
		package.loaded[vim.g.nix_info_plugin_name] = setmetatable({}, {
			__call = function(_, default)
				return default
			end,
		})
		_G.nixInfo = require(vim.g.nix_info_plugin_name)
	end
	nixInfo.isNix = vim.g.nix_info_plugin_name ~= nil
	nixInfo.lze = setmetatable(require("lze"), getmetatable(require("lzextras")))
	function nixInfo.get_nix_plugin_path(name)
		return nixInfo(nil, "plugins", "lazy", name) or nixInfo(nil, "plugins", "start", name)
	end
end

-- LZE HANDLERS
--------------------------------------------------
nixInfo.lze.register_handlers({
	-- Enable the spec only if Nix actually built the plugin --
	{
		spec_field = "auto_enable",
		set_lazy = false,
		modify = function(plugin)
			if vim.g.nix_info_plugin_name then
				if type(plugin.auto_enable) == "table" then
					for _, name in pairs(plugin.auto_enable) do
						if not nixInfo.get_nix_plugin_path(name) then
							plugin.enabled = false
							break
						end
					end
				elseif type(plugin.auto_enable) == "string" then
					if not nixInfo.get_nix_plugin_path(plugin.auto_enable) then
						plugin.enabled = false
					end
				elseif type(plugin.auto_enable) == "boolean" and plugin.auto_enable then
					if not nixInfo.get_nix_plugin_path(plugin.name) then
						plugin.enabled = false
					end
				end
			end
			return plugin
		end,
	},
	-- Enable the spec based on settings.cats.<name> --
	{
		spec_field = "for_cat",
		set_lazy = false,
		modify = function(plugin)
			if vim.g.nix_info_plugin_name then
				if type(plugin.for_cat) == "string" then
					plugin.enabled = nixInfo(false, "settings", "cats", plugin.for_cat)
				end
			end
			return plugin
		end,
	},
	nixInfo.lze.lsp,
})

-- Fallback filetypes for LSP servers --
nixInfo.lze.h.lsp.set_ft_fallback(function(name)
	local lspcfg = nixInfo.get_nix_plugin_path("nvim-lspconfig")
	if lspcfg then
		local ok, cfg = pcall(dofile, lspcfg .. "/lsp/" .. name .. ".lua")
		return (ok and cfg or {}).filetypes or {}
	else
		return (vim.lsp.config[name] or {}).filetypes or {}
	end
end)

-- BASE CONFIGURATION
--------------------------------------------------
require("core.options")
require("core.keymaps")
require("core.autocmds")
require("tools")

-- PLUGIN SPECS
--------------------------------------------------
local mod_dir_to_spec = require("lzextras").mod_dir_to_spec

local raw_specs = mod_dir_to_spec("plugins")

-- Flatten files that return a list of specs --
local specs = {}
for _, file_specs in ipairs(raw_specs) do
	if file_specs[1] and type(file_specs[1]) == "table" then
		for _, spec in ipairs(file_specs) do
			table.insert(specs, spec)
		end
	else
		table.insert(specs, file_specs)
	end
end

nixInfo.lze.load(specs)

-- Last: base16-nvim has to be loaded before the palette can
-- be handed to it.
require("core.theme")
require("core.reader")
