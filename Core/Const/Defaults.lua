--- @type AddOn
local _, AddOn = ...
local Logging = LibStub("LibLogging-1.1")

-- The ['*'] key defines a default table for any key that was not explicitly defined in the defaults.
-- The second magic key is ['**']. It works similar to the ['*'] key, except that it'll also be inherited by all the keys in the same table.
AddOn.defaults = {
    global = {
      cache = {},
      versions = {},
    },
    profile = {
        logThreshold        = Logging.Level.Trace,

        minimap = {
            shown       = true,
            locked      = false,
            minimapPos  = 125,
        },

        -- user interface element positioning and scale
        ui = {
            ['**'] = {
                y           = 0,
                x		    = 0,
                point	    = "CENTER",
                scale	    = 1.0,
            },
        },
    }
}