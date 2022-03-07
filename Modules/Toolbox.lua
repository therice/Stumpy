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

--- @class Toolbox
local Toolbox = AddOn:NewModule('Toolbox', "AceTimer-3.0", "AceHook-3.0")

Toolbox.defaults = {
	profile = {
		-- these are settings for the main totem bar (always visible)
		toolbox = {
			size      = 50,
			spacing   = 8,
			grow      = C.Direction.Horizontal,
		},
		-- these are settings for the flyout bar (only visible when swapping totems)
		flyout = {
			size      = 35,
			spacing   = 5,
			layout    = C.Layout.Grid,
		},
		activeSet = TotemSet.Default.id,
		sets      = {

		},
	}
}

function Toolbox:OnInitialize()
	Logging:Debug("OnInitialize(%s)", self:GetName())
	self.db = AddOn.db:RegisterNamespace(self:GetName(), self.defaults)
	--- @type TotemBar
	self.totemBar = nil
	--- @type Models.Totem.TotemSetDao
	self.totemSets = TotemSetDao(self, self.db.profile.sets)
	--- @type Models.Totem.TotemSet
	self.totemSet = nil
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

function Toolbox:AddDefaultTotemSet()
	local default = self.totemSets:Get(TotemSet.Default.id)
	if Util.Objects.IsNil(default) then
		self.totemSets:Add(TotemSet.Default, false)
	end
end

function Toolbox:RegisterCallbacks()
	Totems():RegisterCallbacks(self, {
		[Totems().Events.TotemUpdated] = function(...) self:TotemUpdated(...) end
	})

	self.totemSets:RegisterCallbacks(self, {
		[Dao.Events.EntityUpdated] = function(...) self:TotemSetDaoEvent(...) end
	})
end

function Toolbox:UnregisterCallbacks()
	self.totemSets:UnregisterAllCallbacks(self)
	Totems():UnregisterAllCallbacks(self)
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
				self:SetDbValue(self.db.profile, 'activeSet', self.totemSet.id)
			end
		end

		if Util.Objects.IsNil(self.totemSet) then
			Logging:Warn("GetTotemSet() : Could not locate/load the active totem set")
		end
	end

	return self.totemSet
end

function Toolbox:ShouldEnqueueEvent()
	-- need to enqueue events should spells not yet be initialized OR
	-- we already enqueued events and processing is pending
	return not Spells():IsInitialized() or
		(not Util.Objects.IsNil(self.eventQueue.timer) and Util.Tables.Count(self.eventQueue.events) > 0)
end

--- @param event string
--- @param totem Models.Totem.Totem
function Toolbox:EnqueueEvent(event, totem)
	Logging:Trace("EnqueueEvent(%s) : %s", tostring(event), tostring(totem))

	local queue = self.eventQueue
	if queue.timer then
		self:CancelTimer(queue.timer)
		queue.timer = nil
	end

	Util.Tables.Push(queue.events, {event, totem})
	queue.timer = self:ScheduleTimer(function() self:ProcessEvents() end, 2)
end

function Toolbox:ProcessEvents()
	local queue = self.eventQueue
	Logging:Trace("ProcessEvents(%d)", Util.Tables.Count(queue.events))

	local process = Util.Tables.Copy(queue.events)
	queue.events = {}
	queue.timer = nil

	for _, eventDetail in pairs(process) do
		self:TotemUpdated(eventDetail[1], eventDetail[2])
	end
end

--- @param event string
--- @param totem Models.Totem.Totem
function Toolbox:TotemUpdated(event, totem)
	Logging:Debug("Update(%s) : %s", event, Util.Objects.ToString(totem:toTable()))

	if self:ShouldEnqueueEvent() then
		self:EnqueueEvent(event, totem)
		return
	end

	if not self.totemBar then self:GetFrame() end

	if Util.Objects.Equals(Totems().Events.TotemUpdated, event) then
		self.totemBar:UpdateButton(totem)
	end
end

function Toolbox:TotemSetDaoEvent(event, eventDetail)
	Logging:Debug("TotemSetDaoEvent(%s) : %s", event, Util.Objects.ToString(eventDetail))

	-- don't care about event if the totem bar isn't visible
	if not self.totemBar then
		return
	end

	--[[
	local extra = unpack(eventDetail.extra)
	if Util.Objects.IsTable(extra) and Util.Objects.IsNumber(extra.element) then
		self.frame:UpdateButton(Totems():Get(extra.element))
	else
		self.frame:UpdateButtons()
	end
	--]]
end

function Toolbox:GetSpellsByTotem(element)
	return Spells():GetHighestRanksByTotem(Totems():GetTotemName(element))
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

function Toolbox:GetElementIndex(element)
	local index = element
	local set = self:GetTotemSet()
	if set then
		index, _ = set:Get(element)
	end
	return Util.Objects.Default(index, 0) > 0 and index or element -- Util.Tables.Find(self.db.profile.order, element)
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
			self.totemSets:Update(set, 'totems', true, {element = element})
		end
	end
end

function Toolbox:CastByElement(element)
	element = tonumber(Util.Objects.Default(element, "0"))
	Logging:Trace("CastByElement(%s)", element)
	if self.totemBar and (element > 0 and element < C.MaxTotems) then
		local macro = self.totemBar:GetMacro(element)
		Logging:Trace("CastByElement(%s): %s", element, Util.Objects.ToString(macro))
		macro:Click("LeftButton", false)
	end
end