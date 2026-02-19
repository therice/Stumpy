--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type UI.Native
local UI = AddOn.Require('UI.Native')
--- @type UI.Util
local UIUtil = AddOn.Require('UI.Util')
--- @type LibWindow
local Window = AddOn:GetLibrary('Window')
--- @type Toolbox
local Toolbox = AddOn:GetModule("Toolbox", true)
--- @type Models.Totem.Totems
local Totems = AddOn.RequireOnUse('Models.Totem.Totems')
--- @type Models.Totem.Totem
local Totem = AddOn.Package('Models.Totem').Totem
--- @type Models.Spell.Spells
local Spells = AddOn.RequireOnUse('Models.Spell.Spells')
--- @type LibTotem
local LibTotem = AddOn:GetLibrary("Totem")
--- @type UI.Native.Widget
local BaseWidget = AddOn.ImportPackage('UI.Native').Widget
--- @type Models.Totem.TotemSet
local TotemSet = AddOn.Package('Models.Totem').TotemSet

-- https://github.com/tomrus88/BlizzardInterfaceCode/blob/4334b87a5365523a8d5211fba0819818946a967f/Interface/FrameXML/Cooldown.lua
local CooldownFrame_Set, CooldownFrame_Clear, GetBindingKey = CooldownFrame_Set, CooldownFrame_Clear, GetBindingKey
local ButtonTexture = {
	bgFile =  UI.ResolveTexture("white"),
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = false, tileSize = 8, edgeSize = 2,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
}
local ButtonBorderColor = C.Colors.Marigold

local function InvalidGrow(grow)
	error(format("Invalid grow '%s' (%s)", grow, Util.Objects.ToString(Util.Tables.Values(C.Direction))))
end

local function InvalidLayout(layout)
	error(format("Invalid layout '%s' (%s)", layout, Util.Objects.ToString(Util.Tables.Values(C.Layout))))
end

local KeyBindable = {
	static = {
		buttons = {},
		AddBindableButtons = function(self, buttons)
			for button, description in pairs(buttons) do
				self.buttons[button] = description
			end
		end
	},
	included = function(_, clazz)
		clazz.isKeyBindable = true
	end,
	GetKeyBindName = function(self, button)
		return format('CLICK %s:%s', self._:GetName(), button)
	end,
	BuildKeyBindNames = function(self, ...)
		local names = {}
		for button, description in pairs(self.clazz.static.buttons) do
			names[self:GetKeyBindName(button)] = format(description, ...)
		end
		return names
	end,
	-- only supports left click ATM
	GetHotKey = function(self)
		if Util.Tables.ContainsKey(self.clazz.static.buttons, C.Buttons.Left) then
			return GetBindingKey(self:GetKeyBindName(C.Buttons.Left))
		end

		return nil
	end,
	UpdateHotKey = function(self)
		if self._.hotKey then
			local key = self:GetHotKey()
			--Logging:Warn("UpdateHotKey(%s) : %s", self._:GetName(), tostring(key))
			if Util.Strings.IsSet(key) then
				self._.hotKey:SetText(UIUtil.ToShortKey(key))
				self._.hotKey:Show()
			else
				self._.hotKey:Hide()
			end
		end
	end
}

--- @type UI.Native.FrameContainer
local FrameContainer = AddOn.Package('UI.Native').FrameContainer
--- @class TotemBar
local TotemBar = AddOn.Class('TotemBar', FrameContainer)
--- @class TotemButton
local TotemButton = AddOn.Class('TotemButton', FrameContainer):include(KeyBindable)
TotemButton.static:AddBindableButtons({
  [C.Buttons.Left]  = L['cast_totem'],
  [C.Buttons.Right] = L['dismiss_totem'],
})

--- @class TotemFlyoutButton
local TotemFlyoutButton = AddOn.Class('TotemFlyoutButton', FrameContainer)
--- @class TotemFlyoutBar
local TotemFlyoutBar = AddOn.Class('TotemFlyoutBar', FrameContainer)
--- @class TotemFlyoutBarButton
local TotemFlyoutBarButton = AddOn.Class('TotemFlyoutBarButton', FrameContainer)
--- @class TotemSetButton
local TotemSetButton = AddOn.Class('TotemSetButton', FrameContainer)
--- @class TotemSetBar
local TotemSetBar = AddOn.Class('TotemSetBar', FrameContainer)
--- @class TotemSetBarButton
local TotemSetBarButton = AddOn.Class('TotemSetBarButton', FrameContainer)
--- @class TotemPulseTimer
local TotemPulseTimer = AddOn.Class('TotemPulseTimer', FrameContainer)

-- https://wowpedia.fandom.com/wiki/SecureHandlers
-- https://wowpedia.fandom.com/wiki/SecureActionButtonTemplate

-- TotemBar BEGIN --
function TotemBar:initialize()
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
	--- @type table<number, TotemButton>
	self.buttons = {}
	--- @type TotemSetButton
	self.setButton = TotemSetButton(self)
	self:CreateButtons()
	self:PositionAndSize()
end

function TotemBar:_CreateFrame()
	local f = CreateFrame('Frame', AddOn:Qualify('TotemBar'), UIParent, "BackdropTemplate,SecureHandlerBaseTemplate")
	local storage = AddOn.db and Util.Tables.Get(AddOn.db.profile, 'ui.TotemBar') or {}
	f:EnableMouse(true)
	f:SetScale(storage.scale)
	Window:Embed(f)
	f:RegisterConfig(storage)
	f:RestorePosition()
	f:MakeDraggable()
	return f
end

function TotemBar:GetButtons()
	return self.buttons
end

function TotemBar:GetButton(index)
	return self.buttons[index]
end

--- @param element Models.Totem.Totem|number|string
function TotemBar:GetButtonByElement(element)
	if Util.Objects.IsInstanceOf(element, Totem) then
		element = element:GetElement()
	elseif Util.Objects.IsString(element) then
		element = tonumber(element)
	elseif not Util.Objects.IsNumber(element) then
		error("Specified element is not of the appropriate type")
	end

	local index, _ = Util.Tables.FindFn(
		self.buttons, function(b) return b.element == element end
	)
	--Logging:Debug("GetButtonByElement() : %d (element) => %d (index)", element, index)
	return self:GetButton(index)
end

function TotemBar:EnsureButton(element, spell, order)
	if AddOn:InCombatLockdown() then
		Logging:Warn("Unable to swap totem button positions while in combat. This is a bug and needs addressed.")
		return
	end

	local existing, target = self:GetButtonByElement(element), self:GetButton(order)
	if existing ~= target then
		Logging:Debug("EnsureButton(%d [element], %d [order]) : swapping %d with %d", element, order, existing.element, target.element)
		Util.Functions.try(
			function()
				existing:CapturePoint()
				self:SwapButtons(existing, target)
			end
		).finally(
			function() existing:ClearPoint() end
		)
	end

	local currentSpell = existing:GetSpell()
	Logging:Debug(
		"EnsureButton() : %d (element) %s (current spell) %s (new spell)",
		target.element, tostring(currentSpell), tostring(spell)
	)
	if not currentSpell or not Util.Objects.Equals(currentSpell.id, spell.id) then
		existing:OnSpellSelected(spell)
	end
end

function TotemBar:CreateButton(element)
	return TotemButton(self, element)
end

function TotemBar:CreateButtons()
	Logging:Trace("CreateButtons()")
	for element = 1, LibTotem.Constants.MaxTotems do
		local index = Toolbox:GetElementIndex(element)
		Logging:Trace("CreateButtons() : %d (element) => %d (index)", element, index)
		self.buttons[index] = self:CreateButton(element)
	end
end

--- @param totem Models.Totem.Totem
function TotemBar:UpdateButton(totem)
	self:GetButtonByElement(totem):Update()
end

-- example taints if swapping occurs during combat
--[[
 An action was blocked in combat because of taint from Stumpy - Stumpy_TotemBar_Totem2:ClearAllPoints()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:153 SwapButtons()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:534 OnDragStop()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:280
 An action was blocked in combat because of taint from Stumpy - Stumpy_TotemBar_Totem2:SetPoint()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:154 SwapButtons()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:534 OnDragStop()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:280
 An action was blocked in combat because of taint from Stumpy - Stumpy_TotemBar_Totem1:ClearAllPoints()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:156 SwapButtons()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:534 OnDragStop()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:280
 An action was blocked in combat because of taint from Stumpy - Stumpy_TotemBar_Totem1:SetPoint()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:157 SwapButtons()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:534 OnDragStop()
     Interface\AddOns\Stumpy\Modules\UI\Toolbox.lua:280
--]]
--- @param one TotemButton
--- @param two TotemButton
function TotemBar:SwapButtons(one, two)
	local idOne, idTwo = one._:GetID(), two._:GetID()
	Logging:Trace("SwapButtons(%d, %d)", idOne, idTwo)

	local pointOne, xOne, yOne =  unpack(one.point)
	local pointTwo, _, _, xTwo, yTwo = two._:GetPoint()

	one._:ClearAllPoints()
	one._:SetPoint(pointTwo, xTwo, yTwo)

	two._:ClearAllPoints()
	two._:SetPoint(pointOne, xOne, yOne)

	local buttons = self:GetButtons()
	local indexOne = Util.Tables.Find(buttons, one)
	local indexTwo = Util.Tables.Find(buttons, two)

	Logging:Trace("SwapButtons(%d, %d) : (%d, %d) [indices]", idOne, idTwo, indexTwo, indexOne)
	buttons[indexOne] = two
	buttons[indexTwo] = one
end

function TotemBar:PositionAndSize()
	local size, spacing, grow = Toolbox:GetBarSettings()
	local pulseSize = Toolbox:GetPulseSize()

	local buttonCount = #self.buttons

	self.setButton:PositionAndSize(size, spacing, grow)

	for i=1, buttonCount do
		local button = self.buttons[i]
		button:PositionAndSize(i, size, spacing, grow, pulseSize)
	end

	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self._:SetWidth((size * buttonCount) + (spacing * buttonCount) + (pulseSize * buttonCount) + spacing)
		self._:SetHeight(size + spacing * 2)
	elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
		self._:SetHeight((size * buttonCount) + (spacing * buttonCount)  + (pulseSize * buttonCount) + spacing)
		self._:SetWidth(size + spacing * 2)
	else
		InvalidGrow(grow)
	end
end

--- @param element number
--- @param spell number
function TotemBar:OnSpellSelected(element, spell)
	self:GetButtonByElement(element):OnSpellSelected(spell)
end

function TotemBar:OnSetActivated(id)
	--- @type Models.Totem.TotemSet
	local set = Toolbox.totemSets:Get(id)
	if not set then return end

	-- if we're in combat lockdown, don't perform the actual
	-- activation, update display to show it's pending and it will
	-- be handled after combat exits
	if AddOn:InCombatLockdown() then
		self.setButton:SetPending(set)
	else
		-- clear the pending marker, we're going to actually activate
		self.setButton:SetPending(nil)

		local order = 1
		for element, spell in set:OrderedIterator() do
			Logging:Debug("Element(%d) => Position (%d) / Spell (%d)", element, order, spell)
			self:EnsureButton(element,  Spells():GetById(spell) , order)
			order = order + 1
		end
	end
end

function TotemBar:OnSetUpdated()
	self.setButton.bar:UpdateButtons()
end

local function SetSpellAttribute(button, spellId)
	if not Util.Objects.IsEmpty(button) and not Util.Objects.IsEmpty(spellId) then
		-- GetSpellInfo = name, iconID, originalIconID, castTime, minRange, maxRange, spellId
		-- GetSpellInfo(10437) => "Searing Totem", nil, 135825, 0, 0, 0, 10437
		local spellName = select(1, GetSpellInfo(spellId))
		Logging:Debug("SetSpellAttribute() : spellId=%s, spellName=%s", tostring(spellId), tostring(spellName))
		button:SetAttribute("spellname", spellName)
		button:SetAttribute("spellid", spellId)
		button:SetAttribute("macrotext", "/cast " .. spellName)
		--button:SetAttribute("*spell1", spellName)
		--button:SetAttribute("spell1", spellName)
		--button:SetAttribute("spell", spellName)
		--button:SetAttribute("macrotext1", "/cast " .. spellName)
		--button:SetAttribute("inactive", false)
	end
end

-- TotemBar END --

-- TotemButton BEGIN --
--- @param parent TotemBar
--- @param element number
function TotemButton:initialize(parent, element)
	--- @type TotemBar
	self.parent = parent
	--- @type number
	self.element = element
	-- tracks whether there is pending change to associated spell
	--- @type boolean
	self.pendingChange = false
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
	self:UpdateHotKey()

	--- @type TotemFlyoutButton
	self.flyoutButton = TotemFlyoutButton(self)
	--- @type TotemFlyoutBar
	self.flyoutBar = TotemFlyoutBar(self)
	--- @type TotemPulseTimer
	self.pulseTimer = TotemPulseTimer(self)
end

function TotemButton:__tostring()
	return format("TotemButton(%d)", self.element)
end

function TotemButton:GetKeyBindNames()
	return self:BuildKeyBindNames(LibTotem.Constants.Totems.ElementIdToName[self.element])
end

--- @return TotemFlyoutBar
function TotemButton:GetFlyoutBar()
	return self.flyoutBar
end

--- @return boolean is there a pending change for associated spell
function TotemButton:HasPendingChange()
	return self.pendingChange
end

--- @return number the associated element (e.g. EARTH)
function TotemButton:GetElement()
	return self.element
end

--- @return boolean indicating if associated totem is present (cast with remaining time)
function TotemButton:IsPresent()
	return Totems():Get(self:GetElement()):IsPresent()
end

--- @return string
function TotemButton:GetName()
	return Util.Strings.Join('_', self.parent:GetFrameName(), 'Totem' .. tostring(self.element))
end

function TotemButton:_SetSpellAttributes(spellId)
	SetSpellAttribute(self._, spellId)
end

function TotemButton:GetSpellId()
	local spellId = self._:GetAttribute("spellid")
	return spellId and tonumber(spellId) or nil
end

--- @return Models.Spell.Spell
function TotemButton:GetSpell()
	local spellId = self:GetSpellId()
	if spellId then
		return Spells():GetById(spellId)
	end

	return nil
end

--- @return string
function TotemButton:GetSpellName()
	local spell = self:GetSpell()
	if spell then
		return spell:GetName()
	end

	return nil
end

--[[
local tc = false
function TotemButton:_CreateTestFrame()
	if not tc then
		-- Create a plain, non-secure button for testing
		local button = CreateFrame("Button", self:GetName() .. "_Test", UIParent, "BackdropTemplate, SecureActionButtonTemplate")
		button:SetID(10000 + self.element)
		button:SetSize(50, 50)
		button:SetPoint("CENTER")
		button:EnableMouse(true)
		button:RegisterForClicks("AnyDown")
		button:Show()

		button:SetBackdrop(ButtonTexture)
		button:SetBackdropColor(0, 0, 0, 1)

		button:SetAttribute("type", "macro")
		button:SetAttribute("macrotext", "/cast Searing Totem")

		--button:SetAttribute("totem-slot", self.element)
		--button:SetAttribute("*type2", "macro")
		button:SetAttribute("type2", "macro")
		--button:SetAttribute("totem-slot", self.element)
		--button:SetAttribute("*macrotext2", string.format("/script DestroyTotem(%d)", self.element))
		button:SetAttribute("macrotext2", string.format("/script DestroyTotem(%d)", self.element))

		-- Optional: show the button name in the center
		local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		label:SetPoint("CENTER")
		label:SetText(self:GetName())

		button:SetScript("PreClick", function(self, buttonClicked)
			print("DEBUG PreClick:", self:GetName(), "button:", buttonClicked)
			print("DEBUG attributes at click:",
			      "type=", self:GetAttribute("type1"),
			      "macrotext=", self:GetAttribute("macrotext1")
			)
		end)
		button:SetScript("OnAttributeChanged", function(...) self:OnAttributeChanged(...) end)

		tc = true

	end
end
--]]
function TotemButton:_CreateFrame()
	local button = CreateFrame(
		'Button', self:GetName(), self.parent:GetFrame(),
		"BackdropTemplate,SecureHandlerBaseTemplate,SecureHandlerStateTemplate,SecureActionButtonTemplate"
	)
	button:SetID(self.element)
	button:SetBackdrop(ButtonTexture)
	button:SetBackdropColor(0, 0, 0, 1)
	button:SetBackdropBorderColor(0, 0, 0, 1)
	button:EnableMouse(true)
	button:RegisterForClicks("AnyDown")

	button.icon = button:CreateTexture(nil, 'ARTWORK')
	button.icon:SetTexCoord(unpack({0.08, 0.92, 0.08, 0.92}))
	UI.SetInside(button.icon)

	button.pending = button:CreateTexture(nil, 'ARTWORK')
	button.pending:SetTexCoord(unpack({0.08, 0.92, 0.08, 0.92}))
	button.pending:Hide()

	button.cooldown = CreateFrame('Cooldown', button:GetName() .. '_Cooldown', button, 'CooldownFrameTemplate')
	button.cooldown:SetAllPoints()
	button.cooldown:SetReverse(true)
	button.cooldown:SetFrameStrata(button:GetFrameStrata())
	button.cooldown:SetFrameLevel(button:GetFrameLevel() + 2)
	UI.SetInside(button.cooldown)

	button.hotKey = button:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmallGray")
	button.hotKey:SetDrawLayer("OVERLAY")
	button.hotKey:SetFont(button.hotKey:GetFont(), 13, "OUTLINE")
	button.hotKey:SetVertexColor(0.75, 0.75, 0.75)
	button.hotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -4)

	-- dropped this in favor of putting the affected status on flyout button
	--[[
	button.count = button:CreateFontString(nil, "ARTWORK", BaseWidget.FontNormalName)
	button.count:SetJustifyH("MIDDLE")
	button.count:SetJustifyV("MIDDLE")
	button.count:Hide()
	--]]

	-- === ADD DEBUG HOOKS ONLY ===
	button:SetScript("PreClick", function(self, buttonClicked)
		Logging:Trace("TotemButton(PreClick) : %s button=%s", self:GetName(), "button:", buttonClicked)
		Logging:Trace("TotemButton(PreClick) : attributes(1) type=%s macrotext=%s", self:GetAttribute("type"), self:GetAttribute("macrotext"))
		Logging:Trace("TotemButton(PreClick) : attributes(2) type=%s macrotext=%s", self:GetAttribute("type2"), self:GetAttribute("macrotext2"))
	end)

	--- on left click, cast totem for associated element
	button:SetAttribute("type", "macro")
	-- This will be provided later based upon spell id (totem)
	-- button:SetAttribute("macrotext", "/cast Searing Totem")

	--- on right click, destroy totem for associated element
	button:SetAttribute("type2", "macro")
	--button:SetAttribute("totem-slot", self.element)
	button:SetAttribute("macrotext2", string.format("/script DestroyTotem(%d)", self.element))

	-- allow button to be moved and swapped with others
	button:SetMovable(true)
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnDragStart", function() self:OnDragStart() end)
	button:SetScript("OnDragStop", function() self:OnDragStop() end)
	button:SetScript("OnAttributeChanged", function(...) self:OnAttributeChanged(...) end)
	button:Show()

	--self:_CreateTestFrame()
	return button
end

--- updates the button based upon associated element's totem, with following priority/order
---  (1) any present totem (spell) for the element
---  (2) any configured totem (spell) for the element (for active totem set)
function TotemButton:Update()
	local totem = Totems():Get(self.element)
	if Util.Objects.IsNil(totem) then
		Logging:Warn("Update(%d) : specified totem is not available for the associated element", self.element)
		return
	end

	local inCombat = AddOn:InCombatLockdown()
	-- grab a reference to spell based upon the totem (game event) or totem set (user configured)
	--- @type Models.Spell.Spell
	local spell
	if totem:IsPresent() then
		spell = totem:GetSpell()
	else
		_, spell = Toolbox:GetTotemSet():Get(self.element)
	end

	Logging:Debug(
		"UpdateButton(%d) : %s (present), %s (in combat) %s (spell)",
		self.element, tostring(totem:IsPresent()), tostring(inCombat), tostring(spell)
	)

	-- if not in combat, we can set the spell attribute which will
	-- result in the callback doing the needful with icon, cooldown, etc
	if not inCombat then
		self:_SetSpellAttributes(spell and spell.id or nil)
		-- if the totem is present, don't clear the pending spell
		-- it could be different than current one
		if not totem:IsPresent() then
			self:SetPending(nil)
		end
	-- cannot modify the 'spell' attribute while in combat, so perform updates directly
	else
		self:OnSpellActivated(spell)
	end
end

-- this is called as a result of a spell being "activated", which infers one of the following
--  (1) a totem event was generated as a result of it being cast
--  (2) a spell will be cast as a result of the button being "clicked"
function TotemButton:OnSpellActivated(spell)
	Logging:Debug("OnSpellActivated(%s)", tostring(spell))
	self:UpdateIcon(spell)
	self:UpdateCooldown()
	self:UpdatePulseTimer()
	self:UpdateAffectedCount()
end

function TotemButton:UpdateIcon(spell)
	Logging:Trace("UpdateIcon(%s)", tostring(spell))
	self._.icon:SetTexture(spell and spell:GetIcon() or nil)
	self._.icon:SetDesaturated(Util.Objects.Check(spell, nil, 1))
end

function TotemButton:UpdateCooldown()
	local totem = Totems():Get(self.element)
	if totem:IsPresent() then
		CooldownFrame_Set(self._.cooldown, totem:GetStartTime(), totem:GetDuration(), 1, true, 1)
	else
		CooldownFrame_Clear(self._.cooldown)
	end
end

function TotemButton:UpdateAffectedCount()
	local totem = Totems():Get(self.element)

	---  @param counts Optional<table<number>>
	local function UpdateDisplay(counts)
		Logging:Trace("UpdatePlayerCount.UpdateDisplay(%d) : %s", self.element, tostring(counts or -1))
		counts = counts or Util.Optional.empty()
		counts:ifPresentOrElse(
			function(v)
				local affected, candidates = unpack(v)
				self.flyoutButton._:SetText(tostring(affected) .. "/" .. tostring(candidates))
				--self._.count:SetText(tonumber(affected) .. "/" .. tostring(candidates))
				--self._.count:Show()
			end,
			function()
				self.flyoutButton._:SetText("")
				--self._.count:Hide()
			end
		)
	end

	--- cancels any
	local function CancelTimer()
		if self.affectedTimer then
			Logging:Trace("UpdatePlayerCount.CancelTimer(%d)", self.element)
			Toolbox:CancelTimer(self.affectedTimer)
			self.affectedTimer = nil
		end
	end

	local function StartTimer()
		if not self.affectedTimer then
			Logging:Trace("UpdatePlayerCount.StartTimer(%d)", self.element)
				AddOn.Timer.After(
					0,
					function()
						CancelTimer()
						self.affectedTimer = Toolbox:ScheduleRepeatingTimer(
							function()
								UpdateDisplay(totem:GetAffected())
							end,
							0.5
						)
					end
				)
		end
	end

	if totem:IsPresent() and totem:IsAffectedUnitUpdateScheduled() then
		StartTimer()
	else
		CancelTimer()
		UpdateDisplay()
	end
end

function TotemButton:UpdatePulseTimer()
	local totem = Totems():Get(self.element)
	local pulse = totem:IsPresent() and totem:GetPulse() or 0

	if pulse > 0 then
		-- pass along the time the totem was summoned when starting pulse timer
		self.pulseTimer:Start(pulse, totem:GetStartTime())
	else
		-- not present, just cancel any pulse timer
		self.pulseTimer:Cancel()
	end
end

function TotemButton:SetPending(spell)
	self.pendingChange = not Util.Objects.IsNil(spell)

	-- nothing pending, hide the associated texture
	if not self:HasPendingChange() then
		self._.pending:Hide()
		return
	end

	-- update the pending texture with spell
	self._.pending:SetTexture(spell:GetIcon())
	self._.pending:Show()
end

-- this is called as a result of a spell being "selected", which infers one of the following
--  (1) the active totem set was modified for the associated element, regardless of mechanism (flyout bar or configuration)
function TotemButton:OnSpellSelected(spell)
	local inCombat, totem = AddOn:InCombatLockdown(), Totems():Get(self.element)
	Logging:Debug(
		"OnSpellSelected(%d) : %s (in combat) %s (totem) %s (spell)",
		self.element, tostring(inCombat), tostring(totem), tostring(spell)
	)

	local currentSpell = Util.Objects.Default(self._:GetAttribute("spellid"), -1)
	if currentSpell == spell.id then
		Logging:Info("OnSpellSelected(%d) : spell has not changed, doing nothing", spell.id)
		return
	end

	-- if we're in combat, don't modify any state until we exit combat
	-- just show the selection as pending
	if inCombat then
		self:SetPending(spell)
	else
		-- if the totem is present, regardless of combat status,
		-- set the selected spell as pending
		-- this allows for current cast spell to retain priority until it elapses
		if totem:IsPresent() then
			self:SetPending(spell)
		-- we can activate the selected spell immediately
		else
			self:_SetSpellAttributes(spell.id)
		end
	end
end

--- SetAttribute calls result in this being fired, which does not infer combat state
--- as you can set non-reserved attributes on protected frames during combat, but cannot set
--- reserved attributes during combat (i.e. spell, macrotext)
function TotemButton:OnAttributeChanged(_--[[ frame --]], key, value)
	Logging:Trace("OnAttributeChanged(%s) : %s = %s", self:GetName(), tostring(key), Util.Objects.ToString(value))
	if Util.Objects.In(key, "spellid", "selectedspell") then
		local spell
		if Util.Objects.IsNumber(value) then
			spell = Spells():GetById(value)
		end

		Logging:Debug("OnAttributeChanged(%s) : %s = %s (found spell = %s)",  self:GetName(), tostring(key), tostring(value), tostring(Util.Objects.IsSet(spell)))

		if Util.Strings.Equal(key, "spellid") then
			self:OnSpellActivated(spell)
		elseif Util.Strings.Equal(key, "selectedspell") then
			-- just update the totem set and rely upon event callbacks to handle based upon state
			Toolbox:SetElementSpell(self.element, spell)
		end
	end
end

function TotemButton:PositionAndSize(index, size, spacing, grow, pulseSize)
	self._:SetSize(size, size)
	self._:ClearAllPoints()

	self._.pending:SetSize(size/2, size/2)
	self._.pending:ClearAllPoints()

	--self._.count:SetSize(size/2, size/2)
	--self._.count:ClearAllPoints()

	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self._:SetPoint('LEFT', (((index - 1) * size) + (index * spacing) + ((index - 1) * pulseSize)), 0)
		self._.pending:SetPoint("TOPRIGHT", self._, "BOTTOMRIGHT", 0, -spacing/2)
	elseif Util.Objects.Equals(grow, C.Direction.Vertical)then
		self._:SetPoint('TOP', 0, -(((index - 1) * size) + (index * spacing)+ ((index - 1) * pulseSize)))
		self._.pending:SetPoint("BOTTOMRIGHT", self._, "BOTTOMLEFT", -spacing/2, 0)
	else
		InvalidGrow(grow)
	end

	self.flyoutButton:PositionAndSize(size, spacing, grow)
	self.pulseTimer:PositionAndSize(size, spacing, grow, pulseSize)
end

function TotemButton:RestorePosition()
	self._:ClearAllPoints()
	self._:SetPoint(self.point[1], self.point[2], self.point[3])
end

function TotemButton:CapturePoint()
	local point, _, _, x, y = self._:GetPoint()
	self.point = {point, x, y}
end

function TotemButton:ClearPoint()
	self.point = nil
end

function TotemButton:OnDragStart()
	--- cannot reposition existing UI elements during combat, see logging detail above SwapButtons()
	if not AddOn:InCombatLockdown() and IsShiftKeyDown() then
		self:CapturePoint()
		Logging:Debug("OnDragStart(%d) : %s", self._:GetID(), Util.Objects.ToString(self.point))
		self._:StartMoving()
	end
end

function TotemButton:OnDragStop()
	if not Util.Objects.IsNil(self.point) then
		Logging:Debug("OnDragStop(%d, %s)", self._:GetID(), Util.Objects.ToString(self.point))
		self._:StopMovingOrSizing()

		local buttons, target = self.parent:GetButtons(), nil
		for i = 1, #buttons do
			local candidate = buttons[i]
			if candidate._:IsMouseOver() and candidate ~= self then
				Logging:Trace("%d => %s", candidate._:GetID(), Util.Objects.ToString({candidate._:GetPoint()}))
				target = candidate
				break
			end
		end

		if target then
			self.parent:SwapButtons(self, target)
			Toolbox:SetElementIndices()
		else
			self:RestorePosition()
		end

		-- nil it out at end as we use it as indicator that frame is being dragged
		self:ClearPoint()
	end
end
-- TotemBarButton END --

-- TotemFlyoutButton START --
---- @param parent TotemButton
function TotemFlyoutButton:initialize(parent)
	--- @type TotemButton
	self.parent = parent
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
end

function TotemFlyoutButton:GetElement()
	return self.parent.element
end

--- @return string
function TotemFlyoutButton:GetName()
	return Util.Strings.Join('_', self.parent:GetFrameName(), 'FlyoutButton')
end

function TotemFlyoutButton:_CreateFrame()
	local button = UI:NewNamed('Button', self.parent:GetFrame(), self:GetName(), nil, "BackdropTemplate,SecureHandlerStateTemplate,SecureHandlerClickTemplate")
	button.text:SetFont(TextStatusBarText:GetFont())
	button.text:SetTextColor(C.Colors.LuminousYellow:GetRGB())
	button.Texture:SetColorTexture(C.Colors.MageBlue:GetRGB())
	button.HighlightTexture:SetColorTexture(C.Colors.MageBlue:GetRGB())
	BaseWidget.Textures.SetGradientAlpha(button.HighlightTexture, "VERTICAL", 0.05, 0.06, 0.09, 1, 0.20, 0.21, 0.25, 1)
	button:RegisterForClicks("LeftButtonDown")

	-- this is all about showing/hiding flyouts
	--
	-- parent <- child hierarchy
	-- totem button (ref to flyoutBar) <- flyout button (self)
	-- totem bar (ref to all flyoutBar(s) by name) <- totem button (attribute for name of active flyoutBar) <- flyout button (self)
	button:SetAttribute("_onclick",[[
		local totemButton = self:GetParent()
		local totemBar = totemButton:GetParent()

		-- reference to the flyoutBar bound to this button
		local flyoutBar = totemButton:GetFrameRef("flyoutBar")
		-- reference to the flyoutBar's name which is currently active (shown)
		local flyoutBarActive = totemBar:GetAttribute("flyoutBarActive")

		-- if we have an active flyoutBar, hide it before any action on current one
		if flyoutBarActive then
			local toHide = totemBar:GetFrameRef(flyoutBarActive)
			if toHide and toHide:GetName() ~= flyoutBar:GetName() and toHide:IsVisible() then
				toHide:Hide()
			end
		end

		if flyoutBar then
			if flyoutBar:IsVisible() then
				flyoutBar:Hide()
				totemBar:SetAttribute("flyoutBarActive", nil)
			else
				flyoutBar:Show()
				totemBar:SetAttribute("flyoutBarActive", flyoutBar:GetName())
			end
		end
	]])

	button:Show()

	return button
end

function TotemFlyoutButton:PositionAndSize(size, _, grow)
	self._:ClearAllPoints()
	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self._:SetSize(size, size/5)
		self._:SetPoint('BOTTOMLEFT', self._:GetParent(), 'TOPLEFT', 0, 5)
	elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
		self._:SetSize(size/5, size)
		self._:SetPoint('TOPLEFT', self._:GetParent(), 'TOPRIGHT', 5, 0)
	else
		InvalidGrow(grow)
	end
end
-- TotemFlyoutButton END --

-- TotemFlyoutBar START --
-- 3 rows with 3 columns in each row
-- todo : make this dynamic based upon layout
local FlyoutRows, FlyoutColumns = 3, 3
local FlyoutMaxButtons =  FlyoutRows * FlyoutColumns

--- @param parent TotemButton
function TotemFlyoutBar:initialize(parent)
	self.parent = parent
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
	--- @type table<number, TotemFlyoutBarButton>
	self.buttons = {}
	self:CreateButtons()
	self:PositionAndSize()
	self:UpdateButtons()
	self:Hide()
end

function TotemFlyoutBar:GetElement()
	return tonumber(self.parent.element)
end

--- @return string
function TotemFlyoutBar:GetName()
	return Util.Strings.Join('_', self.parent:GetFrameName(), 'FlyoutBar')
end

function TotemFlyoutBar:_CreateFrame()
	local f = CreateFrame('Frame', self:GetName(), self.parent:GetFrame(), "BackdropTemplate,SecureHandlerBaseTemplate,SecureHandlerShowHideTemplate")
	-- set a reference to this frame, by static id, on the TotemButton (parent)
	self.parent._:SetFrameRef("flyoutBar", f)
	-- set a reference to this frame, by name, on the TotemBar (parent's parent)
	self.parent.parent._:SetFrameRef(f:GetName(), f)
	return f
end

function TotemFlyoutBar:CreateButtons()
	for index = 1, FlyoutMaxButtons do
		self.buttons[index] = TotemFlyoutBarButton(self, index)
	end
end

function TotemFlyoutBar:PositionAndSize()
	local size, spacing, layout = Toolbox:GetFlyoutSettings()
	local grow = Toolbox:GetBarGrow()
	local buttonCount = #self.buttons

	if Util.Objects.Equals(layout, C.Layout.Grid) then
		self._:SetHeight(FlyoutRows * (size + spacing))
		self._:SetWidth(FlyoutColumns * (size + spacing))
	elseif Util.Objects.Equals(layout, C.Layout.Column) then
		if Util.Objects.Equals(grow, C.Direction.Horizontal) then
			self._:SetHeight((size * buttonCount) + (spacing * buttonCount) + spacing)
			self._:SetWidth(size + spacing * 2)
		elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
			self._:SetWidth((size * buttonCount) + (spacing * buttonCount) + spacing)
			self._:SetHeight(size + spacing * 2)
		else
			InvalidGrow(grow)
		end
	else
		InvalidLayout(layout)
	end

	-- it should be relative to the flyout bar button
	self:Reposition(self.parent.flyoutButton._)

	for i=1, buttonCount do
		self.buttons[i]:PositionAndSize(size, spacing, grow, layout)
	end
end

function TotemFlyoutBar:Reposition(at)
	local grow, spacing = Toolbox:GetBarGrow(), Toolbox:GetFlyoutButtonSpacing()
	--self._:SetParent(at)
	self._:ClearAllPoints()

	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self._:SetPoint('BOTTOM', at, "TOP", spacing, 0)
	elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
		self._:SetPoint('LEFT', at, "RIGHT", 0, spacing)
	else
		InvalidGrow(grow)
	end
end

function TotemFlyoutBar:UpdateButtons()
	local element = self:GetElement()
	Logging:Trace("UpdateButtons(%d)", element)

	if element <= 0 then
		for index = 1, #self.buttons do
			self.buttons[index]:Hide()
		end
	else
		local spells = Toolbox:GetSpellsByTotem(element)
		local spellCount, buttonCount = #spells, #self.buttons

		if spellCount > buttonCount then
			Logging:Warn("UpdateButtons(%d) : spell count exceeds available buttons", element)
		elseif spellCount == 0 then
			Logging:Warn("UpdateButtons(%d) : no available spells", element)
		else
			Logging:Trace("UpdateButtons(%d) : %d (spells) %d (buttons)", element, spellCount, buttonCount)
		end

		for index, spell in pairs(spells) do
			self.buttons[buttonCount - (index - 1)]:SetSpell(spell)
		end

		for hideIndex = (buttonCount - spellCount), 1, -1 do
			self.buttons[hideIndex]:SetSpell(nil)
		end

		for index = 1, buttonCount do
			self.buttons[index]:Update()
		end
	end
end

-- TotemFlyoutBar END --

-- TotemFlyoutBarButton START --
--- @param parent TotemFlyoutBar
--- @param index number
function TotemFlyoutBarButton:initialize(parent, index)
	--- @type TotemFlyoutBar
	self.parent = parent
	--- @type number
	self.index = index
	--- @type Models.Spell.Spell
	self.spell = nil
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
end

function TotemFlyoutBarButton:GetName()
	return Util.Strings.Join('_', self.parent:GetFrameName(), 'Button' .. tostring(self.index))
end

function TotemFlyoutBarButton:_CreateFrame()
	local button = CreateFrame('Button', self:GetName(), self.parent:GetFrame(), "BackdropTemplate,SecureHandlerBaseTemplate,SecureActionButtonTemplate")
	button:SetBackdrop(ButtonTexture)
	button:SetBackdropColor(0, 0, 0, 1)
	button:SetBackdropBorderColor(0, 0, 0, 1)
	button:SetID(self.index)

	button.icon = button:CreateTexture(nil, 'ARTWORK')
	button.icon:SetTexCoord(unpack({0.08, 0.92, 0.08, 0.92}))
	UI.SetInside(button.icon)

	BaseWidget.Border(button, ButtonBorderColor.r, ButtonBorderColor.g, ButtonBorderColor.b, ButtonBorderColor.a, 1, 1, 1)

	-- any up event is a click
	button:RegisterForClicks("AnyDown")

	-- === ADD DEBUG HOOKS ONLY ===
	button:SetScript("PreClick", function(self, buttonClicked)
		Logging:Trace("TotemButton(PreClick) : %s button=%s", self:GetName(), "button:", buttonClicked)
		Logging:Trace("TotemButton(PreClick) : attributes(1) type=%s macrotext=%s",tostring(self:GetAttribute("type")), tostring(self:GetAttribute("macrotext")))
		--Logging:Trace("TotemButton(PreClick) : attributes(2) type=%s macrotext=%s", self:GetAttribute("type2"), self:GetAttribute("_selectSpell"))
	end)


	-- on left click, cast totem for associated spell
	button:SetAttribute("type", "macro")
	button:SetScript(
		'OnShow',
		function()
			if Util.Objects.IsNil(self.spell) then
				button:HideBorders()
				return
			end

			local _, setSpell = Toolbox:GetTotemSet():Get(self.parent.parent:GetElement())
			if Util.Objects.IsSet(setSpell) and Util.Objects.Equals(self.spell:GetId(), setSpell:GetId()) then
				button:ShowBorders()
			else
				button:HideBorders()
			end

		end
	)

	button:SetScript('OnEnter', function() if self.spell then UIUtil.Link(self._, self.spell.link) end end)
	button:SetScript('OnLeave', function() if self.spell then UIUtil:HideTooltip() end end)

	-- this maps right click to selecting the associated spell for the main button
	-- it does NOT cast the spell, only designates it for being the new spell for the associated totem
	-- if in combat, it will queue the replacement
	-- if not in combat, it will update the underlying totem set
	button:SetAttribute("type2", "selectSpell")
	button:SetAttribute("_selectSpell", [[
		-- print('_selectSpell(' .. self:GetAttribute('spellid') .. ')')
		-- the flyoutBar to which this button is bound
		local flyoutBar = self:GetParent()
		-- the totem button to which the flyoutBar is bound
		local totemButton = flyoutBar:GetParent()
		totemButton:SetAttribute('selectedspell', self:GetAttribute('spellid'))
	]])

	button:WrapScript(button, "PostClick", [[ self:GetParent():Hide() ]])
	return button
end

function TotemFlyoutBarButton:Hide()
	self.spell = nil
	TotemFlyoutBarButton.super.Hide(self)
end

--- @param spell Models.Spell.Spell
function TotemFlyoutBarButton:SetSpell(spell)
	Logging:Trace("SetSpell(%d) : %s", self._:GetID(), Util.Objects.ToString(spell and spell:toTable() or 'NONE'))
	self.spell = spell
end

-- should be fine to call SetAttribute() on the action here, as this is called once per button
-- when the associated flyout bar is created. the caveat would be when spells change, which would need
-- to rebuild all the buttons. however, that should also not occur in combat and is a result of (un)learning
-- a new spell or rang from trainer
function TotemFlyoutBarButton:Update()
	--self._:SetAttribute("spell", self.spell and self.spell.id or nil)
	SetSpellAttribute(self._, self.spell and self.spell.id or nil)
	self._.icon:SetTexture(self.spell and self.spell:GetIcon() or nil)
	if self.spell then
		self:Show()
	else
		self:Hide()
	end
end

-- Grid Layout with Horizontal Grow
--[[ index (row, column)
01 (0,0)    02 (0,1)    03  (0,2)
04 (1,0)    05 (1,1)    06  (1,2)
07 (2,0)    08 (2,1)    09  (2,2)
--]]
function TotemFlyoutBarButton:PositionAndSize(size, spacing, grow, layout)
	Logging:Trace("PositionAndSize(%d, %d, %s)", size, spacing, grow)
	self._:SetSize(size, size)
	self._:ClearAllPoints()

	if Util.Objects.Equals(layout, C.Layout.Column) then
		local index
		if Util.Objects.Equals(grow, C.Direction.Horizontal) then
			index = self.index
			self._:SetPoint('TOP', 0, -(((index - 1) * size) + (spacing * index)))
		elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
			index = FlyoutMaxButtons - self.index
			self._:SetPoint('LEFT', ((index) * size) + (spacing * index), 0)
		else
			InvalidGrow(grow)
		end
	elseif Util.Objects.Equals(layout, C.Layout.Grid) then
		-- LUA uses 1 based indexing, not 0 (which we want to use, so subtract 1)
		local row = math.floor((self.index - 1) / FlyoutColumns)
		local column = math.floor((self.index - 1) % FlyoutColumns)
		local x = math.floor((column * size) + (column * spacing))
		local y = math.floor((row * size) + (row * spacing))
		Logging:Trace(
			"PositionAndSize(%d) : (row=%d, col=%d) (x=%d, y=%d)",
			self.index, row, column, x, y
		)

		if Util.Objects.Equals(grow, C.Direction.Horizontal) then
			self._:SetPoint('TOPLEFT', x, -y)
		elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
			self._:SetPoint('BOTTOMRIGHT', -y, x)
		else
			InvalidGrow(grow)
		end
	end
end
-- TotemFlyoutBarButton END --

-- TotemSetButton START --
---- @param parent TotemBar
function TotemSetButton:initialize(parent)
	--- @type TotemBar
	self.parent = parent
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
	self.bar = TotemSetBar(self)
end

--- @return string
function TotemSetButton:GetName()
	return Util.Strings.Join('_', self.parent:GetFrameName(), 'SetButton')
end

function TotemSetButton:_CreateFrame()
	local button = UI:NewNamed('Button', self.parent:GetFrame(), self:GetName(), nil, "BackdropTemplate,SecureHandlerClickTemplate, SecureHandlerStateTemplate")
	button.Texture:SetColorTexture(C.Colors.Cream:GetRGB())
	button.HighlightTexture:SetColorTexture(C.Colors.Cream:GetRGB())
	BaseWidget.Textures.SetGradientAlpha(button.HighlightTexture, "VERTICAL", 0.05, 0.06, 0.09, 1, 0.20, 0.21, 0.25, 1)
	button:RegisterForClicks("LeftButtonDown")

	-- for any pending activation of a totem set
	button.pending = button:CreateTexture(nil, 'ARTWORK')
	button.pending:SetTexCoord(unpack({0.08, 0.92, 0.08, 0.92}))
	button.pending:Hide()

	button:SetAttribute("_onclick",[[
		-- reference to the setBar bound to this button
		local setBar = self:GetFrameRef("setBar")

		if setBar then
			if setBar:IsVisible() then
				setBar:Hide()
			else
				setBar:Show()
			end
		end
	]])

	button:Show()
	return button
end

function TotemSetButton:PositionAndSize(size, _, grow)
	self._:ClearAllPoints()

	self._.pending:SetSize(size/2.5, size/2.5)
	self._.pending:ClearAllPoints()

	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self._:SetSize(size/5, size)
		self._:SetPoint('RIGHT', self._:GetParent(), 'LEFT', -5, 0)
		self._.pending:SetPoint("BOTTOM", self._, "TOP", 0, 2)
	elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
		self._:SetSize(size, size/5)
		self._:SetPoint('BOTTOM', self._:GetParent(), 'TOP', 0, 5)
		self._.pending:SetPoint("LEFT", self._, "RIGHT", 2, 0)
	else
		InvalidGrow(grow)
	end
end

--- @param set Models.Totem.TotemSet
function TotemSetButton:SetPending(set)
	if not set then
		self._.pending:Hide()
	else
		self._.pending:SetTexture(set:GetIcon())
		self._.pending:Show()
	end
end

-- TotemSetButton END --

-- TotemSetBar START --
-- todo : make this dynamic based upon layout
local SetRows, SetColumns = 3, 3
local SetMaxButtons = SetRows * SetColumns

--- @param parent TotemSetButton
function TotemSetBar:initialize(parent)
	self.parent = parent
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
	--- @type table<number, TotemSetBarButton>
	self.buttons = {}
	self:CreateButtons()
	self:PositionAndSize()
	self:UpdateButtons()
	self:Hide()
end

--- @return string
function TotemSetBar:GetName()
	return Util.Strings.Join('_', self.parent.parent:GetFrameName(), 'SetBar')
end

function TotemSetBar:_CreateFrame()
	local f = CreateFrame('Frame', self:GetName(), self.parent:GetFrame(), "BackdropTemplate,SecureHandlerBaseTemplate,SecureHandlerStateTemplate,SecureHandlerShowHideTemplate")
	f:SetScript("OnAttributeChanged", function(...) self:OnAttributeChanged(...) end)
	-- set a reference to this frame, by static id, on the TotemSetButton (parent)
	self.parent._:SetFrameRef("setBar", f)
	return f
end

function TotemSetBar:CreateButtons()
	for index = 1, SetMaxButtons do
		self.buttons[index] = TotemSetBarButton(self, index)
	end
end

function TotemSetBar:PositionAndSize()
	local size, spacing, layout = Toolbox:GetSetSettings()
	local grow = Toolbox:GetBarGrow()
	local buttonCount = #self.buttons

	if Util.Objects.Equals(layout, C.Layout.Grid) then
		self._:SetHeight(SetRows * (size + spacing))
		self._:SetWidth(SetColumns * (size + spacing))
	elseif Util.Objects.Equals(layout, C.Layout.Column) then
		if Util.Objects.Equals(grow, C.Direction.Horizontal) then
			self._:SetWidth((size * buttonCount) + (spacing * buttonCount) + spacing)
			self._:SetHeight(size + spacing * 2)
		elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
			self._:SetHeight((size * buttonCount) + (spacing * buttonCount) + spacing)
			self._:SetWidth(size + spacing * 2)
		else
			InvalidGrow(grow)
		end
	else
		InvalidLayout(layout)
	end

	-- it should be relative to the set bar button
	self:Reposition(self.parent._)

	for i=1, buttonCount do
		self.buttons[i]:PositionAndSize(size, spacing, grow, layout)
	end
end

function TotemSetBar:Reposition(at)
	local grow, spacing = Toolbox:GetBarGrow(), Toolbox:GetSetButtonSpacing()
	--self._:SetParent(at)
	self._:ClearAllPoints()

	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self._:SetPoint('RIGHT', at, "LEFT", -spacing, 0)
	elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
		self._:SetPoint('BOTTOM', at, "TOP", 0, spacing)
	else
		InvalidGrow(grow)
	end
end

function TotemSetBar:UpdateButtons()
	local sets = Util.Tables.Sort(
		Util.Tables.Values(Toolbox.totemSets:GetAll()),
		function(a, b) return a.name < b.name end
	)

	local setCount, buttonCount = Util.Tables.Count(sets), #self.buttons

	if setCount > buttonCount then
		Logging:Warn("UpdateButtons() : set count exceeds available buttons")
	elseif setCount == 0 then
		Logging:Warn("UpdateButtons() : no available sets")
	else
		Logging:Debug("UpdateButtons() : %d (sets) %d (buttons)", setCount, buttonCount)
	end

	local setIndex = buttonCount
	-- this wil be in alphabetical order, so work from greatest index to first
	for _, set in pairs(sets) do
		self.buttons[setIndex]:SetId(set)
		setIndex = setIndex - 1
	end

	for hideIndex = setIndex, 1, -1 do
		self.buttons[hideIndex]:SetId(nil)
	end

	for index = 1, buttonCount do
		self.buttons[index]:Update()
	end
end

--- SetAttribute calls result in this being fired, which does not infer combat state
--- as you can set non-reserved attributes on protected frames during combat, but cannot set
--- reserved attributes during combat (i.e. spell, macrotext)
function TotemSetBar:OnAttributeChanged(_--[[ frame --]], key, value)
	Logging:Trace("OnAttributeChanged(%s) : %s = %s", self:GetName(), tostring(key), Util.Objects.ToString(value))
	if Util.Objects.In(key, "selectedset") then
		local exists = Toolbox.totemSets:Exists(value)
		Logging:Debug("OnAttributeChanged(%s) : %s = %s / %s (found set)",  self:GetName(), tostring(key), tostring(value), tostring(exists))

		if exists then
			-- set the active totem set and rely upon event callbacks to handle based upon state
			Toolbox:SetActiveTotemSet(value, true)
		end
	end
end

-- TotemSetBar END --

-- TotemSetBarButton START --
function TotemSetBarButton:initialize(parent, index)
	self.parent = parent
	self.index = index
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
	self.id = nil
end

function TotemSetBarButton:GetName()
	return Util.Strings.Join('_', self.parent:GetFrameName(), 'Button' .. tostring(self.index))
end

function TotemSetBarButton:_CreateFrame()
	local button = CreateFrame('Button', self:GetName(), self.parent:GetFrame(), "BackdropTemplate,SecureHandlerBaseTemplate,SecureActionButtonTemplate")
	button:SetBackdrop(ButtonTexture)
	button:SetBackdropColor(0, 0, 0, 1)
	button:SetBackdropBorderColor(0, 0, 0, 1)
	button:SetID(self.index)

	BaseWidget.Border(button, ButtonBorderColor.r, ButtonBorderColor.g, ButtonBorderColor.b, ButtonBorderColor.a, 1, 1, 1)

	button.icon = button:CreateTexture(nil, 'ARTWORK')
	button.icon:SetTexCoord(unpack({0.08, 0.92, 0.08, 0.92}))
	UI.SetInside(button.icon)

	button:SetScript(
		'OnShow',
		function()
			--Logging:Debug("OnShow() : %s, %s", tostring(self.id), tostring(Toolbox:GetActiveTotemSetId()))
			if Util.Strings.Equal(self.id, Toolbox:GetActiveTotemSetId()) then
				button:ShowBorders()
			else
				button:HideBorders()
			end
		end
	)
	-- tooltip stuff for set name
	button:SetScript(
		'OnEnter',
		function()
			local set = self:GetSet()
			if set:isPresent() then
				UIUtil.ShowTooltip(button, nil, nil, set:get().name)
			end
		end
	)
	button:SetScript('OnLeave', function() UIUtil:HideTooltip() end)

	button:RegisterForClicks("AnyDown")
	-- on left click, select the associated set
	button:SetAttribute("type", "selectSet")
	button:SetAttribute("_selectSet", [[
		-- the setBar to which this button is bound
		local setBar = self:GetParent()
		setBar:SetAttribute('selectedset', self:GetAttribute('setId'))
	]])


	button:WrapScript(button, "PostClick", [[ self:GetParent():Hide() ]])
	return button
end

-- Grid Layout with Horizontal Grow
--[[ index (row, column)
03 (0,0)    06 (0,1)    09  (0,2)
02 (1,0)    05 (1,1)    08  (1,2)
01 (2,0)    04 (2,1)    07  (2,2)
--]]

-- Grid Layout with Vertical Grow
--[[ index (row, column)
01 (0,0)    02 (0,1)    03  (0,2)
04 (1,0)    05 (1,1)    06  (1,2)
07 (2,0)    08 (2,1)    09  (2,2)
--]]
function TotemSetBarButton:PositionAndSize(size, spacing, grow, layout)
	Logging:Trace("PositionAndSize(%d, %d, %s)", size, spacing, grow)
	self._:SetSize(size, size)
	self._:ClearAllPoints()

	if Util.Objects.Equals(layout, C.Layout.Column) then
		local index
		if Util.Objects.Equals(grow, C.Direction.Horizontal) then
			index = self.index
			self._:SetPoint('RIGHT', self.parent._, 'LEFT', ((index) * size) + (spacing * index), 0)
		elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
			index = SetMaxButtons - self.index
			self._:SetPoint('BOTTOM', self.parent._, 'BOTTOM', 0, ((index * size) + (spacing * index)))
		else
			InvalidGrow(grow)
		end
	elseif Util.Objects.Equals(layout, C.Layout.Grid) then
		-- LUA uses 1 based indexing, not 0 (which we want to use, so subtract 1)
		local index = self.index -- (SetMaxButtons - self.index)

		local row, column
		if Util.Objects.Equals(grow, C.Direction.Horizontal) then
			row = math.floor((SetMaxButtons - self.index) % SetColumns)
			column = math.floor((index - 1) / SetColumns)
		elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
			row = math.floor((self.index - 1) / SetColumns)
			column = math.floor((self.index - 1) % SetColumns)
		else
			InvalidGrow(grow)
		end

		local x = math.floor((column * size) + (column * spacing))
		local y = math.floor((row * size) + (row * spacing))
		Logging:Debug(
			"PositionAndSize(%d) : (row=%d, col=%d) (x=%d, y=%d)",
			self.index, row, column, x, y
		)

		self._:SetPoint('TOPLEFT', x, -y)
	end
end

--- @param set Models.Totem.TotemSet|string
function TotemSetBarButton:SetId(set)
	local id
	if Util.Objects.IsInstanceOf(set, TotemSet) then
		id = set.id
	elseif Util.Objects.IsString(set) then
		id = set
	elseif Util.Objects.IsNil(set) then
		-- noop
	else
		error(format("Unsupported type '%s' for set id", type(set)))
	end

	self.id = id
	self._:SetAttribute("setId", self.id)
	self.set = nil
end

--- @return Optional
function TotemSetBarButton:GetSet()
	if not self.set then
		self.set =
			Util.Strings.IsSet(self.id) and Util.Optional.ofNillable(Toolbox.totemSets:Get(self.id)) or Util.Optional.empty()
	end

	return self.set
end

function TotemSetBarButton:Update()
	local set = self:GetSet()
	set:ifPresentOrElse(
		function(s)
			self._.icon:SetTexture(s:GetIcon())
			self:Show()
		end,
		function()
			self._.icon:SetTexture(nil)
			self:Hide()
		end
	)
end
-- TotemSetBarButton END --

-- TotemPulseTimer START --
local UpdateThreshold = 0.01

--- @param parent TotemButton
function TotemPulseTimer:initialize(parent)
	self.parent = parent
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
	self.interval = 0
	self.startTime = 0
	self._running = false
end

--- @return string
function TotemPulseTimer:GetName()
	return Util.Strings.Join('_', self.parent:GetFrameName(), 'PulseTimer')
end


-- todo : make secure
function TotemPulseTimer:_CreateFrame()
	local frame = CreateFrame('Frame', self:GetName(), self.parent:GetFrame()) --, "SecureHandlerBaseTemplate,SecureHandlerStateTemplate")
	frame:EnableMouse(false)
	frame:Hide()

	--frame:SetSize(195, 20)

	frame.bar = CreateFrame("StatusBar", "$parentBar", frame)
	--frame.bar:SetPoint("CENTER", frame, "CENTER")
	--frame.bar:SetSize(195, 20)
	frame.bar:SetMinMaxValues(0, 1)
	frame.bar:SetStatusBarTexture(BaseWidget.ResolveTexture('default'))
	frame.bar:SetStatusBarColor(C.Colors.LightBlue:GetRGBA())

	frame.bar.bg = frame.bar:CreateTexture("$parent_Bg", "BACKGROUND")
	--frame.bar.bg:SetAllPoints()
	frame.bar.bg:SetColorTexture(0, 0, 0, 0.3)
	--frame.bar.bg:SetColorTexture(0.62353, 0.86275, 0.89412, 0.3)

	frame.bar.spark = frame.bar:CreateTexture("$parent_Spark", "OVERLAY")
	--frame.bar.spark:SetPoint("CENTER", frame.bar, "CENTER")
	--frame.bar.spark:SetSize(32, 64)
	frame.bar.spark:SetTexture(BaseWidget.ResolveTexture('spark'))
	frame.bar.spark:SetBlendMode("ADD")
	frame.bar.spark:SetVertexColor(C.Colors.LightBlue:GetRGBA())
	frame.bar.spark:SetAlpha(1)

	frame.bar.time = frame.bar:CreateFontString("$parent_Time", "OVERLAY", "GameFontHighlightSmall")
	--frame.bar.time:SetPoint("RIGHT", frame.bar, "RIGHT", -1, 0.5)
	--frame.bar.time:SetText("5.0")

	return frame
end

function TotemPulseTimer:PositionAndSize(size, spacing, grow, pulseSize)
	-- todo : evaluate whether clearing and resetting points is necessary
	self._:ClearAllPoints()
	self._.bar:ClearAllPoints()
	self._.bar.bg:ClearAllPoints()
	self._.bar.time:ClearAllPoints()

	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self._:SetSize(pulseSize, size)
		self._:SetPoint('TOPLEFT', self._:GetParent(), 'TOPRIGHT', spacing/2, 0)

		self._.bar:SetSize(pulseSize, size)
		self._.bar:SetOrientation(C.Direction.Vertical)
		self._.bar:SetRotatesTexture(true)
		self._.bar:SetPoint("CENTER", self._, "CENTER")

		self._.bar.bg:SetAllPoints()

		self._.bar.time:SetPoint("TOP", self._.bar, "TOP", 0.5, -1)
	elseif Util.Objects.Equals(grow, C.Direction.Vertical) then

		self._:SetSize(size, pulseSize)
		self._:SetPoint('TOPLEFT', self._:GetParent(), 'BOTTOMLEFT', 0,  -spacing/2)

		self._.bar:SetSize(size, pulseSize)
		self._.bar:SetOrientation(C.Direction.Horizontal)
		self._.bar:SetRotatesTexture(false)
		self._.bar:SetPoint("CENTER", self._, "CENTER")

		self._.bar.bg:SetAllPoints()

		self._.bar.time:SetPoint("RIGHT", self._.bar, "RIGHT", -1, 0.5)
	else
		InvalidGrow(grow)
	end
end

--- @param remaining number the amount of time remaining until pulse
function TotemPulseTimer:Update(remaining)
	local grow = Toolbox:GetBarGrow()
	--Logging:Debug("Update(%s) : %.2f", self:GetName(), remaining)

	-- "fills up"
	-- self._.bar:SetValue(1 - (self.time.remaining/self.time.duration))
	-- "drains down"
	self._.bar:SetValue(self.time.remaining/self.time.duration)
	-- use ceiling on the number as we're not looking for fractional second precision
	-- and showing 0 on the timer is misleading (1 > duration > 0)
	--self._.bar.time:SetText(format("%d", remaining))
	--self._.bar.time:SetText(format("%.1f", remaining))
	self._.bar.time:SetText(format("%d", math.ceil(remaining)))

	self._.bar.spark:ClearAllPoints()
	-- we want the spark to be perpindicular to bar and inverse in size
	-- SetSize(width, height)
	self._.bar.spark:SetSize(self._.bar:GetHeight(), self._.bar:GetWidth())
	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		-- set rotation of spark image to be 180 degrees CCW
		self._.bar.spark:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1)
		self._.bar.spark:SetPoint("CENTER", self._.bar, "BOTTOM", 0.5, self._.bar:GetValue() * self._.bar:GetHeight())
	elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
		-- set rotation of spark image back to normal
		self._.bar.spark:SetTexCoord(0,1,0,1)
		self._.bar.spark:SetPoint("CENTER", self._.bar, "LEFT", self._.bar:GetValue() * self._.bar:GetWidth(), -1)
	else
		InvalidGrow(grow)
	end
end

function TotemPulseTimer:Cancel()
	self:Hide()
	self._:SetScript("OnUpdate", nil)
	self._running = false
end

--- @param interval number how often to pulse (in seconds)
--- @param startTime number the instant, in the past, at which the pulse started (time when totem started)
function TotemPulseTimer:Start(interval, startTime)
	Logging:Debug("Start(%s) : %.2f [%d]", self:GetName(), interval, startTime)

	if not interval or interval <= 0 then
		return
	end

	self.interval = interval
	self.startTime = startTime or GetTime()

	if self._running then
		return
	end

	local accumulator = 0
	local throttle = 0.05 -- 20 updates/sec

	self._:SetScript("OnUpdate", function(_, elapsed)
		accumulator = accumulator + elapsed
		if accumulator < throttle then
			return
		end
		accumulator = 0

		local now = GetTime()
		-- compute where we are in the pulse cycle
		local totalElapsed = now - self.startTime
		local timeIntoPulse = totalElapsed % self.interval
		local remaining = self.interval - timeIntoPulse

		self.time = self.time or {}
		self.time.remaining = remaining
		self.time.duration = self.interval

		self:Update(remaining)
	end)

	self:Show()
end
-- TotemPulseTimer END  --


function Toolbox:OnBindingsUpdated()
	Logging:Debug("OnBindingsUpdated")
	if self.totemBar then
		for _, button in pairs(self.totemBar:GetButtons()) do
			button:UpdateHotKey()
		end
	end
end

--- configures the binding headers and names, used in display for configuring the associated key binds
function Toolbox:SetupKeyBindDisplay()
	_G[C.KeyBinds.Header.TotemBar] =  L['totem_bar']
	_G[C.KeyBinds.Header.TotemFlyout] = L['totem_flyout']
	_G[C.KeyBinds.Header.TotemSet] = L['totem_set']

	-- probably redundant based upon where this is called
	if self.totemBar then
		local function SetKeyBindNames(names)
			for name, description in pairs(names) do
				Logging:Trace("%s => %s", name, description)
				_G[C.KeyBinds.PrefixName .. name] = description
			end
		end

		for _, button in pairs(self.totemBar:GetButtons()) do
			SetKeyBindNames(button:GetKeyBindNames())
		end
	end

	--[[
	local TypeToElement = LibTotem.Constants.Totems.ElementIdToName
	-- e.g. BINDING_HEADER_TOTEMFLYOUTFIRE
	for _, name in pairs(TypeToElement) do
		_G[format(C.KeyBinds.Header.TotemFlyoutType, name:upper())] = format("%s : %s %s",  L['totem_flyout'], name, L['spells'])
	end

	for element = 1, LibTotem.Constants.MaxTotems do
		local elementName =  TypeToElement[element]
		-- e.g. BINDING_NAME_STUMPY_TOTEMBAR_BUTTON_FIRE
		_G[format(C.KeyBinds.Name.TotemBarButton, elementName:upper())] = format("%s %s", elementName, L['totem'])
		-- e.g. BINDING_NAME_STUMPY_TOTEMBAR_FLYOUT_FIRE
		_G[format(C.KeyBinds.Name.TotemFlyout, elementName:upper())] = format("%s %s", elementName, L['spells'])
		for index = 1, FlyoutMaxButtons do
			-- e.g. BINDING_NAME_STUMPY_TOTEMBAR_FLYOUT_FIRE_BUTTON1
			_G[format(C.KeyBinds.Name.TotemFlyoutButton, elementName:upper(), index)] = format("%s %d", L['spell'], index)
		end
	end

	-- e.g. BINDING_NAME_STUMPY_TOTEMBAR_FLYOUT_TOTEMSET
	_G[C.KeyBinds.Name.TotemSetFlyout] = L['flyout']
	for index = 1, SetMaxButtons do
		-- e.g. BINDING_NAME_STUMPY_TOTEMBAR_FLYOUT_TOTEMSET_BUTTON1
        _G[format(C.KeyBinds.Name.TotemSetFlyoutButton, index)] = format("%s %d", L['set'], index)
	end
	--]]
end

function Toolbox:CreateTotemBar()
	if not self.totemBar then
		self.totemBar = TotemBar()
		self:SetupKeyBindDisplay()
		self.totemBar:Show()
	end
end

--- @return TotemBar
function Toolbox:GetTotemBar()
	return self.totemBar
end