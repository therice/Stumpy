local name, _ = ...
--local name_lower = name:lower()
--local name_colored = "|cFF9DDAE6" .. name .. "|r"

local L = LibStub("AceLocale-3.0"):NewLocale(name, "enUS", true, true)
if not L then return end

L["chat_version"] = "|cff1784d1" .. name .. "|r |cFFFFFFFFversion|r|cFFFFA500 %s|r"
L["error_x"] = "|cFFC41E3AError|r : %s"