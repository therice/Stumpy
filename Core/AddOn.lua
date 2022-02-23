--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")


function AddOn:OnInitialize()
	Logging:Debug("OnInitialize(%s)", self:GetName())

	self.db = self:GetLibrary("AceDB"):New(self:Qualify('DB'), self.defaults)
end

function AddOn:OnEnable()
	Logging:Debug("OnEnable(%s)", self:GetName())

	self:Print(format(L["chat_version"], tostring(self.version)) .. " is now loaded.")
end

function AddOn:OnDisable()
	Logging:Debug("OnDisable(%s)", self:GetName())
end