--- @type AddOn
local _, AddOn = ...
local C = AddOn.Constants
--- @type LibLogging
local Logging = AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")

-- this is hooked primarily through the Module Prototype (SetDbValue) in Init.lua
-- but can be invoked directly as needed (for instance if you don't use the standard set definition
-- for an option)
function AddOn:ConfigChanged(moduleName, path, value)
	Logging:Debug("ConfigChanged(%s) : %s = %s", moduleName, Util.Objects.ToString(path), Util.Objects.ToString(value))
	-- need to serialize the values, as AceBucket (if used on other end) only groups by a single value
	self:SendMessage(C.Messages.ConfigChanged, AddOn:Serialize(moduleName, path, value))
end
