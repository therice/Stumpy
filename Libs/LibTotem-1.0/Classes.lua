--- @type LibTotem
local lib = LibStub("LibTotem-1.0", true)

local Logging, Util = lib.Logging, lib.Util

--- @class LibTotem.Totem
local Totem = lib.Class('LibTotem.Totem')
lib.Totem = Totem
lib.Totem.Flags = {
	WeaponEnchant   =   1,
	SummonNpc       =   2,
}

function Totem:initialize(element, spellId, auraId, npcId, pulse, appliesTo, flags)
	--- @type number
	self.element = element
	--- @type number
	self.spellId = spellId
	--- @type number
	self.auraId = auraId
	--- @type number
	self.npcId = npcId
	--- @type number
	self.pulse = pulse or 0
	--- @type LibUtil.Bitfield.Bitfield
	self.appliesTo = appliesTo or lib.Util.Bitfield.Create(0)
	--- @type LibUtil.Bitfield.Bitfield
	self.flags = flags or lib.Util.Bitfield.Create(0)
end

function Totem:GetElement()
	return self.element
end

function Totem:GetSpellId()
	return self.spellId
end

function Totem:GetAuraId()
	return self.auraId
end

function Totem:GetNPCId()
	return self.npcId
end

function Totem:HasPulse()
	return self.pulse > 0
end

function Totem:GetPulse()
	return self.pulse
end

function Totem:IsApplicableTo(class)
	if Util.Objects.IsNumber(class) then
		return self.appliesTo:BitEnabled(class)
	else
		return self.appliesTo:AnyBitEnabled()
	end
end

function Totem:__tostring()
	return format(
		"Totem(element=%d spellId=%d auraId=%d npcId=%d pulse=%d appliesTo=%s flags=%s)",
		self.element, self.spellId, self.auraId, self.npcId, self.pulse,
		tostring(self.appliesTo),
		tostring(self.flags)
	)
end