-- LOWERCASE COMMAND ALIASES
--------------------------------------------------
-- User commands must start with a capital (E183), so
-- `:mdguide` cannot be defined as one. A cmdline abbreviation
-- rewrites the word into the real command instead.
--
-- The guard matters: without it the word would expand
-- anywhere on the command line, including inside `:s//`
-- patterns and command arguments. It is checked when the
-- word is complete, so `:previewmd stop` expands as well.

local M = {}

function M.set(lhs, cmd)
	vim.cmd(
		("cnoreabbrev <expr> %s (getcmdtype() ==# ':' && getcmdline() ==# %q) ? %q : %q"):format(lhs, lhs, cmd, lhs)
	)
end

return M
