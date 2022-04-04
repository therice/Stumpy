--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type LibLogging
local Logging = AddOn:GetLibrary("Logging")
--- @type CallbackHandler
local Cbh = AddOn:GetLibrary("CallbackHandler")
--- @type Core.Event
local Event = AddOn.RequireOnUse('Core.Event')
--- @type Models.SemanticVersion
local SemanticVersion = AddOn.Package('Models').SemanticVersion
--- @type Models.Versioned
local Versioned = AddOn.Package('Models').Versioned
--- @type Models.Dao
local Dao = AddOn.Package('Models').Dao
--- @type LibUtil.UUID
local UUID = Util.UUID
--- @type Models.Date
local Date = AddOn.Package('Models').Date
--- @type Models.DateFormat
local DateFormat = AddOn.Package('Models').DateFormat
--- @type Models.Spell.Spells
local Spells = AddOn.RequireOnUse('Models.Spell.Spells')
--- @type LibTotem
local LibTotem = AddOn:GetLibrary("Totem")
--- @type HereBeDragons
local HBD = AddOn:GetLibrary('HereBeDragons')

local GetTotemInfo = GetTotemInfo

--- @type Models.Totem.TotemTimers
local TotemTimers = AddOn.RequireOnUse('Models.Totem.TotemTimers')
--- @class Models.Totem.Totem
local Totem = AddOn.Package('Models.Totem'):Class('Totem')
--- forward declaration of constant for schedule which updates affected units
--- @type string
local AffectedUnitTimerName

--- forward declare functions for initialization
local SetFields, PostInitialize

--- @param element number
function Totem:initialize(element, ...)
	self.element = element
	SetFields(self, ...)
end

-- https://wowpedia.fandom.com/wiki/API_GetTotemInfo
--      haveTotem, totemName, startTime, duration, icon
--
-- These are in the order expected from arguments to the events listed above
--
local TotemFields = {'present', 'name', 'startTime', 'duration', 'icon'}
--- @param self  Models.Totem.Totem
SetFields = function(self, ...)
	Logging:Trace("SetFields(%d) : %s", self.element, Util.Objects.ToString({...}))
	local t = Util.Tables.Temp(...)
	for index, field in pairs(TotemFields) do
		self[field] = t[index]
	end
	Util.Tables.ReleaseTemp(t)

	PostInitialize(self)
end

--- @param self Models.Totem.Totem
PostInitialize = function(self)
	if self:IsPresent() then
		self.position = Util.Optional.of({HBD:GetPlayerWorldPosition()})
		self.affected = Util.Optional.empty()
		TotemTimers():AddTotem(nil, self)
	else
		self.position = Util.Optional.empty()
		self.affected = Util.Optional.empty()
		TotemTimers():RemoveTotem(nil, self)
	end
end

function Totem:GetStartTime()
	return self.startTime
end

function Totem:GetDuration()
	return self.duration
end

function Totem:GetElement()
	return self.element
end

function Totem:GetIcon()
	return self.icon
end

function Totem:GetName()
	return self.name
end

--- @return Optional
function Totem:GetPosition()
	return self.position
end

--- @return Optional
function Totem:GetAffected()
	return self.affected
end

function Totem:GetPulse()
	local spell = self:GetSpell()
	return spell and LibTotem:GetPulseBySpellId(spell:GetId()) or 0
end

function Totem:IsRankPresent()
	if not Util.Strings.IsEmpty(self.name) then
		local parts = Util.Strings.Split(self.name, ' ')
		Logging:Trace("IsRankPresent() : %s", Util.Objects.ToString(parts))
		return Util.Numbers.IsRoman(parts[#parts])
	end

	return false
end

function Totem:GetRank()
	if not Util.Strings.IsEmpty(self.name) then
		if self:IsRankPresent() then
			-- this assumes the last part of the name is the rank
			local parts = Util.Strings.Split(self.name, ' ')
			local roman = parts[#parts]
			Logging:Trace("GetRank(%s)", tostring(roman))
			return Util.Numbers.DecodeRoman(roman)
		--[[
		else
			-- todo : dubious, very dubious
			return 1
		--]]
		end
	end

	return nil
end

function Totem:GetNormalizedName()
	if not Util.Strings.IsEmpty(self.name) then
		local hasRank = self:IsRankPresent()
		-- this assumes the last part of the name is the rank
		local parts = Util.Strings.Split(self.name, ' ')
		return Util.Strings.Join(' ', Util.Tables.Sub(parts, 1, hasRank and #parts - 1 or #parts))
	end

	return nil
end

function Totem:IsPresent()
	return self.present
end

function Totem:Refresh()
	SetFields(self, GetTotemInfo(self.element))
	Logging:Debug("Refresh(%d) : %s", self.element, Util.Objects.ToString(self:toTable()))
end

--- @return Optional
function Totem:GetAura()
	local spell = self:GetSpell()
	if spell then
		return Util.Optional.of(LibTotem:GetAuraBySpellId(spell:GetId()))
	end

	return Util.Optional.empty()
end

--- @return Models.Spell.Spell
function Totem:GetSpell()
	-- could use LibTotem, but this is dynamic
	local name, rank = self:GetNormalizedName(), self:GetRank()
	Logging:Trace("GetSpell(%s, %d)", tostring(name), tonumber(rank))
	return Spells():GetByNameAndRank(name, rank)
end

function Totem:IsAffectedUnitUpdateScheduled()
	return TotemTimers():IsTotemScheduled(AffectedUnitTimerName, self)
end

function Totem:__tostring()
	return format("Totem(%d, %s, %s)", self:GetElement(), Util.Strings.IfEmpty(self:GetName(), "N/A"), tostring(self:IsPresent()))
end

--- forward declaration of function which adds the default totem timers
local AddDefaultTotemTimers

local Events = {
	TotemUpdated    =   "TotemUpdated"
}

--- @class Models.Totem.Totems
--- @field public totems table<number, Models.Totem.Totem>
--- @field public subscriptions table<number, rx.Subscription>
local Totems = AddOn.Instance(
	'Models.Totem.Totems',
	function()
		local singleton = {
			--- @type table<number, Models.Totem.Totem>
			totems = {},
			--- @type table<number, rx.Subscription>
			subscriptions = {},
			--- @type table
			callbacks = nil,
			--- @type table<number, string>
			totemItemNames = {}
		}

		for element = 1, LibTotem.Constants.MaxTotems do
			singleton.totems[element] = Totem(element)
		end

		singleton.callbacks = Cbh:New(singleton)

		return singleton
	end
)

Totems.Events = Events

--[[
-- from Blizzard API
local Item = Item

function Totems:LoadItemNames()
	Logging:Trace("LoadItemNames()")
	for element = 1, C.MaxTotems do
		local itemId = C.TotemItemIds[element]
		local item = Item:CreateFromItemID(itemId)
		Logging:Trace("LoadItemNames(%d, %d)", element, itemId)

		item:ContinueOnItemLoad(
			function()
				self.totemItemNames[element] = item:GetItemName()
				Logging:Trace("LoadItemNames(%d) : %s", element, tostring(self.totemItemNames[element]))
			end
		)
	end
end
--]]

function Totems:Get(element)
	return self.totems[element]
end

--[[
function Totems:GetTotemName(element)
	return self.totemItemNames[element]
end
--]]

--- @param element number
function Totems:Refresh(element)
	Logging:Trace("Refresh(%d)", Util.Objects.Default(element, -1))
	if not element then
		for _, totem in pairs(self.totems) do
			totem:Refresh()
		end
	else
		self.totems[element]:Refresh()
	end
end

function Totems:OnTotemUpdate(_, element)
	Logging:Trace("OnTotemUpdate() : %d", element)
	self:Refresh(element)
	self:FireCallbacks(element)
end

--[[
function Totems:OnSpellcastSuccess(...)
	Logging:Trace("OnSpellcastSuccess() : %s", Util.Objects.ToString({...}))
end
--]]

function Totems:FireCallbacks(element)
	if Util.Objects.IsNil(element) then
		for _, totem in pairs(self.totems) do
			self.callbacks:Fire(Events.TotemUpdated, totem)
		end
	else
		self.callbacks:Fire(Events.TotemUpdated, self.totems[element])
	end
end

function Totems:RegisterCallbacks(target, callbacks)
	for event, eventFn in pairs(callbacks) do
		self.RegisterCallback(target, event, eventFn)
	end
end

function Totems:UnregisterCallbacks(target, callbacks)
	for _, event in pairs(callbacks) do
		self.UnregisterCallback(target, event)
	end
end

function Totems:UnregisterAllCallbacks(target)
	self.UnregisterAllCallbacks(target)
end

function Totems:IsInitialized()
	return Util.Tables.Count(self.subscriptions) > 0
end

function Totems:Initialize()
	if not self:IsInitialized() then
		Logging:Trace("Initialize()")

		AddDefaultTotemTimers()
		self:Refresh()
		self:FireCallbacks()

		self.subscriptions = Event():BulkSubscribe({
            --[C.Events.UnitSpellcastSucceeded] = function(...)  self:OnSpellcastSuccess(...) end,
			[C.Events.PlayerTotemUpdate] = function(...) self:OnTotemUpdate(...) end,
		})
	end
end

function Totems:Shutdown()
	if self:IsInitialized() then
		self.totems = {}
		self.totemItemNames = {}
		AddOn.Unsubscribe(self.subscriptions)
		self.subscriptions = {}
	end
end

--- @class Models.Totem.TotemSet
local TotemSet = AddOn.Package('Models.Totem'):Class('TotemSet', Versioned)
Versioned.ExcludeAttrsInHash(TotemSet)
Versioned.IncludeAttrsInRef(TotemSet)
TotemSet.static:AddTriggers("name", "default", "totems")

local Version = SemanticVersion(1, 0, 0)

function TotemSet:initialize(id, name, icon)
	Versioned.initialize(self, Version)
	---@type string
	self.id = id
	---@type string
	self.name = name
	--- @type number
	self.icon = icon or 0
	---@type table<number, table<number>>
	self.totems = {}

	for element = 1, LibTotem.Constants.MaxTotems do
		self.totems[element] = {}
	end
end

function TotemSet:__tostring()
	return self.name
end

function TotemSet:SetIcon(icon)
	self.icon = tonumber(icon)
end

function TotemSet:GetIcon()
	return self.icon
end

function TotemSet:SetOrder(element, order)
	self.totems[element][1] = order
end

function TotemSet:SetSpell(element, spell)
	self.totems[element][2] = spell
end

function TotemSet:Set(element, order, spell)
	Logging:Trace("Set(%d) : %d / %d", element, tonumber(order), Util.Objects.Default(spell, -1))
	self.totems[element] = {}
	self:SetOrder(element, order)
	self:SetSpell(element, spell)
end

--- @return number, Models.Spell.Spell
function TotemSet:Get(element)
	local data = self.totems[element]

	local order, spellId, spell = nil, nil, nil

	if not Util.Objects.IsEmpty(data) then
		order, spellId = unpack(data)

		Logging:Trace("Get(%d) : %d (order) %d (spell)", element, tostring(order),  Util.Objects.Default(spellId, -1))
		if spellId then
			spell = Spells():GetById(spellId)
		end

		Logging:Trace("Get(%d) : %d (spell) => %s", element, Util.Objects.Default(spellId, -1), Util.Objects.ToString(spell and spell:toTable() or {}))
	end

	return order, spell
end

--- this will yield a function which provides element to spell mappings, in the order specified by set
---
--- @return function
function TotemSet:OrderedIterator()
	local ordering =
		Util(self.totems):Copy()
			:Map(function(attrs) return attrs[1] end)
			:Flip()()
	--Logging:Debug("Iterator() : %s", Util.Objects.ToString(ordering))

	local index, element = 0

	return function()
		index = index + 1

		if index >  LibTotem.Constants.MaxTotems then
			return nil
		end

		element = ordering[index]
		Logging:Debug("OrderedIterator(%d) : %d", index, element)
		return element, self.totems[element][2]
	end
end

function TotemSet.CreateInstance(...)
	local uuid, name = UUID.UUID(), format("%s (%s)", L["totem_set"], DateFormat.Full:format(Date()))
	local totemSet = TotemSet(uuid, name, TotemSet.Default.icon)
	totemSet.totems = Util.Tables.Copy(TotemSet.Default.totems)
	return totemSet
end

--- @class Models.Totem.TotemSetDao
local TotemSetDao = AddOn.Package('Models.Totem'):Class('TotemSetDao', Dao)
function TotemSetDao:initialize(module, db)
	Dao.initialize(self, module, db, TotemSet)
end

--- @type Models.Totem.TotemTimer
local TotemTimer =  AddOn.Package('Models.Totem').TotemTimer
--- @type Models.Player
local Player = AddOn.Package('Models').Player

--- this timer is responsible for periodic updating of present totems (where applicable) with affected unit count
--- @class Models.Totem.AffectedUnitTimer
local AffectedUnitTimer = AddOn.Package('Models.Totem'):Class('AffectedUnitTimer', TotemTimer)
AffectedUnitTimerName = "AffectedUnitTimer"

function AffectedUnitTimer:initialize()
	-- todo : update this less frequently
	TotemTimer.initialize(self, AffectedUnitTimerName, function(...) self:_Evaluate(...) end, 1)
end

--- @param totem Models.Totem.Totem
function AffectedUnitTimer:AddTotem(totem)
	local spell = totem:GetSpell()
	Logging:Debug("AddTotem(%s, %s)", tostring(totem), tostring(spell))
	-- override logic to only add totems where unit count is relevant
	-- will only be called if totem is present and it affects (any) possible units
	if spell and LibTotem:AffectsAnyUnitBySpellId(spell:GetId()) then
		AffectedUnitTimer.super.AddTotem(self, totem)
	else
		Logging:Info("AddTotem(%s) : NOT adding", tostring(totem))
	end
end

--- @param totem Models.Totem.Totem
function AffectedUnitTimer:_Evaluate(totem)
	local candidates, affected = 0, 0

	local spell, aura = totem:GetSpell(), totem:GetAura()
	Logging:Trace("_Evaluate(%s, %s)", tostring(totem), tostring(aura))
	for unit in AddOn:GroupIterator(false, true) do
		local player = Player:Get(unit)
		Logging:Trace("_Evaluate(%s, %s) :  %s", tostring(totem), unit, tostring(player))
		if player then
			-- is the player a candidate for being affected by the totem's spell (based upon class)
			local isCandidate = LibTotem:AffectsUnitBySpellId(spell:GetId(), player:GetClassId())
			-- now check where the unit is eligible based upon it's state (connected, alive, etc.)
			local isEligible = AddOn.UnitIsEligibleForBuff(unit)
			Logging:Trace(
				"_Evaluate(%s, %s) : %s (is candidate) %s (is eligible)",
	              tostring(totem), unit, tostring(isCandidate), tostring(isEligible)
			)
			if isCandidate and isEligible then
				-- the unit is both a candidate and eligible, so increment the affected count
				candidates = candidates + 1
				-- if there is an aura, check that first
				if aura:isPresent() and AddOn.IsUnitAffectedBySpell(unit, aura:get()) then
					affected = affected + 1
				-- otherwise, check whether the unit is in range
				else
					-- totemic mastery provides 30 yard range, otherwise 20
					local range = Util.Objects.Check(AddOn.player.talents[LibTotem.Constants.Talents.Spell.TotemicMastery], 30, 20)
					local totemPosition = totem:GetPosition()
					totemPosition:ifPresent(
						function(position)
							local unitX, unitY, zone = HBD:GetUnitWorldPosition(unit)
							if unitX and unitY then
								local totemX, totemY = unpack(position)
								Logging:Trace(
									"_Evaluate(%s, %s) : %d, %d (totem) %d, %d (player) %d (range)",
									tostring(totem), unit,
									tonumber(totemX), tonumber(totemY), tonumber(unitX), tonumber(unitY),
									tonumber(range)
								)
								local distance = HBD:GetWorldDistance(zone, totemX, totemY, unitX, unitY)
								Logging:Trace( "_Evaluate(%s, %s) : %.2f (distance)", tostring(totem), unit, tonumber(distance))

								if distance and distance <= range then
									affected = affected + 1
								end
							end
						end
					)
				end
			end
		end
	end

	Logging:Trace("_Evaluate(%s, %s) : %d (candidates) %d (affected)", tostring(totem), tostring(aura), candidates, affected)
	totem.affected = Util.Optional.of({affected, candidates})
end

AddDefaultTotemTimers = function()
	Logging:Trace("AddDefaultTotemTimers()")
	TotemTimers():AddTimer(AffectedUnitTimer())
end

do
	local LTC = LibTotem.Constants.Totems

	local DefaultSpellIdsByElement = {
		[LTC.Element.Fire]  = 3599, -- Searing Totem
		[LTC.Element.Earth] = 8071, -- Stoneskin Totem
		[LTC.Element.Water] = 5394, -- Healing Stream Totem
		[LTC.Element.Air]   = 8512, -- Windfury Totem
	}

	local Default = TotemSet('621E37A4-3F2A-49D4-C145-EDF8D5D965B8', 'Stumpy Default Totem Set', 136008)

	for element, spellId in pairs(DefaultSpellIdsByElement) do
		Default:Set(element, element, spellId)
	end

	TotemSet.Default = Default
end