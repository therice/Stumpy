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
local UUID = Util.UUID.UUID
--- @type Models.Date
local Date = AddOn.Package('Models').Date
--- @type Models.DateFormat
local DateFormat = AddOn.Package('Models').DateFormat
--- @type Models.Spell.Spells
local Spells = AddOn.RequireOnUse('Models.Spell.Spells')

local GetTotemInfo = GetTotemInfo

--local SpellRange = AddOn:GetLibrary("SpellRange")

--- @class Models.Totem.Totem
local Totem = AddOn.Package('Models.Totem'):Class('Totem')

-- https://wowpedia.fandom.com/wiki/API_GetTotemInfo
--      haveTotem, totemName, startTime, duration, icon
--
-- These are in the order expected from arguments to the events listed above
--
local TotemFields = {'present', 'name', 'startTime', 'duration', 'icon'}
--- @param self  Models.Totem.Totem
local function SetFields(self, ...)
	Logging:Trace("SetFields(%d) : %s", self.element, Util.Objects.ToString({...}))
	local t = Util.Tables.Temp(...)
	for index, field in pairs(TotemFields) do
		self[field] = t[index]
	end
	Util.Tables.ReleaseTemp(t)
end

--- @param element number
function Totem:initialize(element, ...)
	self.element = element
	SetFields(self, ...)
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

function Totem:GetNormalizedName()
	-- this assumes the last part of the name is the rank
	local parts = Util.Strings.Split(self.name, ' ')
	return Util.Strings.Join(' ', Util.Tables.Sub(parts, 1, #parts - 1))
end

function Totem:IsPresent()
	return self.present
end

function Totem:Refresh()
	SetFields(self, GetTotemInfo(self.element))
	Logging:Trace("Refresh(%d) : %s", self.element, Util.Objects.ToString(self:toTable()))
end

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

		for element = 1, C.MaxTotems do
			singleton.totems[element] = Totem(element)
		end

		singleton.callbacks = Cbh:New(singleton)

		return singleton
	end
)

Totems.Events = Events

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

function Totems:Get(element)
	return self.totems[element]
end

function Totems:GetTotemName(element)
	return self.totemItemNames[element]
end

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

--function Totems:OnSpellcastSuccess(...)
--	Logging:Trace("OnSpellcastSuccess() : %s", Util.Objects.ToString({...}))
--end

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

		self:LoadItemNames()
		self:Refresh()
		self:FireCallbacks()

		self.subscriptions = Event():BulkSubscribe({
           --[C.Events.UnitSpellcastSucceeded] = function(...)  self:OnSpellcastSuccess(...) end
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

function TotemSet:initialize(id, name)
	Versioned.initialize(self, Version)
	---@type string
	self.id = id
	---@type string
	self.name = name
	---@type table<number, table<number>>
	self.totems = {}

	for element = 1, C.MaxTotems do
		self.totems[element] = {}
	end
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

	local order, spell = nil, nil

	if not Util.Objects.IsEmpty(data) then
		order, spell = unpack(data)

		Logging:Trace("Get(%d) : %d (order) %d (spell)", element, tostring(order),  Util.Objects.Default(spell, -1))
		if spell then
			spell = Spells():GetById(spell)
		end

		Logging:Trace("Get(%d) : %d (spell) => %s", element, Util.Objects.Default(spell, -1), Util.Objects.ToString(spell and spell:toTable() or {}))
	end

	return order, spell
end

function TotemSet.CreateInstance(...)
	local uuid, name = UUID(), format("%s (%s)", L["totem_set"], DateFormat.Full:format(Date()))
	return Set(uuid, name)
end

--- @class Models.Totem.TotemSetDao
local TotemSetDao = AddOn.Package('Models.Totem'):Class('TotemSetDao', Dao)
function TotemSetDao:initialize(module, db)
	Dao.initialize(self, module, db, TotemSet)
end

do
	local DefaultSpellIdsByElement = {
		[C.TotemElements.Fire]  = 3599, -- Searing Totem
		[C.TotemElements.Earth] = 8071, -- Stoneskin Totem
		[C.TotemElements.Water] = 5394, -- Healing Stream Totem
		[C.TotemElements.Air]   = 8512, -- Windfury Totem
	}

	local Default = TotemSet('621E37A4-3F2A-49D4-C145-EDF8D5D965B8', 'Stumpy Default Totem Set')

	for element, spellId in pairs(DefaultSpellIdsByElement) do
		Default:Set(element, element, spellId)
	end

	TotemSet.Default = Default
end