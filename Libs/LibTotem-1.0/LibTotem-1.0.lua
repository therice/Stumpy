local MAJOR_VERSION = "LibTotem-1.0"
local MINOR_VERSION = 20502

--- @class LibTotem
local lib, _ = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not lib then return end

--- @type LibLogging
lib.Logging = LibStub("LibLogging-1.1")
--- @type LibClass
lib.Class = LibStub("LibClass-1.0")
--- @type LibUtil
lib.Util = LibStub("LibUtil-1.2")

lib.Constants = {

}

lib.Indices = {
	BySpellId = {

	}
}

local Logging = lib.Logging

--- @param index table<number, number>
--- @param indexKey number
--- @param mappingFn function<LibTotem.Totem>
local function GetByIndex(index, indexKey, mappingFn)
	local totemIndex = index[indexKey]
	if totemIndex then
		return mappingFn(lib.Constants.Totems.Totem[totemIndex])
	end

	return nil
end

--- @return number|nil
function lib:GetElementBySpellId(spellId)
	return GetByIndex(
		self.Indices.BySpellId,
		spellId,
		function(t) return t:GetElement() end
	)
end

function lib:GetAuraBySpellId(spellId)
	return GetByIndex(
		self.Indices.BySpellId,
		spellId,
		function(t) return t:GetAuraId() end
	)
end

function lib:AffectsAnyUnitBySpellId(spellId)
	Logging:Debug("AffectsAnyUnitBySpellId(%d)", tonumber(spellId))
	return GetByIndex(
		self.Indices.BySpellId,
		spellId,
		function(t) return t:IsApplicableTo() end
	)
end

function lib:AffectsUnitBySpellId(spellId, class)
	return GetByIndex(
		self.Indices.BySpellId,
		spellId,
		function(t) return t:IsApplicableTo(class) end
	)
end