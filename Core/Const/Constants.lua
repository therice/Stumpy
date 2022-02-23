--- @type AddOn
local name, AddOn = ...

--local L = LibStub("AceLocale-3.0"):GetLocale(name)

-- this will be first non-library file to load
-- shim it here so available until re-established
if not AddOn._IsTestContext then AddOn._IsTestContext = function() return false end end

AddOn.Constants = {
    name   = name,
    name_c = "|CFF87CEFA" .. name .. "|r",

    -- https://www.easyrgb.com/en/convert.php
    -- https://wowpedia.fandom.com/wiki/Quality
    Colors = {
        AdmiralBlue    = CreateColor(0.3, 0.35, 0.5, 1),
        Aluminum       = CreateColor(0.7, 0.7, 0.7, 1),
        Blue           = CreateColor(0, 0.44, 0.87, 1),
        Cream          = CreateColor(1.0, 0.99216, 0.81569, 1),
        Cyan           = CreateColor(0.61569,  0.85490, 0.90196, 1),
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
        LightBlue      = CreateColor(0.62353,0.86275,0.89412, 1),
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

    Events = {

    }
}