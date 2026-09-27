-- EXTERNAL TOOL INTEGRATIONS
--------------------------------------------------
-- These modules only register user commands and functions:
-- they cost nothing at startup and add no package to the
-- build. Any external program they call must be available
-- on the host PATH.

require("tools.open")
require("tools.lze")
require("tools.docs")
require("tools.markdown")
