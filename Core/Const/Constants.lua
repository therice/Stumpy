--- @type AddOn
local name, AddOn = ...

--local L = LibStub("AceLocale-3.0"):GetLocale(name)

-- this will be first non-library file to load
-- shim it here so available until re-established
if not AddOn._IsTestContext then AddOn._IsTestContext = function() return false end end

AddOn.Constants = {
    name   = name,
    name_c = "|CFF87CEFA" .. name .. "|r",

    Classes = {
        Shaman = 7
    },

    -- https://www.easyrgb.com/en/convert.php
    -- https://wowpedia.fandom.com/wiki/Quality
    Colors  = {
        AdmiralBlue    = CreateColor(0.3, 0.35, 0.5, 1),
        Aluminum       = CreateColor(0.7, 0.7, 0.7, 1),
        Blue           = CreateColor(0, 0.44, 0.87, 1),
        Cream          = CreateColor(1.0, 0.99216, 0.81569, 1),
        Cyan           = CreateColor(0.61569, 0.85490, 0.90196, 1),
        DeathKnightRed = CreateColor(0.77, 0.12, 0.23, 1),
        Evergreen      = CreateColor(0, 1, 0.59, 1),
        Fuchsia        = CreateColor(1, 0, 1, 1),
        Green          = CreateColor(0, 1, 0, 1),
        Grey           = CreateColor(0.73725, 0.78824, 0.80392, 1),
        ItemArtifact   = _G.ITEM_QUALITY_COLORS[6].color,
        ItemCommon     = _G.ITEM_QUALITY_COLORS[1].color,
        ItemEpic       = _G.ITEM_QUALITY_COLORS[4].color,
        ItemHeirloom   = _G.ITEM_QUALITY_COLORS[7].color,
        ItemLegendary  = _G.ITEM_QUALITY_COLORS[5].color,
        ItemPoor       = _G.ITEM_QUALITY_COLORS[0].color,
        ItemRare       = _G.ITEM_QUALITY_COLORS[3].color,
        ItemUncommon   = _G.ITEM_QUALITY_COLORS[2].color,
        LightBlue      = CreateColor(0.62353, 0.86275, 0.89412, 1),
        LuminousOrange = CreateColor(1, 0, 0, 1),
        LuminousYellow = CreateColor(1, 1, 0, 1),
        MageBlue       = CreateColor(0.25, 0.78, 0.92, 1),
        Marigold       = CreateColor(0.7, 0.6, 0, 1),
        Nickel         = CreateColor(0.5, 0.5, 0.5, 1),
        PaladinPink    = CreateColor(0.96, 0.55, 0.73, 1),
        Pumpkin        = CreateColor(0.8, 0.5, 0, 1),
        Purple         = CreateColor(0.53, 0.53, 0.93, 1),
        RogueYellow    = CreateColor(1, 0.96, 0.41, 1),
        Salmon         = CreateColor(0.99216, 0.48627, 0.43137, 1),
        White          = CreateColor(1, 1, 1, 1)
    },

    Buttons = {
        Left  = "LeftButton",
        Right = "RightButton",
    },

    Direction = {
        Horizontal = "HORIZONTAL",
        Vertical   = "VERTICAL",
    },

    Events = {
        PlayerEnteringWorld    = "PLAYER_ENTERING_WORLD",
        PlayerTotemUpdate      = "PLAYER_TOTEM_UPDATE",
        SpellsChanged          = "SPELLS_CHANGED",
        UnitSpellcastSucceeded = "UNIT_SPELLCAST_SUCCEEDED"
    },

    Icons = {
        TotemGeneric = 136232
    },

    Keys = {
        RightControl = "RCTRL",
        LeftControl = "LCTRL",
    },

    Layout = {
        Column  = "COLUMN",
        Grid    = "GRID",
    },

    MaxTotems = MAX_TOTEMS,

    Messages = {
        Enabled             = name .. "_Enabled",
        ModeChanged         = name .. "_ModeChanged",
    },

    Modes = {
        Standard      = 0x01, -- 1   [base10] -> 00000001
        Test          = 0x02, -- 2   [base10] -> 00000010
        Develop       = 0x04, -- 4   [base10] -> 00000100
        Persistence   = 0x08, -- 8   [base10] -> 00001000
        Reserved2     = 0x10, -- 16  [base10] -> 00010000
        Reserved3     = 0x20, -- 32  [base10] -> 00100000
        Reserved4     = 0x40, -- 64  [base10] -> 01000000
        EmulateCombat = 0x80, -- 128 [base10] -> 10000000
    },

    Sort = {
        Ascending   = "ASCENDING",
        Descending  = "DESCENDING"
    },

    Talents = {
        DualWield      = {2, 18},
        TotemicMastery = {3, 8},
    },

    TalentSpells = {
        DualWield      = 674,
        TotemicMastery = 16189,
    },

    -- https://wowpedia.fandom.com/wiki/API_GetTotemInfo
    -- index of the totem (Fire = 1 Earth = 2 Water = 3 Air = 4)
    TotemElements = {
        Fire  = 1,
        Earth = 2,
        Water = 3,
        Air   = 4
    },
}

local C = AddOn.Constants
AddOn.Constants.ClassTags = {
    Shaman = C_CreatureInfo.GetClassInfo(C.Classes.Shaman).classFile
}

-- these are the item ids which correspond to the physical item (totem)
-- required to cast a totem of that element
AddOn.Constants.TotemItemIds = {
    [C.TotemElements.Fire]  = 5176,
    [C.TotemElements.Earth] = 5175,
    [C.TotemElements.Water] = 5177,
    [C.TotemElements.Air]   = 5178
}