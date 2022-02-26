local AceAddon, AceAddonMinor = LibStub('AceAddon-3.0')
local AddOnName, AddOn = ...

--- @class AddOn
AddOn = AceAddon:NewAddon(AddOn, AddOnName, 'AceConsole-3.0', 'AceEvent-3.0', "AceSerializer-3.0", "AceHook-3.0", "AceTimer-3.0", "AceBucket-3.0")
AddOn:SetDefaultModuleState(false)
_G[AddOnName] = AddOn

-- just capture version here, it will be turned into semantic version later
-- as we don't have access to that model yet here
AddOn.version = GetAddOnMetadata(AddOnName, "Version")
AddOn.author = GetAddOnMetadata(AddOnName, "Author")

--@debug@
-- if local development and not substituted, then use a dummy version
if AddOn.version == '@project-version@' then
    AddOn.version = '2022.0.0-dev'
end
--@end-debug@

AddOn.Timer = C_Timer

do
    AddOn:AddLibrary('CallbackHandler', 'CallbackHandler-1.0')
    AddOn:AddLibrary('Class', 'LibClass-1.0')
    AddOn:AddLibrary('Logging', 'LibLogging-1.1')
    AddOn:AddLibrary('Util', 'LibUtil-1.1')
    AddOn:AddLibrary('Deflate', 'LibDeflate')
    AddOn:AddLibrary('Base64', 'LibBase64-1.0')
    AddOn:AddLibrary('Rx', 'LibRx-1.1')
    AddOn:AddLibrary('MessagePack', 'LibMessagePack-1.0')
    AddOn:AddLibrary('AceAddon', AceAddon, AceAddonMinor)
    AddOn:AddLibrary('AceEvent', 'AceEvent-3.0')
    AddOn:AddLibrary('AceTimer', 'AceTimer-3.0')
    AddOn:AddLibrary('AceHook', 'AceHook-3.0')
    AddOn:AddLibrary('AceLocale', 'AceLocale-3.0')
    AddOn:AddLibrary('AceConsole', 'AceConsole-3.0')
    AddOn:AddLibrary('AceComm', 'AceComm-3.0')
    AddOn:AddLibrary('AceSerializer', 'AceSerializer-3.0')
    AddOn:AddLibrary('AceGUI', 'AceGUI-3.0')
    AddOn:AddLibrary('AceDB', 'AceDB-3.0')
    AddOn:AddLibrary('AceBucket', 'AceBucket-3.0')
    AddOn:AddLibrary('AceConfig', 'AceConfig-3.0')
    AddOn:AddLibrary('AceConfigCmd', 'AceConfigCmd-3.0')
    AddOn:AddLibrary('AceConfigDialog', 'AceConfigDialog-3.0')
    AddOn:AddLibrary('AceConfigRegistry', 'AceConfigRegistry-3.0')
    AddOn:AddLibrary('Window', 'LibWindow-1.1')
    AddOn:AddLibrary('DataBroker', 'LibDataBroker-1.1')
    AddOn:AddLibrary('DbIcon', 'LibDBIcon-1.0')
    AddOn:AddLibrary('JSON', 'LibJSON-1.0')
    AddOn:AddLibrary('SpellRange', 'SpellRange-1.0')
    AddOn:AddLibrary('RangeCheck', 'LibRangeCheck-2.0')
end

AddOn.Locale = AddOn:GetLibrary("AceLocale"):GetLocale(AddOn.Constants.name)

--- @type LibLogging
local Logging = AddOn:GetLibrary("Logging")
---@type LibUtil
local Util = AddOn:GetLibrary("Util")

--@debug@
Logging:SetRootThreshold(AddOn._IsTestContext() and Logging.Level.Trace or Logging.Level.Debug)
--@end-debug@

local function GetDbValue(self, db, i, ...)
    local path = Util.Objects.IsTable(i) and tostring(i[#i]) or Util.Strings.Join('.', i, ...)
    Logging:Trace("GetDbValue(%s, %s, %s)", self:GetName(), tostring(db), path)
    return Util.Tables.Get(db, path)
end

local function SetDbValue(self, db, i, v)
    local path = Util.Objects.IsTable(i) and tostring(i[#i]) or i
    Logging:Trace("SetDbValue(%s, %s, %s, %s)", self:GetName(), tostring(db), tostring(path), Util.Objects.ToString(v))
    Util.Tables.Set(db, path, v)
    if self['GenerateConfigChangedEvents'] and self:GenerateConfigChangedEvents() then
        AddOn:ConfigChanged(self:GetName(), path)
    end
end

AddOn.GetDbValue = GetDbValue
AddOn.SetDbValue = SetDbValue

local ModulePrototype = {
    IsDisabled = function (self, _)
        Logging:Trace("Module:IsDisabled(%s) : %s", self:GetName(), tostring(not self:IsEnabled()))
        return not self:IsEnabled()
    end,
    SetEnabled = function (self, _, v)
        if v then
            Logging:Trace("Module:SetEnabled(%s) : Enabling module", self:GetName())
            self:Enable()
        else
            Logging:Trace("Module:SetEnabled(%s) : Disabling module ", self:GetName())
            self:Disable()
        end
        self.db.profile.enabled = v
        Logging:Trace("Module:SetEnabled(%s) : %s", self:GetName(), tostring(self.db.profile.enabled))
    end,
    GetDbValue = function(self, db, ...)
        if not Util.Objects.IsTable(db) then
            return GetDbValue(self, self.db.profile, db, ...)
        else
            return GetDbValue(self, db, ...)
        end
    end,
    SetDbValue = function(self, db, ...)
        if not Util.Objects.IsTable(db) then
            SetDbValue(self, self.db.profile, db, ...)
        else
            SetDbValue(self, db, ...)
        end
    end,
    GenerateConfigChangedEvents = function(self)
        return false
    end,
    -- will provide the default value used for bootstrapping a module's db
    -- will only return a value if the module has a 'Defaults' attribute
    GetDefaultDbValue = function(self, ...)
        if self.defaults then
            return Util.Tables.Get(self.defaults, Util.Strings.Join('.', ...))
        end
        return nil
    end,
    -- specifies if module should be enabled on startup
    EnableOnStartup = function (self)
        local enable = (self.db and ((self.db.profile and self.db.profile.enabled) or self.db.enabled)) or false
        Logging:Debug("EnableOnStartup(%s) : %s", self:GetName(), tostring(enable))
        return enable
    end,
}

AddOn:SetDefaultModulePrototype(ModulePrototype)

-- stuff below here is strictly for use during tests of addon
-- not to be confused with addon test mode
--@debug@
local function _testNs(name) return  Util.Strings.Join('_', name, 'Testing')  end
local AddOnTestNs = _testNs(AddOnName)
function AddOn._IsTestContext(name)
    if _G[AddOnTestNs] then
        return true
    end
    if Util.Strings.IsSet(name) then
        if _G[_testNs(name)] then
            return true
        end
    end

    return false
end
--@end-debug@