--- @type LibTotem
local lib = LibStub("LibTotem-1.0", true)

lib.Constants = {
	Classes = {
		Warrior     = 1,
		Paladin     = 2,
		Hunter      = 3,
		Rogue       = 4,
		Priest      = 5,
		--DeathKnight = 6
		Shaman      = 7,
		Mage        = 8,
		Warlock     = 9,
		--Monk        = 10,
		Druid       = 11,
		--DemonHunter = 12,
	},

	MaxTotems = _G.MAX_TOTEMS,

	Talents = {
		Spell = {
			DualWield      = 674,
			TotemicMastery = 16189,
		},
		Talent = {
			DualWield      = {2, 18},
			TotemicMastery = {3, 8},
		},
	},

	Totems = {
		-- https://wowpedia.fandom.com/wiki/API_GetTotemInfo
		-- index of the totem (Fire = 1 Earth = 2 Water = 3 Air = 4)
		Element = {
			Fire  = 1,
			Earth = 2,
			Water = 3,
			Air   = 4
		},
		ElementIdToName = {

		},
		-- these are the item ids which correspond to the physical item (totem)
		-- required to cast a totem of that element
		ItemId = {

		},
		--- @type table<number, LibTotem.Totem>
		Totem = {

		}
	},
}

local C = lib.Constants

C.Totems.ElementIdToName = tInvert(C.Totems.Element)

C.Totems.ItemId = {
	[C.Totems.Element.Fire]  = 5176,
	[C.Totems.Element.Earth] = 5175,
	[C.Totems.Element.Water] = 5177,
	[C.Totems.Element.Air]   = 5178
}