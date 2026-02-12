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
--- @type Models.Totem.Totems
local Totems = AddOn.RequireOnUse('Models.Totem.Totems')
--- @type Core.Message
local Message = AddOn.RequireOnUse('Core.Message')
--- @type Models.Spell.Spells
local Spells = AddOn.RequireOnUse('Models.Spell.Spells')

function AddOn:OnInitialize()
	Logging:Debug("OnInitialize(%s)", self:GetName())
	local version, build, date, tocVersion = GetBuildInfo()
	AddOn.BuildInfo = {
		version =  SemanticVersion(version),
		build = build,
		date = date,
		tocVersion = tocVersion,

		-- technically, this is wrath "classic" but that's the only flavor which exists right now
		IsWrath = function(self) return self.version.major == 3 and self.version.minor == 4 end,
		IsWrathP1 = function(self) return self:IsWrath() and self.version.patch == 0 end, -- Naxx
		IsWrathP2 = function(self) return self:IsWrath() and self.version.patch == 1 end, -- Ulduar
		IsWrathP3 = function(self) return self:IsWrath() and self.version.patch == 2 end, -- TOGC
		IsWrathP4 = function(self) return self:IsWrath() and self.version.patch == 3 end, -- ICC

		IsCataclysm = function(self) return self.version.major == 4 and self.version.minor == 4 end,

		IsMOP = function(self) return self.version.major == 5 and self.version.minor == 5 end,
		IsMOPP2 = function(self) return self:IsMOP() and self.version.patch == 2 end,
		IsMOPP3 = function(self) return self:IsMOP() and self.version.patch == 3 end,
	}

	Logging:Debug("OnInitialize(%s) : BuildInfo(%s)", self:GetName(), Util.Objects.ToString(AddOn.BuildInfo))

	-- convert to a semantic version
	self.version = SemanticVersion(self.version)
	-- bitfield which keeps track of our operating mode
	--- @type Core.Mode
	self.mode = AddOn.Package('Core').Mode()
	-- is the addon enabled, can be altered at runtime
	self.enabled = true
	-- add on settings
	self.db = self:GetLibrary("AceDB"):New(self:Qualify('DB'), self.defaults)
	if not AddOn._IsTestContext() then Logging:SetRootThreshold(self.db.profile.logThreshold) end

	-- register slash commands
	SlashCommands:Register()
	self:RegisterChatCommands()
end

function AddOn:OnEnable(rescheduled)
	rescheduled = Util.Objects.Default(rescheduled, false)

	--@debug@
	-- this enables certain code paths that wouldn't otherwise be available in normal usage
	self.mode:Enable(C.Modes.Develop)
	--@end-debug@

	Logging:Debug("OnEnable(%s) : Mode=%s", self:GetName(), tostring(self.mode))

	-- register events
	if not rescheduled then
		self:SubscribeToEvents()
	end

	self.player = AddOn.Player()
	-- seems to be client regression introduced in 2.5.4 where the needed API calls to get a player's information
	-- isn't always available on initial login, so reschedule
	if not self.player then
		self:ScheduleTimer(function() self:OnEnable(true) end, 1)
		Logging:Warn("OnEnable(%s) : unable to determine player, rescheduling enable", self:GetName())
		return
	end

	Logging:Debug("%s", Util.Objects.ToString(self.player:toTable()))

	if not self.player:IsClass("SHAMAN") then
		AddOn:Print(
			format(
				L["not_usable_by_x"],
				UIUtil.ClassColorDecorator(self.player:GetClass()):decorate(self.player:GetClassDisplayName())
			)
		)
		self:Disable()
		return
	end

	local configSupplements, lpadSupplements = {}, {}
	for name, module in self:IterateModules() do
		Logging:Debug("OnEnable(%s) : Examining module (startup) '%s'", self:GetName(), name)
		if module:EnableOnStartup() then
			Logging:Debug("OnEnable(%s) : Enabling module (startup) '%s'", self:GetName(), name)
			module:Enable()
		end

		-- extract module's configuration supplement for later application
		local cname, cfn = self:GetConfigSupplement(module)
		if cname and cfn then
			configSupplements[cname] = cfn
		end

		-- support multiple launchpad supplements per module
		Util.Tables.CopyInto(lpadSupplements, self:GeLaunchpadSupplements(module))
	end

	-- track launchpad (UI) supplements for application as needed
	-- will only be applied the first time the UI is displayed
	-- {applied [boolean], configuration supplements [table], launchpad supplements [table]}
	self.supplements = {false, configSupplements, lpadSupplements}

	-- add minimap button
	self:AddMinimapButton()
	self:Print(format(L["chat_version"], tostring(self.version)) .. " is now loaded.")
	-- fire message at end that addon has been enabled
	self:SendMessage(C.Messages.Enabled)
	self:AfterEnabled()
end

function AddOn:OnDisable()
	Logging:Debug("OnDisable(%s)", self:GetName())
	for _, module in self:IterateModules() do
		module:Disable()
	end
end

function AddOn:AfterEnabled()
	Logging:Debug("AfterEnabled(%s)", self:GetName())

	local handle

	local function After()
		Logging:Debug("After()")
		AddOn.Unsubscribe(handle)
		Totems():Initialize()
		self:MacroMediator():Update()
	end

	-- wait for spells to be refreshed before initializing totems
	handle = Message():BulkSubscribe({
		[C.Messages.SpellsRefreshComplete] = function(...) After() end,
	})

	Spells():Enable(true)
end