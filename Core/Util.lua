--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type LibUtil.Bitfield.Bitfield
local Bitfield = Util.Bitfield.Bitfield
--- @type Models.Player
local Player = AddOn.ImportPackage('Models').Player
--- @type LibTotem
local LibTotem = AddOn:GetLibrary("Totem")

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

local UnitNames = {}

-- Gets a unit's name formatted with realmName.
-- If the unit contains a '-' it's assumed it belongs to the realmName part.
-- Note: If 'unit' is a playername, that player must be in our raid or party!
-- @param u Any unit, except those that include '-' like "name-target".
-- @return Titlecased "unitName-realmName"
function AddOn:UnitName(u)
	if Util.Objects.IsEmpty(u) then return nil end
	if UnitNames[u] then return UnitNames[u] end

	local function qualify(name, realm)
		name = name:lower():gsub("^%l", string.upper)
		return name .. "-" .. realm
	end

	-- First strip any spaces
	local unit = gsub(u, " ", "")
	-- Then see if we already have a realm name appended
	local find = strfind(unit, "-", nil, true)
	-- "-" isn't the last character
	if find and find < #unit then
		-- Let's give it same treatment as below so we're sure it's the same
		local name, realm = strsplit("-", unit, 2)
		name = name:lower():gsub("^%l", string.upper)
		return qualify(name, realm)
	end
	-- Apparently functions like GetRaidRosterInfo() will return "real" name, while UnitName() won't
	-- always work with that (see ticket #145). We need this to be consistent, so just lowercase the unit:
	unit = unit:lower()
	-- Proceed with UnitName()
	local name, realm = UnitName(unit)
	-- Extract our own realm
	if Util.Strings.IsEmpty(realm) then realm = GetRealmName() or "" end
	-- if the name isn't set then UnitName couldn't parse unit, most likely because we're not grouped.
	if not name then name = unit end
	-- Below won't work without name
	-- We also want to make sure the returned name is always title cased (it might not always be! ty Blizzard)
	local qualified = qualify(name, realm)
	UnitNames[u] = qualified
	return qualified
end

function AddOn:UnitClass(name)
	local player = Player:Get(name)
	if player and Util.Strings.IsSet(player.class) then return player.class end
	return select(2, UnitClass(Ambiguate(name, "short")))
end

function AddOn.Player()
	local player = Player:Get("player")
	if player and player:IsClass("SHAMAN") then
		local talents = {}
		for talent, spell in pairs(LibTotem.Constants.Talents.Spell) do
			talents[spell] = select(5, GetTalentInfo(unpack(LibTotem.Constants.Talents.Talent[talent]))) == 1 and true or false
		end

		player:Update({talents = talents})
	end

	return player
end

local UnitExists, UnitIsVisible, UnitIsConnected, UnitCanAssist, UnitIsDeadOrGhost =
	_G.UnitExists, _G.UnitIsVisible, _G.UnitIsConnected, _G.UnitCanAssist, _G.UnitIsDeadOrGhost

function AddOn.UnitIsEligibleForBuff(unit)
	return
		UnitExists(unit) and UnitIsVisible(unit) and UnitIsConnected(unit) and
		UnitCanAssist(C.player, unit) and not UnitIsDeadOrGhost(unit)
end

function AddOn:InCombatLockdown()
	return InCombatLockdown() or self:CombatEmulationEnabled()
end

--- @param reversed boolean
--- @param forceParty boolean
function AddOn:GroupIterator(reversed, forceParty)
	reversed = Util.Objects.Default(reversed, false)
	forceParty = Util.Objects.Default(forceParty, false)

	local unit = (not forceParty and IsInRaid()) and C.raid or C.party
	local numGroupMembers = (unit == C.party) and GetNumSubgroupMembers() or GetNumGroupMembers()
	local i = reversed and numGroupMembers or (unit == C.party and 0 or 1)
	return function()
		local ret
		if i == 0 and unit == C.party then
			ret = C.player
		elseif i <= numGroupMembers and i > 0 then
			ret = unit .. i
		end
		i = i + (reversed and -1 or 1)
		return ret
	end
end

function AddOn.IsUnitAffectedBySpell(unitId, spellId)
	local affected = false

	if spellId > 0 then
		local name, unitSpellId

		for index = 1, 40 do
			local result = { UnitBuff(unitId, index) }
			if Util.Objects.IsTable(result) and Util.Tables.Count(result) > 0 then
				name, unitSpellId = tostring(result[1]), tonumber(result[10])
			else
				break
			end

			Logging:Debug("IsUnitAffectedBySpell(%s, %d) : %s, %d [candidate]", unitId, spellId, tostring(name), unitSpellId)

			if spellId == unitSpellId then
				affected = true
				break
			end
		end
	end

	return affected
end