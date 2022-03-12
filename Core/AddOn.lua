--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util =  AddOn:GetLibrary("Util")
--- @type Models.SemanticVersion
local SemanticVersion  = AddOn.Package('Models').SemanticVersion
--- @type UI.Util
local UIUtil = AddOn.Require('UI.Util')
--- @type Core.SlashCommands
local SlashCommands = AddOn.Require('Core.SlashCommands')

function AddOn:OnInitialize()
	Logging:Debug("OnInitialize(%s)", self:GetName())
	-- convert to a semantic version
	self.version = SemanticVersion(self.version)
	-- bitfield which keeps track of our operating mode
	--- @type Core.Mode
	self.mode = AddOn.Package('Core').Mode()
	-- add on settings
	self.db = self:GetLibrary("AceDB"):New(self:Qualify('DB'), self.defaults)
	if not AddOn._IsTestContext() then Logging:SetRootThreshold(self.db.profile.logThreshold) end

	-- register slash commands
	SlashCommands:Register()
	self:RegisterChatCommands()
end

function AddOn:OnEnable()
	--@debug@
	-- this enables certain code paths that wouldn't otherwise be available in normal usage
	self.mode:Enable(C.Modes.Develop)
	--@end-debug@

	Logging:Debug("OnEnable(%s) : Mode=%s", self:GetName(), tostring(self.mode))

	self.player = AddOn.Player()
	Logging:Debug("%s", Util.Objects.ToString(self.player:toTable()))
	--[[
	if not self.player:IsShaman() then
		AddOn:Print(
			format(
				L["not_usable_by_x"],
				UIUtil.ClassColorDecorator(self.player.classTag):decorate(self.player.class)
			)
		)
		self:Disable()
		return
	end
	--]]

	for name, module in self:IterateModules() do
		Logging:Debug("OnEnable(%s) : Examining module (startup) '%s'", self:GetName(), name)
		if module:EnableOnStartup() then
			Logging:Debug("OnEnable(%s) : Enabling module (startup) '%s'", self:GetName(), name)
			module:Enable()
		end
	end

	-- register events
	self:SubscribeToEvents()
	-- add minimap button
	self:AddMinimapButton()
	self:Print(format(L["chat_version"], tostring(self.version)) .. " is now loaded.")

	-- fire message at end that addon has been enabled
	self:SendMessage(C.Messages.Enabled)
end

function AddOn:OnDisable()
	Logging:Debug("OnDisable(%s)", self:GetName())
	for _, module in self:IterateModules() do
		module:Disable()
	end
end