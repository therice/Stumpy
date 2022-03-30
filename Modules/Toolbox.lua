--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type Models.Totem.Totems
local Totems = AddOn.RequireOnUse('Models.Totem.Totems')
--- @type Models.Totem.TotemSet
local TotemSet = AddOn.Package('Models.Totem').TotemSet
--- @type Models.Totem.TotemSetDao
local TotemSetDao = AddOn.Package('Models.Totem').TotemSetDao
--- @type Models.Spell.Spells
local Spells = AddOn.RequireOnUse('Models.Spell.Spells')
--- @type Models.Dao
local Dao = AddOn.Package('Models').Dao
--- @type Core.Message
local Message = AddOn.RequireOnUse('Core.Message')
--- @type Core.Event
local Event = AddOn.RequireOnUse('Core.Event')

--- @class Toolbox
local Toolbox = AddOn:NewModule('Toolbox', "AceTimer-3.0", "AceHook-3.0", "AceEvent-3.0")

Toolbox.defaults = {
	profile = {
		-- these are settings for the main totem bar (always visible)
		toolbox = {
			size      = 50,
			spacing   = 3,
			grow      = C.Direction.Horizontal,
		},
		-- these are settings for the flyout bar (only visible when swapping totems)
		flyout = {
			size      = 35,
			spacing   = 5,
			layout    = C.Layout.Grid,
		},
		-- these are settings for the set bar (only visible when swapping sets)
		set = {
			size      = 35,
			spacing   = 5,
			layout    = C.Layout.Grid,
		},
		-- this is for the pulse timer and size is either width or height, based upon toolbox grow1
		pulse = {
			size    = 15
		},
		activeSet = TotemSet.Default.id,
		sets      = {

		},
	}
}

function Toolbox:OnInitialize()
	Logging:Debug("OnInitialize(%s)", self:GetName())
	self.db = AddOn.db:RegisterNamespace(self:GetName(), self.defaults)
	--- @type table<number, rx.Subscription>
	self.msgSubscriptions = nil
	--- @type table<number, rx.Subscription>
	self.evtSubscriptions = nil
	--- @type TotemBar
	self.totemBar = nil
	--- @type Models.Totem.TotemSetDao
	self.totemSets = TotemSetDao(self, self.db.profile.sets)
	--- @type Models.Totem.TotemSet
	self.totemSet = nil
	-- when an attempt is made to activate a totem set, but we're unable to (i.e. combat) keep
	-- a reference so it can be handled once combat is done
	--- @type Optional
	self.pendingTotemSet = Util.Optional.empty()
	-- queue of totem events that couldn't be processed as they arrived
	self.eventQueue = {
		events    = {},
		timer     = nil,
	}
end

function Toolbox:OnEnable()
	Logging:Debug("OnEnable(%s)", self:GetName())
	self:AddDefaultTotemSet()
	self:RegisterCallbacks()
end

function Toolbox:OnDisable()
	Logging:Debug("OnEnable(%s)", self:GetName())
	self:UnregisterCallbacks()
end

-- todo : upgrade from default spells to highest rank
function Toolbox:AddDefaultTotemSet()
	local default = self.totemSets:Get(TotemSet.Default.id)
	if Util.Objects.IsNil(default) then
		self.totemSets:Add(TotemSet.Default, false)
	end
end

function Toolbox:RegisterCallbacks()

	self.msgSubscriptions = Message():BulkSubscribe({
         [C.Messages.EnterCombat] = function(...) self:OnEnterCombat(...) end,
         [C.Messages.ExitCombat] = function(...) self:OnExitCombat(...) end,
         [C.Messages.ConfigChanged] = function(...)  self:OnConfigChanged(...) end,
     })

	self.evtSubscriptions = Event():BulkSubscribe({
		[C.Events.UpdateBindings] = function(...)  self:OnBindingsUpdated(...) end
	})

	Totems():RegisterCallbacks(self, {
		[Totems().Events.TotemUpdated] = function(...) self:OnTotemEvent(...) end
	})

	self.totemSets:RegisterCallbacks(self, {
		[Dao.Events.EntityUpdated] = function(...) self:OnTotemSetDaoEvent(...) end
	})
end

function Toolbox:UnregisterCallbacks()
	self.totemSets:UnregisterAllCallbacks(self)
	Totems():UnregisterAllCallbacks(self)
	AddOn.Unsubscribe(self.evtSubscriptions)
	self.evtSubscriptions = nil
	AddOn.Unsubscribe(self.msgSubscriptions)
	self.msgSubscriptions = nil
end

function Toolbox:EnableOnStartup()
	return true
end

function Toolbox:GetActiveTotemSetId()
	return Util.Objects.Default(self.db.profile.activeSet, TotemSet.Default.id)
end

--- @return Models.Totem.TotemSet
function Toolbox:GetTotemSet()
	if Util.Objects.IsNil(self.totemSet) then
		-- attempt to load totem set based upon active id
		self.totemSet = self.totemSets:Get(self:GetActiveTotemSetId())
		-- could not be found, just grab one
		if Util.Objects.IsNil(self.totemSet) then
			local sets = self.totemSet:GetAll()
			if not Util.Objects.IsNil(sets) and Util.Tables.Count(sets) > 0 then
				self.totemSet = Util.Tables.First(sets)
				self:SetActiveTotemSet(self.totemSet.id)
			end
		end

		if Util.Objects.IsNil(self.totemSet) then
			Logging:Warn("GetTotemSet() : Could not locate/load the active totem set")
		end
	end

	return self.totemSet
end

function Toolbox:SetActiveTotemSet(id, sendMessage)
	sendMessage = Util.Objects.Default(sendMessage, false)

	Logging:Debug("SetActiveTotemSet() : %s %s (sendMessage)", tostring(id), tostring(sendMessage))

	if not Util.Strings.IsSet(id) then
		Logging:Warn("Cannot activate totem set, as no id was provided")
		return
	end

	-- if we have an existing totem set, but the one we're activating is different, then nil it out
	if not Util.Objects.IsNil(self.totemSet) and not Util.Strings.Equal(self.totemSet.id, id) then
		Logging:Debug("SetActiveTotemSet() : new totem set activated, clearing reference")
		self.totemSet = nil
	end

	-- based upon whether we are in combat, either capture the id to activate OR
	-- clear it out
	if AddOn:InCombatLockdown() then
		self.pendingTotemSet = Util.Optional.of({id, sendMessage})
	else
		self.pendingTotemSet = Util.Optional.empty()
	end

	local _GenerateConfigChangedEvents = self.GenerateConfigChangedEvents
	Util.Functions.try(
		function()
			self.GenerateConfigChangedEvents = function() return sendMessage end
			self:SetDbValue(self.db.profile, 'activeSet', id)
		end
	).finally(
		function()
			if _GenerateConfigChangedEvents then
				self.GenerateConfigChangedEvents = _GenerateConfigChangedEvents
			end
		end
	)
end

function Toolbox:ShouldEnqueueEvent()
	-- need to enqueue events should
	-- (1) spells not yet be initialized OR
	-- (2) we already enqueued events and processing is pending
	local spellsReady = (Spells():IsEnabled() and Spells():IsLoaded())
	local eventsEnqueued = (not Util.Objects.IsNil(self.eventQueue.timer) and Util.Tables.Count(self.eventQueue.events) > 0)
	local enqueue = not spellsReady or eventsEnqueued
	Logging:Trace("ShouldEnqueueEvent(%s (spells), %s (events)) : %s", tostring(spellsReady), tostring(eventsEnqueued), tostring(enqueue))
	return enqueue
end

--- @param event string
--- @param totem Models.Totem.Totem
function Toolbox:EnqueueTotemEvent(event, totem)
	local queue = self.eventQueue
	Logging:Debug("EnqueueTotemEvent(%s) : %s, %s", tostring(event), tostring(totem), tostring(queue.timer))

	local function CancelTimer()
		if queue.timer then
			local cancelled = self:CancelTimer(queue.timer)
			Logging:Debug("EnqueueTotemEvent() : Cancelling timer (%s)", tostring(cancelled))
			queue.timer = nil
		end
	end

	--CancelTimer()
	Util.Tables.Push(queue.events, {event, totem})

	-- dumb dumb dumb, which is due to this being fired close to login and scheduler being borked
	-- otherwise would only need the call to ScheduleTimer()
	AddOn.Timer.After(0,
		function()
			CancelTimer()
			queue.timer = self:ScheduleTimer(function() self:ProcessTotemEvents() end, 2)
		end
	)
end

function Toolbox:ProcessTotemEvents()
	local queue = self.eventQueue
	Logging:Debug("ProcessTotemEvents(%d)", Util.Tables.Count(queue.events))

	local process = Util.Tables.Copy(queue.events)
	queue.events = {}
	queue.timer = nil

	for _, eventDetail in pairs(process) do
		self:OnTotemEvent(eventDetail[1], eventDetail[2])
	end
end

--- @param event string
--- @param totem Models.Totem.Totem
function Toolbox:OnTotemEvent(event, totem)
	local shouldEnqueue = self:ShouldEnqueueEvent()
	Logging:Debug("OnTotemEvent(%s) : %s, %s (enqueue)", event, Util.Objects.ToString(totem:toTable()), tostring(shouldEnqueue))

	if shouldEnqueue then
		self:EnqueueTotemEvent(event, totem)
		return
	end

	-- todo : InCombat and totemBar not yet created
	-- if the totem bar isn't visible, create and display
	if not self.totemBar then self:CreateTotemBar() end

	if Util.Objects.Equals(Totems().Events.TotemUpdated, event) then
		self.totemBar:UpdateButton(totem)
	end
end

function Toolbox:OnTotemSetDaoEvent(event, eventDetail)
	Logging:Debug("OnTotemSetDaoEvent(%s) : %s", event, Util.Objects.ToString(eventDetail))

	-- don't care about event if the totem bar isn't visible
	if not self.totemBar then return end

	-- there may be extra detail on the event which designates what totem bar button to update
	local extra = unpack(eventDetail.extra)
	if Util.Objects.IsTable(extra) and Util.Objects.IsNumber(extra.element) and Util.Objects.IsSet(extra.spell) then
		self.totemBar:OnSpellSelected(extra.element, extra.spell)
	-- emulated DOA event via OnConfigChanged(), only as a result of active set id being changed
	elseif Util.Objects.IsTable(extra) and Util.Objects.IsString(extra.setId) then
		self.totemBar:OnSetActivated(extra.setId)
	else
		Logging:Warn("OnTotemSetDaoEvent() : NOT IMPLEMENTED")
	end
end

function Toolbox:OnConfigChanged(_, message)
	Logging:Debug("OnConfigChanged() : %s", Util.Objects.ToString(message))
	local success, module, path, value = AddOn:Deserialize(message)
	if success and Util.Strings.Equal(self:GetName(), module) then
		Logging:Debug("OnConfigChanged() : %s = %s", Util.Objects.ToString(path), Util.Objects.ToString(value))
		-- todo : validate any other paths which would generate this to make sure properly handled
		-- the active totem set has changed
		if Util.Strings.Equal(path, "activeSet") then
			-- this is a simulated event, where we specify the set id which was activated
			self:OnTotemSetDaoEvent(Dao.Events.EntityUpdated, { extra = {{setId = value}} })
		end
	end

end

function Toolbox:OnEnterCombat()
	Logging:Debug("OnEnterCombat()")
	-- don't care about event if the totem bar isn't visible
	if not self.totemBar then return end
end

function Toolbox:OnExitCombat()
	Logging:Debug("OnExitCombat()")
	-- don't care about event if the totem bar isn't visible
	if not self.totemBar then return end

	if self.pendingTotemSet:isPresent() then
		local id, sendMessage = unpack(self.pendingTotemSet:get())
		self:SetActiveTotemSet(id, sendMessage)
	end

	for _, button in pairs(self.totemBar:GetButtons()) do
		if button:HasPendingChange() then
			if not button:IsPresent() then
				button:Update()
			end
		end
	end
end

function Toolbox:GetSpellsByTotem(element)
	return Spells():GetHighestRanksByTotemElement(element)
end

function Toolbox:GetBarButtonSize()
	return Util.Objects.Default(self.db.profile.toolbox.size, 50)
end

function Toolbox:GetBarButtonSpacing()
	return Util.Objects.Default(self.db.profile.toolbox.spacing, 8)
end

function Toolbox:GetBarGrow()
	return Util.Objects.Default(self.db.profile.toolbox.grow, C.Direction.Horizontal)
end

function Toolbox:GetBarSettings()
	return self:GetBarButtonSize(), self:GetBarButtonSpacing(), self:GetBarGrow()
end

function Toolbox:GetFlyoutButtonSize()
	return Util.Objects.Default(self.db.profile.flyout.size, 35)
end

function Toolbox:GetFlyoutButtonSpacing()
	return Util.Objects.Default(self.db.profile.flyout.spacing, 5)
end

function Toolbox:GetFlyoutLayout()
	return Util.Objects.Default(self.db.profile.flyout.layout, C.Layout.Grid)
end

function Toolbox:GetFlyoutSettings()
	return self:GetFlyoutButtonSize(), self:GetFlyoutButtonSpacing(), self:GetFlyoutLayout()
end

function Toolbox:GetSetButtonSize()
	return Util.Objects.Default(self.db.profile.set.size, 35)
end

function Toolbox:GetSetButtonSpacing()
	return Util.Objects.Default(self.db.profile.set.spacing, 5)
end

function Toolbox:GetSetLayout()
	return Util.Objects.Default(self.db.profile.set.layout, C.Layout.Grid)
end

function Toolbox:GetSetSettings()
	return self:GetSetButtonSize(), self:GetSetButtonSpacing(), self:GetSetLayout()
end

function Toolbox:GetPulseSize()
	return Util.Objects.Default(self.db.profile.pulse.size, 15)
end

function Toolbox:GetElementIndex(element)
	local index = element
	local set = self:GetTotemSet()
	if set then
		index, _ = set:Get(element)
	end
	return Util.Objects.Default(index, 0) > 0 and index or element
end

function Toolbox:SetElementIndices()
	if self.totemBar then
		local ordering =
			Util(self.totemBar:GetButtons())
				:Copy(function(button) return button:GetFrame():GetID() end)()

		local set = self:GetTotemSet()
		for order, element in pairs(ordering) do
			set:SetOrder(element, order)
		end

		Logging:Trace("SetElementIndices() : %s", Util.Objects.ToString(set:toTable()))
		self.totemSets:Update(set, 'totems', false)
	end
end

function Toolbox:SetElementSpell(element, spell)
	if Util.Objects.IsNumber(element) and not Util.Objects.IsNil(spell) then
		local set = self:GetTotemSet()
		local _, currentSpell = set:Get(element)

		if not Util.Objects.Equals(spell.id, currentSpell.id) then
			set:SetSpell(element, spell.id)
			Logging:Trace("SetElementSpell() : %s", Util.Objects.ToString(set:toTable()))
			self.totemSets:Update(set, 'totems', true, {element = element, spell = spell})
		end
	end
end

--[[
function Toolbox:CastByElement(element)
	element = tonumber(Util.Objects.Default(element, "0"))
	Logging:Trace("CastByElement(%s)", element)
	if self.totemBar and (element > 0 and element < C.MaxTotems) then
		local macro = self.totemBar:GetMacro(element)
		Logging:Trace("CastByElement(%s): %s", element, Util.Objects.ToString(macro))
		macro:Click("LeftButton", false)
	end
end
--]]