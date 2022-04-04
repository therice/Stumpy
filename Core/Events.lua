--- @type  AddOn
local _, AddOn = ...
local L, C  = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util =  AddOn:GetLibrary("Util")
--- @type Core.Event
local Event = AddOn.Require('Core.Event')

function AddOn:SubscribeToEvents()
	Logging:Debug("SubscribeToEvents(%s)", self:GetName())
	if Util.Tables.Count(self.Events) > 0 then
		local events = {}
		for event, method in pairs(self.Events) do
			Logging:Debug("SubscribeToEvents(%s) : %s", self:GetName(), event)
			events[event] = function(evt, ...) self[method](self, evt, ...) end
		end
		self.eventSubscriptions = Event:BulkSubscribe(events)
	end
end

function AddOn:UnsubscribeFromEvents()
	Logging:Debug("UnsubscribeFromEvents(%s)", self:GetName())
	if self.eventSubscriptions then
		for _, subscription in pairs(self.eventSubscriptions) do
			subscription:unsubscribe()
		end
		self.eventSubscriptions = nil
	end
end

-- track whether initial load of addon or has it been reloaded (either via login or explicit reload)
local initialLoad = true

-- this event is triggered when the player logs in, /reloads the UI, or zones between map instances
-- basically whenever the loading screen appears
--
-- initial login = true, false
-- reload ui = false, true
-- instance zone event = false, false
function AddOn:OnPlayerEnteringWorld(_, isLogin, isReload)
	Logging:Debug(
		"OnPlayerEnteringWorld(%s) : isLogin=%s, isReload=%s, initialLoad=%s",
		 tostring(nil), tostring(isLogin), tostring(isReload), tostring(initialLoad)
	)
	-- if we have not yet handled the initial entering world event
	if initialLoad then
		initialLoad = false
	end
end

-- for events that invoke OnEnterCombat and OnExitCombat, we do a one time subscription and then
-- dispatch via messages. this allows for emulation outside of combat for testing/development purposes

function AddOn:OnEnterCombat(...)
	Logging:Debug("OnEnterCombat() : %s", Util.Objects.ToString({...}))
	self:SendMessage(C.Messages.EnterCombat, ...)
end

function AddOn:OnExitCombat(...)
	Logging:Debug("OnExitCombat() : %s", Util.Objects.ToString({...}))
	self:SendMessage(C.Messages.ExitCombat, ...)
end

function AddOn:OnUpdateMacros(...)
	Logging:Debug("OnUpdateMacros() : %s", Util.Objects.ToString({...}))
	self:MacroMediator():Update()
end