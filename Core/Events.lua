--- @type  AddOn
local _, AddOn = ...
local L, C  = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util =  AddOn:GetLibrary("Util")
--- @type Core.Event
local Event = AddOn.Require('Core.Event')
--- @type Models.Spell.Spells
local Spells = AddOn.RequireOnUse('Models.Spell.Spells')
--- @type Models.Totem.Totems
local Totems = AddOn.RequireOnUse('Models.Totem.Totems')

function AddOn:SubscribeToEvents()
	Logging:Debug("SubscribeToEvents(%s)", self:GetName())
	if Util.Tables.Count(self.Events) > 0 then
		local events = {}
		for event, method in pairs(self.Events) do
			Logging:Trace("SubscribeToEvents(%s) : %s", self:GetName(), event)
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
function AddOn:PlayerEnteringWorld(_, isLogin, isReload)
	Logging:Debug(
		"PlayerEnteringWorld(%s) : isLogin=%s, isReload=%s, initialLoad=%s",
		 tostring(nil), tostring(isLogin), tostring(isReload), tostring(initialLoad)
	)
	-- if we have not yet handled the initial entering world event
	if initialLoad then
		initialLoad = false
		Totems():Initialize()
	end
end

function AddOn:SpellsChanged()
	Logging:Debug("SpellsChanged()")
	Spells():Refresh()
end