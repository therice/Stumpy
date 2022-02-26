--- @type AddOn
local _, AddOn = ...
local C = AddOn.Constants
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type LibLogging
local Logging = AddOn:GetLibrary("Logging")
local AceEvent = AddOn:GetLibrary("AceEvent")
--- @type CallbackHandler
local Cbh = AddOn:GetLibrary("CallbackHandler")
--- @type Core.Event
local Event = AddOn.RequireOnUse('Core.Event')

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

function Totem:Refresh()
	SetFields(self, GetTotemInfo(self.element))
	Logging:Trace("Refresh(%d) : %s", self.element, Util.Objects.ToString(self:toTable()))
end

--- @class Models.Totem.Set
local Set = AddOn.Package('Models.Totem'):Class('Set')
function Set:initialize()
	--- @type table<number, Models.Totem.Totem>
	self.totems = {}
	for element= 1, MAX_TOTEMS do
		self.totems[element] = Totem(element)
	end
end

--- @return Models.Totem.Totem
function Set:Get(element)
	return self.totems[element]
end

function Set:Clear()
	self.totems = {}
end

--- @param element number
function Set:Refresh(element)
	Logging:Trace("Refresh(%d)", Util.Objects.Default(element, -1))
	if not element then
		for _, totem in pairs(self.totems) do
			totem:Refresh()
		end
	else
		self.totems[element]:Refresh()
	end
end

local Events = {
	TotemUpdated    =   "TotemUpdated"
}

--- @class Models.Totem.Totems
--- @field public set Models.Totem.Set
--- @field public subscriptions table<number, rx.Subscription>
local Totems = AddOn.Instance(
	'Models.Totem.Totems',
	function()
		local singleton = {
			--- @type Models.Totem.Set
			set = Set(),
			--- @type table<number, rx.Subscription>
			subscriptions = {},
			--- @type table
			callbacks = nil
		}

		AceEvent:Embed(singleton)

		singleton.callbacks = Cbh:New(singleton)
		singleton:RegisterMessage(
			C.Messages.Enabled,
			function()
				Logging:Trace("%s received, initializing Totems", C.Messages.Enabled)
				singleton:UnregisterMessage(C.Messages.Enabled)
				singleton:Initialize()
			end
		)

		return singleton
	end
)

Totems.Events = Events

function Totems:FireCallbacks(element)
	if Util.Objects.IsNil(element) then
		for _, totem in pairs(self.set.totems) do
			self.callbacks:Fire(Events.TotemUpdated, totem)
		end
	else
		self.callbacks:Fire(Events.TotemUpdated, self.set.totems[element])
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

function Totems:OnTotemUpdate(_, element)
	Logging:Trace("OnTotemUpdate() : %d", element)
	self.set:Refresh(element)
	self:FireCallbacks(element)
end

--function Totems:OnSpellcastSuccess(...)
--	Logging:Trace("OnSpellcastSuccess() : %s", Util.Objects.ToString({...}))
--end

function Totems:IsInitialized()
	return Util.Tables.Count(self.subscriptions) > 0
end

function Totems:Initialize()
	if not self:IsInitialized() then
		self.set:Refresh()
		self:FireCallbacks()

		self.subscriptions = Event():BulkSubscribe({
			[C.Events.PlayerTotemUpdate] = function(...) self:OnTotemUpdate(...) end,
			--[C.Events.UnitSpellcastSucceeded] = function(...)  self:OnSpellcastSuccess(...) end
		})
	end
end

function Totems:Shutdown()
	if self:IsInitialized() then
		self.set:Clear()
		AddOn.Unsubscribe(self.subscriptions)
		self.subscriptions = {}
	end
end