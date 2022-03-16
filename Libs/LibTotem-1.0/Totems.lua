--- @type LibTotem
local lib = LibStub("LibTotem-1.0", true)

local Classes, Flags, Element, CTotems =
	lib.Constants.Classes, lib.Totem.Flags, lib.Constants.Totems.Element, lib.Constants.Totems.Totem

-- bitfield
local function Bf(...)
	return lib.Util.Bitfield.CreateAndEnableBits(...)
end

-- this isn't exclusively classes that can melee, but ones that
-- potentially benefit from melee oriented weapon spells
-- shamans are omitted because they typically use weapon imbues
local function WC()
	return Classes.Warrior, Classes.Rogue
end

-- this isn't exclusively classes that can melee, but ones that
-- potentially benefit from melee oriented spells
local function MC()
	return Classes.Warrior, Classes.Paladin, Classes.Hunter, Classes.Rogue, Classes.Shaman, Classes.Druid
end

-- classes which may have a mana pool
local function MAC()
	return Classes.Paladin, Classes.Hunter, Classes.Priest, Classes.Shaman, Classes.Mage, Classes.Warlock, Classes.Druid
end

-- all classes
local function AC()
	return unpack(lib.Util.Tables.Values(Classes))
end

local function AddTotem(...)
	lib.Util.Tables.Push(CTotems, lib.Totem(...))
end

--  {element, spellId, auraId, npcId, pulse, appliesTo, flags}
local Totems = {
	{ Element.Earth, 2484, 0, 2630 },   -- Earthbind

	{ Element.Fire, 1535, 0, 5879 },   -- Fire Nova Rank 1
	{ Element.Fire, 8498, 0, 6110 },   -- Fire Nova Rank 2
	{ Element.Fire, 8499, 0, 6111 },   -- Fire Nova Rank 3
	{ Element.Fire, 11314, 0, 7844 },  -- Fire Nova Rank 4
	{ Element.Fire, 11315, 0, 7845 },  -- Fire Nova Rank 5
	{ Element.Fire, 25546, 0, 15482 }, -- Fire Nova Rank 6
	{ Element.Fire, 25547, 0, 15483 }, -- Fire Nova Rank 7

	{ Element.Fire, 8190, 0, 5929, 2 },   -- Magma Rank 1
	{ Element.Fire, 10585, 0, 7464, 2 },  -- Magma Rank 2
	{ Element.Fire, 10586, 0, 7465, 2 },  -- Magma Rank 3
	{ Element.Fire, 10587, 0, 7466, 2 },  -- Magma Rank 4
	{ Element.Fire, 25552, 0, 1548, 2 },  -- Magma Rank 5

	-- this totem attacks continuously, with cast times randing from 1.5 to 2.5 seconds
	-- averages don't make sense for a repeating pulse
	{ Element.Fire, 3599, 0, 2523 },   -- Searing Rank 1
	{ Element.Fire, 6363, 0, 3902 },   -- Searing Rank 2
	{ Element.Fire, 6364, 0, 3903 },   -- Searing Rank 3
	{ Element.Fire, 6365, 0, 3904 },   -- Searing Rank 4
	{ Element.Fire, 10437, 0, 7400 },  -- Searing Rank 5
	{ Element.Fire, 10438, 0, 7402 },  -- Searing Rank 6
	{ Element.Fire, 25533, 0, 15480 }, -- Searing Rank 7

	{ Element.Earth, 5730, 0, 3579 },   -- Stoneclaw Rank 1
	{ Element.Earth, 6390, 0, 3911 },   -- Stoneclaw Rank 2
	{ Element.Earth, 6391, 0, 3912 },   -- Stoneclaw Rank 3
	{ Element.Earth, 6392, 0, 3913 },   -- Stoneclaw Rank 4
	{ Element.Earth, 10427, 0, 7398 },  -- Stoneclaw Rank 5
	{ Element.Earth, 10428, 0, 7399 },  -- Stoneclaw Rank 6
	{ Element.Earth, 25525, 0, 15478 }, -- Stoneclaw Rank 7

	{ Element.Water, 8184, 8185, 5927, 0, Bf(AC()) },    -- Fire Resistance Rank 1
	{ Element.Water, 10537, 10534, 7424, 0, Bf(AC()) },  -- Fire Resistance Rank 2
	{ Element.Water, 10538, 10535, 7425, 0, Bf(AC()) },  -- Fire Resistance Rank 3
	{ Element.Water, 25563, 25562, 15487, 0, Bf(AC()) }, -- Fire Resistance Rank 4

	-- https://wow.tools/dbc/?dbc=spellitemenchantment&build=2.5.3.42328#page=1&colFilter[1]=Flame
	-- https://wowpedia.fandom.com/wiki/API_GetWeaponEnchantInfo
	-- may want to refine to only classes which melee and don't use their own weapon imbues
	{ Element.Fire, 8227, 124, 5950, 0, Bf(AC()), Bf(Flags.WeaponEnchant) },      -- Flametongue Rank 1
	{ Element.Fire, 8249, 285, 6012, 0, Bf(AC()), Bf(Flags.WeaponEnchant) },      -- Flametongue Rank 2
	{ Element.Fire, 10526, 543, 7423, 0, Bf(AC()), Bf(Flags.WeaponEnchant) },     -- Flametongue Rank 3
	{ Element.Fire, 16387, 1683, 10557, 0, Bf(AC()), Bf(Flags.WeaponEnchant) },   -- Flametongue Rank 4
	{ Element.Fire, 25557, 2637, 15485, 0, Bf(AC()), Bf(Flags.WeaponEnchant) },   -- Flametongue Rank 5

	{ Element.Fire, 8181, 8182, 5926, 0, Bf(AC()) },    -- Frost Resistance Rank 1
	{ Element.Fire, 10478, 10476, 7412, 0, Bf(AC()) },  -- Frost Resistance Rank 2
	{ Element.Fire, 10479, 10477, 7413, 0, Bf(AC()) },  -- Frost Resistance Rank 3
	{ Element.Fire, 25560, 25559, 15486, 0, Bf(AC()) }, -- Frost Resistance Rank 4

	-- may want to refine to only classes which are typically benefit from AGI
	-- however, it varies by spec  (i.e. feral druid vs boomkin druid)
	{ Element.Air, 8835, 8836, 7486, 0, Bf(AC()) },    -- Grace of Air Rank 1
	{ Element.Air, 10627, 10626, 7487, 0, Bf(AC()) },  -- Grace of Air Rank 2
	{ Element.Air, 25359, 25360, 15463, 0, Bf(AC()) }, -- Grace of Air Rank 3

	{ Element.Air, 8177, 8178, 5925, 0, Bf(AC()) },    -- Grounding

	{ Element.Air, 10595, 10596, 7467, 0, Bf(AC()) },  -- Nature Resistance Rank 1
	{ Element.Air, 10600, 10598, 7468, 0, Bf(AC()) },  -- Nature Resistance Rank 2
	{ Element.Air, 10601, 10599, 7469, 0, Bf(AC()) },  -- Nature Resistance Rank 3
	{ Element.Air, 25574, 25573, 15490, 0, Bf(AC()) }, -- Nature Resistance Rank 4

	{ Element.Air, 6495, 0, 3968 },   -- Sentry

	-- may want to refine to only classes which are typically in melee range
	-- however, it varies by spec (i.e. feral druid vs boomkin druid)
	{ Element.Earth, 8071, 8072, 5873, 0, Bf(AC()) },       -- Stoneskin Rank 1
	{ Element.Earth, 8154, 8156, 5919, 0, Bf(AC()) },       -- Stoneskin Rank 2
	{ Element.Earth, 8155, 8157, 5920, 0, Bf(AC()) },       -- Stoneskin Rank 3
	{ Element.Earth, 10406, 10403, 7366, 0, Bf(AC()) },     -- Stoneskin Rank 4
	{ Element.Earth, 10407, 10404, 7367, 0, Bf(AC()) },     -- Stoneskin Rank 5
	{ Element.Earth, 10408, 10405, 7368, 0, Bf(AC()) },     -- Stoneskin Rank 6
	{ Element.Earth, 25508, 25506, 15470, 0, Bf(AC()) },    -- Stoneskin Rank 7
	{ Element.Earth, 25509, 25507, 15474, 0, Bf(AC()) },    -- Stoneskin Rank 8

	-- may want to refine to only classes which are typically benefit from STR
	-- however, it varies by spec (i.e. elemental shaman vs enhance shaman)
	{ Element.Earth, 8075, 8076, 5874, 0, Bf(AC()) },       -- Strength of Earth Rank 1
	{ Element.Earth, 8160, 8162, 5921, 0, Bf(AC()) },       -- Strength of Earth Rank 2
	{ Element.Earth, 8161, 8163, 5922, 0, Bf(AC()) },       -- Strength of Earth Rank 3
	{ Element.Earth, 10442, 10441, 7403, 0, Bf(AC()) },     -- Strength of Earth Rank 4
	{ Element.Earth, 25361, 25362, 15464, 0, Bf(AC()) },    -- Strength of Earth Rank 5
	{ Element.Earth, 25528, 25527, 15479, 0, Bf(AC()) },    -- Strength of Earth Rank 6

	-- may want to refine to only classes which melee and don't use their own weapon imbues
	{ Element.Air, 8512, 1783, 6112, 5, Bf(AC()), Bf(Flags.WeaponEnchant) },      -- Windfury Rank 1
	{ Element.Air, 10613, 563, 7483, 5, Bf(AC()), Bf(Flags.WeaponEnchant) },      -- Windfury Rank 2
	{ Element.Air, 10614, 564, 7484, 5, Bf(AC()), Bf(Flags.WeaponEnchant) },      -- Windfury Rank 3
	{ Element.Air, 25585, 2638, 15496, 5, Bf(AC()), Bf(Flags.WeaponEnchant) },    -- Windfury Rank 4
	{ Element.Air, 25587, 2639, 15497, 5, Bf(AC()), Bf(Flags.WeaponEnchant) },    -- Windfury Rank 5

	{ Element.Air, 15107, 15108, 9687, 0, Bf(AC()), },    -- Windwall Rank 1
	{ Element.Air, 15111, 15109, 9688, 0, Bf(AC()), },    -- Windwall Rank 2
	{ Element.Air, 15112, 15110, 9689, 0, Bf(AC()), },    -- Windwall Rank 3
	{ Element.Air, 25577, 25576, 15492, 0, Bf(AC()), },   -- Windwall Rank 4

	{ Element.Water, 8170, 0, 5924, 5, Bf(AC()) },          -- Disease Cleansing

	{ Element.Water, 5394, 5672, 3527, 2, Bf(AC()) },       -- Healing Stream Rank 1
	{ Element.Water, 6375, 6371, 3906, 2, Bf(AC()) },       -- Healing Stream Rank 2
	{ Element.Water, 6377, 6372, 3907, 2, Bf(AC()) },       -- Healing Stream Rank 3
	{ Element.Water, 10462, 10460, 3908, 2, Bf(AC()) },     -- Healing Stream Rank 4
	{ Element.Water, 10463, 10461, 3909, 2, Bf(AC()) },     -- Healing Stream Rank 5
	{ Element.Water, 25567, 25566, 15488, 2, Bf(AC()) },    -- Healing Stream Rank 6

	{ Element.Water, 5675, 5677, 3573, 2, Bf(MAC()) },      -- Mana Spring Rank 1
	{ Element.Water, 10495, 10491, 7414, 2, Bf(MAC()) },    -- Mana Spring Rank 2
	{ Element.Water, 10496, 10493, 7415, 2, Bf(MAC()) },    -- Mana Spring Rank 3
	{ Element.Water, 10497, 10494, 7416, 2, Bf(MAC()) },    -- Mana Spring Rank 4
	{ Element.Water, 25570, 25569, 15489, 2, Bf(MAC()) },   -- Mana Spring Rank 5

	{ Element.Water, 16190, 16191, 10467, 3, Bf(MAC()) },   -- Mana Tide Rank 1
	{ Element.Water, 17354, 17355, 11100, 3, Bf(MAC()) },   -- Mana Tide Rank 2
	{ Element.Water, 17359, 17360, 11101, 3, Bf(MAC()) },   -- Mana Tide Rank 3

	{ Element.Water, 8166, 0, 5923, 5, Bf(AC()) },          -- Poison Cleansing

	{ Element.Air, 25908, 25909, 15803, 0, Bf(AC()) },    -- Tranquil Air

	-- todo : check aura
	-- https://tbc.wowhead.com/spell=8146/tremor-totem-effect
	{ Element.Earth, 8143, 0, 5913, 3, Bf(AC()) },  -- Tremor

	-- may want to refine to only classes which benefit from spell power
	-- however, it varies by spec (i.e. feral druid vs boomkin druid)
	{ Element.Air, 3738, 2895, 15447, 0, Bf(AC()) },  -- Wrath of Air Totem

	-- may want to refine to only classes which benefit from spell crit
	-- however, it varies by spec (i.e. feral druid vs boomkin druid)
	{ Element.Fire, 30706, 30708, 17539, 0, Bf(AC()) }, -- Totem of Wrath

	{ Element.Fire, 2894, 0, 15438, 0, Bf(), Bf(Flags.SummonNpc) }, -- Fire Elemental Totem (by summon elemental SpellID)
	{ Element.Earth, 2062, 0, 15352, 0, Bf(), Bf(Flags.SummonNpc) }, -- Earth Elemental Totem (by summon elemental SpellID)
}

do
	-- add all the totem table data as instances of Totem class
	for _, t in pairs(Totems) do
		AddTotem(unpack(t))
	end

	local Indices = lib.Indices
	-- index totems by various elements
	for index, t in pairs(CTotems) do
		-- spell ids are unique
		Indices.BySpellId[t:GetSpellId()] = index
	end
end