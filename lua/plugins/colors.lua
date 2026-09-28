-- COLORSCHEME
--------------------------------------------------
-- The one plugin with no lazy trigger: it has to be in place
-- before the first buffer is drawn, or the editor flashes the
-- default theme. `priority` puts it ahead of the other
-- startup plugins (lze defaults to 50).
--
-- Nothing is configured here. lua/core/theme.lua feeds it the
-- palette, and init.lua requires that last, once this has
-- loaded.

return {
	{
		"base16-nvim",

		enabled = true,
		auto_enable = true,
		lazy = false,

		priority = 1000,
	},

	-- Reader themes --
	-- Gruvbox for `:ReaderLight` / `:ReaderDark`. No trigger
	-- of its own: lua/core/reader.lua loads it with
	-- trigger_load on the first call.
	{
		"gruvbox.nvim",

		enabled = true,
		auto_enable = false,
		lazy = true,

		after = function(plugin)
			require("gruvbox").setup(plugin.opts)
		end,

		opts = {
			contrast = "",
			-- Opaque on purpose: a cream page over a dark
			-- terminal would be unreadable
			transparent_mode = false,
		},
	},
}
