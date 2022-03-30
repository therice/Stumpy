local name, _ = ...
--local name_lower = name:lower()
local name_colored = "|cff1784d1" .. name .. "|r"

local L = LibStub("AceLocale-3.0"):NewLocale(name, "enUS", true, true)
if not L then return end

L["cast_totem"] = "Cast %s Totem"
L["chat_commands_ec"]  = "Toggle combat emulation"
L["chat_version"] = "|cff1784d1" .. name .. "|r |cFFFFFFFFversion|r|cFFFFA500 %s|r"
L["clear"] = "Clear"
L["dismiss_totem"] = "Dismiss %s Totem"
L["error_x"] = "|cFFC41E3AError|r : %s"
L["frame_logging"] = "" .. name_colored .. " : Logging"
L["flyout"] = "Flyout"
-- stuff related to abbreviating key binds
L["KEY_ALT"] = "A"
L["KEY_CTRL"] = "C"
L["KEY_DELETE"] = "Del"
L["KEY_HOME"] = "Hm"
L["KEY_INSERT"] = "Ins"
L["KEY_MOUSEBUTTON"] = "M"
L["KEY_MOUSEWHEELDOWN"] = "MwD"
L["KEY_MOUSEWHEELUP"] = "MwU"
L["KEY_NUMPAD"] = "N"
L["KEY_PAGEDOWN"] = "PD"
L["KEY_PAGEUP"] = "PU"
L["KEY_SHIFT"] = "S"
L["KEY_SPACE"] = "SpB"
L["left_click"] = "Left Click"
L["not_usable_by_x"] = "No usable by %s, |cFFFF0000disabling|r"
L["reload_ui"] = "Reload UI"
L["right_click"] = "Right Click"
L["set"] = "Set"
L["shift_left_click"] = "Shift + Left Click"
L["spell"] = "Spell"
L["spells"] = "Spells"
L["totem"] = "Totem"
L["totem_bar"] = "Totem Bar"
L["totem_flyout"] = "Totem Flyout"
L["totem_set"] = "Totem Set"

