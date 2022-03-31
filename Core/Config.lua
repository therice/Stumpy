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

-- these will be applied to the generic 'configuration' layout
function AddOn:GetConfigSupplement(module)
	if module['ConfigSupplement'] then
		local cname, fn = module:ConfigSupplement()
		if Util.Strings.IsSet(cname) and Util.Objects.IsFunction(fn) then
			Logging:Trace("GetConfigSupplement() : module '%s' has a configuration supplement named '%s'", module:GetName(), cname)
			return cname, fn
		end
	end

	Logging:Trace("GetConfigSupplement() : module '%s' has no associated configuration supplement", module:GetName())
	return nil, nil
end

-- these will be applied as a new section in the layout
function AddOn:GeLaunchpadSupplements(module)
	local all = {}

	if module['LaunchpadSupplements'] then
		local supplements = module:LaunchpadSupplements()
		for _, supplement in pairs(supplements) do
			local mname, fn, enableDisableSupport = unpack(supplement)
			if Util.Strings.IsSet(mname) and Util.Objects.IsFunction(fn) then
				Logging:Trace("GeLaunchpadSupplement() : module '%s' has a launchpad supplement named '%s'", module:GetName(), mname)
				all[mname] = {module, fn, enableDisableSupport}
			end
		end
	end

	Logging:Trace("GetConfigSupplement() : module '%s' has no associated launchpad supplement", module:GetName())
	return all
end

