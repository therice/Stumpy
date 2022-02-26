--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type LibUtil.Bitfield.Bitfield
local Bitfield = Util.Bitfield.Bitfield

--- @class Core.Mode
local Mode = AddOn.Package('Core'):Class('Mode', Bitfield)
function Mode:initialize()
	Bitfield.initialize(self, C.Modes.Standard)
end

function AddOn:Qualify(...)
	return Util.Strings.Join('_', C.name, ...)
end

--- @param subscriptions table<number, rx.Subscription>
function AddOn.Unsubscribe(subscriptions)
	if Util.Objects.IsSet(subscriptions) then
		for _, subscription in pairs(subscriptions) do
			subscription:unsubscribe()
		end
	end
end

function AddOn.Player()
	local guid = UnitGUID("player")
	local class, classTag, _, _, _, name, realm = GetPlayerInfoByGUID(guid)

	if Util.Objects.IsEmpty(realm) then
		realm = select(2, UnitFullName("player"))
	end

	local player = {
		guid = guid,
		class = class,
		classTag = classTag,
		name = name,
		realm = realm,
		talents = {

		},
		IsShaman = function(self)
			return Util.Objects.Equals(self.classTag, C.ClassTags.Shaman)
		end
	}

	if player:IsShaman() then
		for talent, spell in pairs(C.TalentSpells) do
			player.talents[spell] = select(5, GetTalentInfo(unpack(C.Talents[talent]))) == 1 and true or false
		end
	end

	return player
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
local GetSpellSubtext = _G.GetSpellSubtext

function AddOn.SpellLinkToSpell(link)
	return strmatch(strmatch(link or "", "spell:[%d:-]+") or "", "(spell:.-):*$")
end

function AddOn.UpdateSpells(type)
	type = Util.Objects.Default(type, "spell")

	local spellCount = 0
	for tab = 1, GetNumSpellTabs() do
		local _, _, offs, numspells, _, specId = GetSpellTabInfo(tab)
		if specId == 0 then
			spellCount = offs + numspells
		end
	end

	Logging:Trace("UpdateSpells() : spell count = %d", spellCount)

	for index = 1, spellCount do
		local type, id = GetSpellBookItemInfo(index, type)
		local name, subName = GetSpellBookItemName(index, type)
		local subText = GetSpellSubtext(id)
		local link =  GetSpellLink(index, type)
		Logging:Trace("UpdateSpells() : index=%d, name=%s (%s), type=%s, id=%d, subtext=%s, link=%s", index, name, subName, type, id, tostring(subText), tostring(AddOn.SpellLinkToSpell(link)))
		Logging:Trace("UpdateSpells() : id=%d, %s", id, Util.Objects.ToString({GetSpellInfo(id)}))
	end


end