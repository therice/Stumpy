--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")

--- @class Spells
local Spells = AddOn:NewModule('Spells')

function Spells:OnInitialize()
	Logging:Debug("OnInitialize(%s)", self:GetName())
end

function Spells:OnEnable()
	Logging:Debug("OnEnable(%s)", self:GetName())
end

function Spells:EnableOnStartup()
	return true
end

