--- @type AddOn
local _, AddOn = ...
local C = AddOn.Constants
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type LibLogging
local Logging = AddOn:GetLibrary("Logging")
local AceEvent = AddOn:GetLibrary("AceEvent")

--- @class Models.Spell.Spell
local Spell = AddOn.Package('Models.Spell'):Class('Spell')

local SpellFields = {'id', 'name', 'modifier', 'icon'}
function Spell:initialize(...)
	local t = Util.Tables.Temp(...)
	for index, field in pairs(SpellFields) do
		self[field] = t[index]
	end
	Util.Tables.ReleaseTemp(t)
end

function Spell:__tostring()
	return format("%s %s [%d]", self.name, Util.Strings.IsEmpty(self.modifier) and "" or self.modifier, self.id)
end

-- https://wowpedia.fandom.com/wiki/API_GetNumSpellTabs
local GetNumSpellTabs = _G.GetNumSpellTabs
-- https://wowpedia.fandom.com/wiki/API_GetSpellTabInfo
local GetSpellTabInfo = _G.GetSpellTabInfo
-- https://wowpedia.fandom.com/wiki/API_GetSpellBookItemInfo
local GetSpellBookItemInfo = _G.GetSpellBookItemInfo
-- https://wowpedia.fandom.com/wiki/API_GetSpellBookItemName
local GetSpellBookItemName = _G.GetSpellBookItemName
-- https://wowpedia.fandom.com/wiki/API_GetSpellLink
local GetSpellLink = _G.GetSpellLink
-- https://wowpedia.fandom.com/wiki/API_GetSpellInfo
local GetSpellInfo = _G.GetSpellInfo

--- @class Models.Spell.Spells
--- @field public set Models.Totem.Set
--- @field public subscriptions table<number, rx.Subscription>
local Spells = AddOn.Instance(
	'Models.Spell.Spells',
	function()
		local singleton = {
			--- @type table<number, Models.Spell.Spell>
			spells = {}
		}

		AceEvent:Embed(singleton)

		singleton:RegisterMessage(
			C.Messages.Enabled,
			function()
				Logging:Trace("%s received, initializing Spells", C.Messages.Enabled)
				singleton:UnregisterMessage(C.Messages.Enabled)
				singleton:Initialize()
			end
		)

		return singleton
	end
)

function Spells:IsInitialized()
	return Util.Tables.Count(self.spells) > 0
end

function Spells:Initialize()
	if not self:IsInitialized() then
		local spellCount = 0
		for tab = 1, GetNumSpellTabs() do
			local _, _, offs, numspells, _, specId = GetSpellTabInfo(tab)
			if specId == 0 then
				spellCount = offs + numspells
			end
		end

		Logging:Trace("Initialize() : spell count = %d", spellCount)

		for index = 1, spellCount do
			local type, id = GetSpellBookItemInfo(index, "SPELL")
			local name, modifier = GetSpellBookItemName(index, type)
			local _, _, icon = GetSpellInfo(id)
			local spell = Spell(id, name, modifier, icon)
			Logging:Trace("UpdateSpells(%d) : %s", index, tostring(spell))
		end
	end
end

function Spells:Shutdown()
	if self:IsInitialized() then
		self.spells:Clear()
	end
end