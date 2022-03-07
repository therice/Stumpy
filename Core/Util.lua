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

function AddOn:InCombatLockdown()
	return InCombatLockdown() or self:CombatEmulationEnabled()
end