--- @type AddOn
local _, AddOn = ...
local C = AddOn.Constants
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type LibLogging
local Logging = AddOn:GetLibrary("Logging")
--- @type Core.Event
local Event = AddOn.RequireOnUse('Core.Event')
--- @type LibTotem
local LibTotem = AddOn:GetLibrary("Totem")

-- this is a good dynamic way to get the totem (item) name required for a spell, but using static data instead
--[[
local Deformat = AddOn:GetLibrary("Deformat")
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

local GetTotemBySpell = Util.Memoize.Memoize(
	function(spell)
		Logging:Trace("GetTotemBySpell(%d)", tostring(spell.id))

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
					Logging:Trace("GetTotemBySpell(%d) : %s", spell.id, totemText or "")
					return totemText
				end
			end
		end

		return nil
	end
)
--]]

--- @class Models.Spell.Aura
local Aura = AddOn.Package('Models.Spell'):Class('Aura')
function Aura:initialize(name, id)
	self.name = name
	self.id = id
end

function Aura:GetName()
	return self.name
end

function Aura:GetId()
	return self.id
end

function Aura:IsValid()
	return not Util.Strings.IsEmpty(self.name) and self.id > 0
end

function Aura:__tostring()
	return format("Aura(%s [%d])", Util.Objects.Default(self.name, "N/A"), self.id)
end

--[[
local AuraUtil, UnitAura, AuraNone = _G.AuraUtil, _G.UnitAura, Aura(nil, 0)

local GetAuraByTotemSpell = Util.Memoize.Memoize(
	function(spell)
		Logging:Debug("GetAuraByTotemSpell(%s)", tostring(spell))

		--local result = {
		--	AuraUtil.FindAura(
		--		function(...)
		--			-- 1st three params are predicates
		--			local args = { ... }
		--			local name, spellId = args[4], args[13]
		--			Logging:Debug("GetAuraByTotemSpell(%s) : %s (%d)", spell, name, spellId)
		--			return Util.Strings.StartsWith(spell, name) or Util.Strings.Equal(spell, name)
		--		end,
		--		C.player
		--	)
		--}


		local aura
		for index = 1, 255 do
			local name, _, _, _, _, _, _, _, _, spellId = UnitAura(C.player, index, C.AuraFilter.Helpful)
			-- no result, so nothing further to do
			if Util.Strings.IsEmpty(name) then
				break
			end
			Logging:Debug("GetAuraByTotemSpell(%d) : %s, %d [candidate]", index, tostring(name), tonumber(spellId))

			if  Util.Strings.StartsWith(spell, name) or Util.Strings.Equal(spell, name) then
				aura = Aura(name, spellId)
				break
			end
		end

		Logging:Debug("GetAuraByTotemSpell(%s) : %s [result]", tostring(spell), tostring(aura))
		--
		--if Util.Objects.IsTable(result) and Util.Tables.Count(result) >= 10 then
		--	return Aura(result[1], result[10])
		--else
		--	return nil
		--end

		return aura
	end
)

local function GetAuraByTotemSpell(spell)
	Logging:Debug("GetAuraByTotemSpell(%s)", tostring(spell))

	--local result = {
	--	AuraUtil.FindAura(
	--		function(...)
	--			-- 1st three params are predicates
	--			local args = { ... }
	--			local name, spellId = args[4], args[13]
	--			Logging:Debug("GetAuraByTotemSpell(%s) : %s (%d)", spell, name, spellId)
	--			return Util.Strings.StartsWith(spell, name) or Util.Strings.Equal(spell, name)
	--		end,
	--		C.player
	--	)
	--}


	-- , C.AuraFilter.Helpful .. "|" .. C.AuraFilter.Cancelable

	local aura
	for _ = 1, 3 do
		for index = 1, 255 do
			local name, _, _, _, _, _, _, _, _, spellId = UnitAura(C.player, index)
			-- no result, so nothing further to do
			if Util.Strings.IsEmpty(name) then
				break
			end

			Logging:Debug("GetAuraByTotemSpell(%d) : %s, %d [candidate]", index, tostring(name), tonumber(spellId))

			if  Util.Strings.StartsWith(spell, name) or Util.Strings.Equal(spell, name) then
				aura = Aura(name, spellId)
				break
			end
		end

		if not Util.Objects.IsNil(aura) then
			break
		end
	end

	Logging:Debug("GetAuraByTotemSpell(%s) : %s [result]", tostring(spell), tostring(aura))
	--
	--if Util.Objects.IsTable(result) and Util.Tables.Count(result) >= 10 then
	--	return Aura(result[1], result[10])
	--else
	--	return nil
	--end

	return aura
end
--]]

--- @class Models.Spell.Spell
local Spell = AddOn.Package('Models.Spell'):Class('Spell')
local SpellFields = {'id', 'spellBookId', 'name', 'modifier', 'icon', 'link'}
function Spell:initialize(...)
	local t = Util.Tables.Temp(...)
	for index, field in pairs(SpellFields) do
		self[field] = t[index]
	end
	Util.Tables.ReleaseTemp(t)
end

local GetRank =  Util.Memoize.Memoize(
	function(modifier)
		if not Util.Objects.IsString(modifier) then return 0 end
		return tonumber(strmatch(Util.Strings.Lower(modifier), "%a+ (%d+)")) or 0
	end
)

function Spell:GetId()
	return self.id
end

function Spell:GetSpellBookId()
	return self.spellBookId
end

function Spell:GetName()
	return self.name
end

function Spell:GetIcon()
	return self.icon
end

function Spell:GetRank()
	return GetRank(self.modifier)
end

--[[
function Spell:GetTotemName()
	return GetTotemBySpell(self)
end
--]]

--- @return Optional
function Spell:GetTotemElement()
	return Util.Optional.ofNillable(LibTotem:GetElementBySpellId(self:GetId()))
end

--[[
--- @return Models.Spell.Aura
function Spell:GetAura()
	local totemElement = self:GetTotemElement()
	if totemElement:isPresent() then
		local aura = GetAuraByTotemSpell(self:GetName())
		return aura or AuraNone
	end

	return AuraNone
end

--]]

function Spell:__tostring()
	local rank = self:GetRank()
	if rank > 0 then
		return format("Spell(%s, %d, %d, %d)", self.name, rank, self.id, self.spellBookId)
	else
		return format("Spell(%s, %d, %d)", self.name, self.id, self.spellBookId)
	end
end

-- https://wowpedia.fandom.com/wiki/API_GetNumSpellTabs
local GetNumSpellTabs = _G.GetNumSpellTabs
-- https://wowpedia.fandom.com/wiki/API_GetSpellTabInfo
local GetSpellTabInfo = _G.GetSpellTabInfo
-- https://wowpedia.fandom.com/wiki/API_GetSpellBookItemInfo
local GetSpellBookItemInfo = _G.GetSpellBookItemInfo
-- https://wowpedia.fandom.com/wiki/API_GetSpellLink
local GetSpellLink = _G.GetSpellLink
-- https://wowpedia.fandom.com/wiki/API_GetSpellInfo
local GetSpellInfo = _G.GetSpellInfo

local SpellAPI= _G.Spell
local SpellMixin = _G.CreateFromMixins(_G.SpellMixin)
local Delay = 0.50
local SpellBookType = "SPELL"

--- @class Models.Spell.Spells
--- @field public spells table<string, table>
--- @field public subscriptions table<number, rx.Subscription>
--- @field public timer table
local Spells = AddOn.Instance(
	'Models.Spell.Spells',
	function()
		return {
			spells = {
				--- @type table<number, Models.Spell.Spell>
				byId = {},
				--- @type table<number, table<Models.Spell.Spell>>
				byTotem = {},
				--- @type table<number, number>
				uncached = {},
				Reset = function(self)
					self.byId = {}
					self.byTotem = {}
					self.uncached = {}
				end
			},
			subscriptions      = nil,
			timer              = nil,
		}
	end
)

--- @param self Models.Spell.Spells
--- @param spellBookId number
--- @param id number
--- @return Optional
local function AddSpell(self, spellBookId, id)
	Logging:Trace("AddSpell(%d, %d)", spellBookId, id)
	SpellMixin:SetSpellID(id)

	if SpellMixin:IsSpellEmpty() then
		Logging:Trace("AddSpell(%d) : is empty", id)
		return Util.Optional.empty()
	end

	if SpellMixin:IsSpellDataCached() then
		-- spell isn't known by the player
		if not IsSpellKnown(id) then
			Logging:Trace("AddSpell(%d) : not known", id)
			return Util.Optional.empty()
		end
		-- don't want to include passive spells
		if IsPassiveSpell(id) then
			Logging:Trace("AddSpell(%d) : is passive", id)
			return Util.Optional.empty()
		end

		local name, modifier, link =
			SpellMixin:GetSpellName(),  Util.Objects.Default(SpellMixin:GetSpellSubtext(), ""), GetSpellLink(id)
		local _, _, icon = GetSpellInfo(id)

		self.spells.byId[id] = Spell(id, spellBookId, name, modifier, icon, link)
		--Logging:Trace("AddSpell(%d) : %s, %s, %s, %s", id, name, modifier,  icon, link)
		Logging:Trace("AddSpell(%d) : %s (%s)", id, tostring(self.spells.byId[id]), tostring(modifier))
		return Util.Optional.of(true)
	else
		Logging:Trace("AddSpell(%d) : not cached", id)
		return Util.Optional.of(false)
	end

end

--- @param self Models.Spell.Spells
--- @param spellBookId number
--- @param id number
local function AddSpellWithFallback(self, spellBookId, id)
	-- attempt to load and add spell
	-- if it was uncached, schedule a callback for when it's loaded
	AddSpell(self, spellBookId, id):ifPresent(
		function(cached)
			--Logging:Debug("AddSpellWithFallback(%d) : %s", id, tostring(cached))
			if not cached then
				self.spells.uncached[id] = true
				SpellAPI:CreateFromSpellID(id):ContinueOnSpellLoad(
					function()
						self.spells.uncached[id] = nil
						AddSpell(self, spellBookId, id)
					end
				)
			end
		end
	)
end

--- @type self Models.Spell.Spells
local function LoadSpells(self, execution)
	Logging:Debug("LoadSpells(%d) : START", execution)
	AddOn:SendMessage(C.Messages.SpellsRefreshStart)

	self.spells:Reset()

	local spellCount = 0
	for tab = 1, GetNumSpellTabs() do
		local _, _, offs, numspells, _, specId = GetSpellTabInfo(tab)
		if specId == 0 then
			spellCount = offs + numspells
		end
	end

	Logging:Debug("LoadSpells(%d) : spell count = %d", execution, spellCount)

	for spellBookId = 1, spellCount do
		local type, id = GetSpellBookItemInfo(spellBookId, SpellBookType)
		Logging:Trace("LoadSpells(%d) : %d : %d = %s", execution, spellBookId, id, type)
		if Util.Objects.Equals(type, SpellBookType) then
			AddSpellWithFallback(self, spellBookId, id)
		end
	end

	Logging:Debug("LoadSpells(%d) : END (uncached = %d)", execution, Util.Tables.Count(self.spells.uncached))
	AddOn:SendMessage(C.Messages.SpellsRefreshComplete)
end

-- this is only for debugging purposes and keeping track of even ordering
local SpellsChangedCounter = {
	value = 0,
	increment = function(self)
		self.value = self.value + 1
		return self.value
	end
}

--- @type self Models.Spell.Spells
local function OnSpellsChanged(self, ...)
	Logging:Debug("OnSpellsChanged() : %s", Util.Objects.ToString({...}))

	local function CancelTimer()
		if self.timer then
			local cancelled = AddOn:CancelTimer(self.timer)
			Logging:Debug("OnSpellsChanged.CancelTimer() : %s (cancelled)", tostring(cancelled))
			self.timer = nil
		end
	end

	local execution = SpellsChangedCounter:increment()
	AddOn.Timer.After(
		0,
		function()
			CancelTimer()
			self.timer = AddOn:ScheduleTimer(function() LoadSpells(self, execution) end, Delay)
		end
	)
end


function Spells:IsEnabled()
	local isEnabled = not Util.Objects.IsNil(self.subscriptions)
	Logging:Trace("IsEnabled() : %s", tostring(isEnabled))
	return isEnabled
end

function Spells:IsLoaded()
	local spellCount, uncachedCount = Util.Tables.Count(self.spells.byId),  Util.Tables.Count(self.spells.uncached)
	Logging:Trace("IsLoaded() : %d (spells) %d (uncached)", spellCount, uncachedCount)
	if AddOn._IsTestContext() then
		return true
	else
		return spellCount > 0 and uncachedCount == 0
	end
end

function Spells:Enable(load)
	if Util.Objects.IsNil(self.subscriptions) then
		load = Util.Objects.Default(load, false)

		Logging:Debug("Enable()")
		self.subscriptions = Event():BulkSubscribe({
           [C.Events.SpellsChanged] = function(...) OnSpellsChanged(self, ...) end,
           [C.Events.LearnedSpellInTab] = function(...) OnSpellsChanged(self, ...) end
       })

		if load then
			OnSpellsChanged(self)
		end
	end
end

function Spells:Disable()
	if Util.Objects.IsNil(self.subscriptions) then
		Logging:Debug("Disable()")
		AddOn.Unsubscribe(self.subscriptions)
		self.subscriptions = nil
		self.spells:Reset()
	end
end

--- @return Models.Spell.Spell
function Spells:GetById(id)
	--Logging:Trace("GetById(%d)", id)
	return self.spells.byId[id]
end

function Spells:GetAllRanksById(id)
	local all = {}
	local spell = self:GetById(id)
	if spell then
		all = Util.Tables.CopyFilter(
			self.spells.byId,
			function(s) return Util.Strings.Equal(spell.name, s.name) end
		)
	end
	return all
end

--- @param name string the spell name (cannot be nil)
--- @param rank number the rank of the spell (if nil, it will be ignored and 1st spell which matches name wil be returned)
function Spells:GetByNameAndRank(name, rank)
	--Logging:Debug("GetByNameAndRank(%s, %d) : %s", tostring(name), tonumber(rank), Util.Tables.Count(self.spells.byId))

	local spell
	if Util.Objects.IsSet(name) then
		_, spell =
			Util.Tables.FindFn(
				self.spells.byId,
				function(s)
					if Util.Objects.Equals(s.name, name) then
						if not Util.Objects.IsNil(rank) then
							return s:GetRank() == rank
						else
							return true
						end
					end

					return false
				end
			)
	end
	return spell
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

--- @param element number
function Spells:GetHighestRanksByTotemElement(element)
	local all = self.spells.byTotem[element]
	if Util.Objects.IsEmpty(all) and Util.Objects.IsNumber(element) then
		all =
			Util(self.spells.byId)
				-- only match spells for specified totem
				:CopyFilter(function(s) return s:GetTotemElement():ifPresent(function(e) return e == element end) end)
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
		self.spells.byTotem[element] = all or {}
	end
	return all
end