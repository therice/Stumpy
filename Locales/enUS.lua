local name, _ = ...
--local name_lower = name:lower()
local name_colored = "|cff1784d1" .. name .. "|r"

local L = LibStub("AceLocale-3.0"):NewLocale(name, "enUS", true, true)
if not L then return end

L["chat_commands_ec"]  = "Toggle combat emulation"
L["chat_version"] = "|cff1784d1" .. name .. "|r |cFFFFFFFFversion|r|cFFFFA500 %s|r"
L["clear"] = "Clear"
L["error_x"] = "|cFFC41E3AError|r : %s"
L["frame_logging"] = "" .. name_colored .. " : Logging"
L["left_click"] = "Left Click"
L["not_usable_by_x"] = "No usable by %s, |cFFFF0000disabling|r"
L["reload_ui"] = "Reload UI"
L["right_click"] = "Right Click"
L["shift_left_click"] = "Shift + Left Click"
L["totem_set"] = "Totem Set"