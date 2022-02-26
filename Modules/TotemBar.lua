--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type Models.Totem.Totems
local Totems = AddOn.RequireOnUse('Models.Totem.Totems')

--- @class TotemBar
local TotemBar = AddOn:NewModule('TotemBar')

TotemBar.defaults = {
	profile = {
		size    = 50,
		spacing = 8,
		grow    = C.Direction.Horizontal,
		sort    = C.Sort.Ascending,
	}
}

function TotemBar:OnInitialize()
	Logging:Debug("OnInitialize(%s)", self:GetName())
	self.db = AddOn.Libs.AceDB:New(AddOn:Qualify('TotemBar'), self.defaults)
end

function TotemBar:OnEnable()
	Logging:Debug("OnEnable(%s)", self:GetName())
	self:RegisterCallbacks()
	self:GetFrame():Show()
end

function TotemBar:RegisterCallbacks()
	Totems():RegisterCallbacks(self, {
		[Totems().Events.TotemUpdated] = function(...)  self:Update(...) end
	})
end

function TotemBar:UnregisterCallbacks()
	Totems():UnregisterAllCallbacks(self)
end

function TotemBar:EnableOnStartup()
	return true
end
