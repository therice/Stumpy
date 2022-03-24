--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type Core.Message
local Message = AddOn.RequireOnUse('Core.Message')
--- @type Models.Macros.Macros
local Macros = AddOn.Require('Models.Macros.Macros')
--- @type Models.Dao
local Dao = AddOn.Package('Models').Dao

--- @class MacroMediator
local MacroMediator = AddOn:NewModule('MacroMediator', "AceTimer-3.0", "AceHook-3.0", "AceEvent-3.0")

function MacroMediator:OnInitialize()
	Logging:Debug("OnInitialize(%s)", self:GetName())
	--- @type table<number, rx.Subscription>
	self.subscriptions = nil
	--- @type boolean
	self.updatePending = false
	--- @type boolean
	self.updateInFlight = false
end

function MacroMediator:OnEnable()
	Logging:Debug("OnEnable(%s)", self:GetName())
	self:RegisterCallbacks()
end

function MacroMediator:OnDisable()
	Logging:Debug("OnEnable(%s)", self:GetName())
	self:UnregisterCallbacks()
end

function MacroMediator:EnableOnStartup()
	return true
end

function MacroMediator:RegisterCallbacks()
	self.subscriptions = Message():BulkSubscribe({
		[C.Messages.ExitCombat] = function(...) self:OnExitCombat(...) end,
		[C.Messages.ConfigChanged] = function(...)  self:OnConfigChanged(...) end,
	})

	AddOn:Toolbox().totemSets:RegisterCallbacks(self, {
		[Dao.Events.EntityUpdated] = function(...) self:OnTotemSetDaoEvent(...) end
	})
end

function MacroMediator:UnregisterCallbacks()
	AddOn:Toolbox().totemSets:UnregisterAllCallbacks(self)
	AddOn.Unsubscribe(self.subscriptions)
	self.subscriptions = nil
end

function MacroMediator:OnExitCombat()
	Logging:Debug("OnExitCombat")
	if self.updatePending then
		self:Update()
	end
end

function MacroMediator:OnConfigChanged(_, message)
	Logging:Debug("OnConfigChanged() : %s", Util.Objects.ToString(message))
	local success, module, path, _ = AddOn:Deserialize(message)
	if success and Util.Strings.Equal(AddOn:Toolbox():GetName(), module) then
		if Util.Strings.Equal(path, "activeSet") then
			self:Update()
		end
	end
end

function MacroMediator:OnTotemSetDaoEvent(event, eventDetail)
	Logging:Debug("OnTotemSetDaoEvent(%s) : %s", event, Util.Objects.ToString(eventDetail))
	self:Update()
end

function MacroMediator:Update()
	Logging:Debug("Update()")

	if AddOn:InCombatLockdown() then
		self.updatePending = true
		return
	end

	if self.updateInFlight then
		return
	end

	Util.Functions.try(
		function()
			self.updateInFlight = true
			Macros:LoadAndParse()
		end
	).finally(
		function()
			self.updateInFlight = false
			self.updatePending = false
		end
	)

end

