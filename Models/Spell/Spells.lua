--- @type AddOn
local _, AddOn = ...
local C = AddOn.Constants
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type LibLogging
local Logging = AddOn:GetLibrary("Logging")
local Deformat = AddOn:GetLibrary("Deformat")

--- @class Models.Spell.Spell
local Spell = AddOn.Package('Models.Spell'):Class('Spell')
local SpellFields = {'id', 'name', 'modifier', 'icon', 'link'}
function Spell:initialize(...)
	local t = Util.Tables.Temp(...)
	--Logging:Trace("%s", Util.Objects.ToString(t))
	for index, field in pairs(SpellFields) do
		self[field] = t[index]
	end
	Util.Tables.ReleaseTemp(t)
	--Logging:Trace("%s", Util.Objects.ToString(self:toTable()))
	-- various attributes which don't apply to all spells
	self.totemName = nil
end

local GetRank =  Util.Memoize.Memoize(
	function(modifier)
		if not Util.Objects.IsString(modifier) then return 0 end
		return tonumber(strmatch(Util.Strings.Lower(modifier), "%a+ (%d+)")) or 0
	end
)

function Spell:GetName()
	return self.name
end

function Spell:GetIcon()
	return self.icon
end

function Spell:GetRank()
	return GetRank(self.modifier)
end

function Spell:__tostring()
	local rank = self:GetRank()
	if rank > 0 then
		return format("%s (%d) [%d]", self.name, rank, self.id)
	else
		return format("%s [%d]", self.name, self.id)
	end
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


--- @class SpellsActionMutex
local SpellsActionMutex = AddOn.Class('SpellsActionMutex')
function SpellsActionMutex:initialize()
	self.active = false
	self.timer = nil
end

function SpellsActionMutex:IsActive()
	return self.active
end

function SpellsActionMutex:Cancel()
	if self.timer then
		AddOn:CancelTimer(self.timer)
		self.timer = nil
	end
end

function SpellsActionMutex:Schedule(fn, after)
	self:Cancel()
	self.timer = AddOn:ScheduleTimer(fn, after)
end

function SpellsActionMutex:Execute(fn)
	Util.Functions.try(
		function()
			self.active = true
			fn()
		end
	).finally(
		function()
			self.active = false
		end
	)
end

--- @class Models.Spell.Spells
--- @field public spells  table<number, Models.Spell.Spell>
--- @field public spells  table<number, table<Models.Spell.Spell>>
--- @field public subscriptions table<number, rx.Subscription>
--- @field public refresh SpellsActionMutex
--- @field public augment SpellsActionMutex
local Spells = AddOn.Instance(
	'Models.Spell.Spells',
	function()
		return {
			--- @type table<number, Models.Spell.Spell>
			spells             = {},
			spellsByTotem      = {},
			eventSubscriptions = nil,
			refresh            = SpellsActionMutex(),
			augment            = SpellsActionMutex(),
		}
	end
)

function Spells:IsInitialized()
	Logging:Debug("IsInitialized(%s, %d)", tostring(self.refresh:IsActive()), Util.Tables.Count(self.spells))
	return Util.Tables.Count(self.spells) > 0 and not self.refresh:IsActive()
end


-- https://github.com/tomrus88/BlizzardInterfaceCode/blob/tbc/Interface/FrameXML/GameTooltip.xml
-- https://github.com/tomrus88/BlizzardInterfaceCode/blob/tbc/Interface/FrameXML/GameTooltip.lua
-- https://github.com/tomrus88/BlizzardInterfaceCode/blob/tbc/Interface/SharedXML/GameTooltipTemplate.xml
local tooltip = CreateFrame("GameTooltip", "Spells_TooltipParse", nil, "GameTooltipTemplate")
tooltip:SetOwner(UIParent, "ANCHOR_NONE")
tooltip:UnregisterAllEvents()
tooltip:Hide()

-- this will be the tooltip line format for whether spell requires a totem (and what it is)
local SPELL_TOTEMS = _G.SPELL_TOTEMS .. "%s"
-- there are up to 8 lines, but we only examine the left text (as other stuff irrelevant for our purposes)
local TextLeftPattern = tooltip:GetName().."TextLeft%d"

local function AugmentSpell(spell)
	if Util.Objects.IsNil(spell) or not Util.Objects.IsInstanceOf(spell, Spell) then
		return
	end

	Logging:Trace("AugmentSpell(%d)", tostring(spell.id))

	local link = spell.link
	--Logging:Trace("AugmentSpell(%d) : %s", id, link)
	tooltip:SetOwner(UIParent, "ANCHOR_NONE")
	tooltip:SetHyperlink(link)
	--Logging:Trace("AugmentSpell(%d) : NumLines=%s", id, tooltip:NumLines())

	for i = 1, tooltip:NumLines() or 0 do
		local line = getglobal(TextLeftPattern:format(i))
		if line and line.GetText then
			local text = line:GetText() or ""
			--Logging:Trace("AugmentSpell(%d) : %s", id, text)
			local totemText = Deformat(text, SPELL_TOTEMS)
			if Util.Strings.IsSet(totemText) then
				Logging:Trace("AugmentSpell(%d) : %s", spell.id, totemText or "")
				spell.totemName = totemText
				break
			end
		end
	end

	tooltip:Hide()
end

--- @param self Models.Spell.Spells
local function AugmentSpells(self)
	Logging:Trace("AugmentSpells()")

	-- don't allow multiple concurrent augmentations to occur
	if self.augment:IsActive() then
		self.augment:Schedule(function() AugmentSpells(self) end, 2)
		return
	end

	self.augment:Execute(
		function()
			for _, spell in pairs(self.spells) do
				AugmentSpell(spell)
			end
		end
	)
end

function Spells:Refresh()
	Logging:Trace("Refresh()")

	-- don't allow multiple concurrent refreshes to occur
	if self.refresh:IsActive() then
		self.refresh:Schedule(function() self:Refresh() end, 2)
		return
	end

	self.refresh:Execute(
		function()
			self.spells = {}
			self.spellsByTotem = {}

			local spellCount = 0
			for tab = 1, GetNumSpellTabs() do
				local _, _, offs, numspells, _, specId = GetSpellTabInfo(tab)
				if specId == 0 then
					spellCount = offs + numspells
				end
			end

			Logging:Trace("Refresh() : spell count = %d", spellCount)

			for index = 1, spellCount do
				local type, id = GetSpellBookItemInfo(index, "SPELL")
				local _, modifier = GetSpellBookItemName(index, type)
				-- apparently, the modifier can be nil on initial load
				modifier = Util.Objects.Default(modifier, "")
				local name, _, icon = GetSpellInfo(id)
				local link = GetSpellLink(id)
				local spell = Spell(id, name, modifier, icon, link)
				self.spells[id] = spell
				Logging:Trace("Refresh(%d) : %s", index, tostring(spell))
			end

			-- give some time before executing the augmentation
			AddOn:ScheduleTimer(function() AugmentSpells(self) end, 2)
		end
	)
end

--- @return Models.Spell.Spell
function Spells:GetById(id)
	return self.spells[id]
end

function Spells:GetAllRanksById(id)
	local all = {}

	local spell = self:GetById(id)
	if spell then
		all = Util.Tables.CopyFilter(
			self.spells,
			function(s) return Util.Strings.Equal(spell.name, s.name) end
		)
	end

	return all
end

function Spells:GetHighestRankById(id)
	local all = self:GetAllRanksById(id)
	if all then
		return Util.Tables.FoldL(
			all,
			function(u, v)
				--Logging:Debug("u = %s, v = %s", tostring(u), tostring(v))
				if u:GetRank() > v:GetRank() then
					return u
				else
					return v
				end
			end,
			Util.Tables.First(all)
		)
	else
		return nil
	end
end
function Spells:GetHighestRanksByTotem(totem)
	local all = self.spellsByTotem[totem]

	if Util.Objects.IsEmpty(all) and Util.Strings.IsSet(totem) then
		all =
			Util(self.spells)
				-- only match spells for specified totem
				:CopyFilter(function(s) return Util.Strings.Equal(s.totemName, totem) end)
				-- group by the spell name
				:Group(function(s) return s:GetName() end)
				-- take the highest rank of the spell
				:Map(
					function(spells)
						return Util.Tables.FoldL(
							spells,
							function(u, v)
								if u:GetRank() > v:GetRank() then
									return u
								else
									return v
								end
							end,
							Util.Tables.First(spells)
						)
					end
				)
				:Values()
				:Sort(function(a, b) return a:GetName() < b:GetName() end)()

		Logging:Trace("%s", Util.Objects.ToString(Util.Tables.Copy(all, function(s) return s:toTable() end), 5))

		self.spellsByTotem[totem] = all or {}
	end

	return all
end