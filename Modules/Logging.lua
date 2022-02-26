--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Log = AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @class Logging
local Logging = AddOn:NewModule("Logging")

local accum
if not AddOn._IsTestContext() then
    accum = {}
    Log:SetWriter(
        function(msg)
            Util.Tables.Push(accum, msg)
        end
    )
end

local LoggingLevels = {
    [Log:GetThreshold(Log.Level.Disabled)] = Log.Level.Disabled,
    [Log:GetThreshold(Log.Level.Fatal)]    = Log.Level.Fatal,
    [Log:GetThreshold(Log.Level.Error)]    = Log.Level.Error,
    [Log:GetThreshold(Log.Level.Warn)]     = Log.Level.Warn,
    [Log:GetThreshold(Log.Level.Info)]     = Log.Level.Info,
    [Log:GetThreshold(Log.Level.Debug)]    = Log.Level.Debug,
    [Log:GetThreshold(Log.Level.Trace)]    = Log.Level.Trace,
}

function Logging:OnInitialize()
    Log:Debug("OnInitialize(%s)", self:GetName())
end

function Logging:OnEnable()
    Log:Debug("OnEnable(%s)", self:GetName())

    self:BuildFrame()
    if not AddOn._IsTestContext() then
        self:SwitchDestination(accum)
        accum = nil
    end
    --@debug@
    self:Toggle()
    --@end-debug@
end

function Logging:EnableOnStartup()
    return true
end

function Logging.GetLoggingLevels()
    return Util.Tables.Copy(LoggingLevels)
end

function Logging:SetLoggingThreshold(threshold)
    AddOn:SetDbValue(AddOn.db.profile, {'logThreshold'}, threshold)
    Log:SetRootThreshold(threshold)
end