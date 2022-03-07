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

local CooldownFrame_Set, CooldownFrame_Clear = CooldownFrame_Set, CooldownFrame_Clear
local ButtonTexture = {
	bgFile =  UI.ResolveTexture("white"),
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = false, tileSize = 8, edgeSize = 2,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

local function InvalidGrow(grow)
	error(format("Invalid grow '%s' (%s)", grow, Util.Objects.ToString(Util.Tables.Values(C.Direction))))
end

local function InvalidLayout(layout)
	error(format("Invalid layout '%s' (%s)", layout, Util.Objects.ToString(Util.Tables.Values(C.Layout))))
end

--- @type UI.Native.FrameContainer
local FrameContainer = AddOn.Package('UI.Native').FrameContainer
--- @class TotemBar
local TotemBar = AddOn.Class('TotemBar', FrameContainer)
--- @class TotemButton
local TotemButton = AddOn.Class('TotemButton', FrameContainer)
--- @class TotemFlyoutButton
local TotemFlyoutButton = AddOn.Class('TotemFlyoutButton', FrameContainer)
--- @class TotemFlyoutBar
local TotemFlyoutBar = AddOn.Class('TotemFlyoutBar', FrameContainer)
--- @class TotemFlyoutBarButton
local TotemFlyoutBarButton = AddOn.Class('TotemFlyoutBarButton', FrameContainer)

-- TotemBar BEGIN --
function TotemBar:initialize()
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
	--- @type table<number, TotemButton>
	self.buttons = {}
	--- @type TotemFlyoutBar
	self.flyoutBar = TotemFlyoutBar(self)
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

--- @return TotemFlyoutBar
function TotemBar:GetFlyoutBar()
	return self.flyoutBar
end

function TotemBar:GetButtons()
	return self.buttons
end

--- @param element Models.Totem.Totem|number|string
function TotemBar:GetButtonByElement(element)
	if Util.Objects.IsInstanceOf(element, Totem) then
		element = element:GetElement()
	elseif Util.Objects.IsString(element) then
		element = tonumber(element)
	elseif Util.Objects.IsNumber(element) then
		error("Specified element is not of the appropriate type")
	end

	local index = Toolbox:GetElementIndex(element)
	return self.buttons[index]
end

function TotemBar:CreateButton(element)
	return TotemButton(self, element)
end

function TotemBar:CreateButtons()
	Logging:Trace("CreateButtons()")
	for element = 1, C.MaxTotems do
		local index = Toolbox:GetElementIndex(element)
		Logging:Trace("CreateButtons() : %d (element) => %d (index)", element, index)
		self.buttons[index] = self:CreateButton(element)
	end
end

--- @param totem Models.Totem.Totem
function TotemBar:UpdateButton(totem)
	self:GetButtonByElement(totem):Update(totem)
end

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

	local buttonCount = #self.buttons

	for i=1, buttonCount do
		local button = self.buttons[i]
		button:PositionAndSize(i, size, spacing, grow)
	end

	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self._:Width((size * buttonCount) + (spacing * buttonCount) + spacing)
		self._:Height(size + spacing * 2)
	elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
		self._:Height((size * buttonCount) + (spacing * buttonCount) + spacing)
		self._:Width(size + spacing * 2)
	else
		InvalidGrow(grow)
	end
end
-- TotemBar END --

-- TotemBarButton BEGIN --
--- @param parent TotemBar
--- @param element number
function TotemButton:initialize(parent, element)
	--- @type TotemBar
	self.parent = parent
	--- @type number
	self.element = element
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
	--- @type TotemFlyoutButton
	self.flyoutButton = TotemFlyoutButton(self)
end

function TotemButton:GetFlyoutBar()
	return self.parent:GetFlyoutBar()
end

--- @return string
function TotemButton:GetName()
	return Util.Strings.Join('', self.parent:GetFrameName(), 'Totem', tostring(self.element))
end

function TotemButton:_CreateFrame()
	local button = CreateFrame('Button', self:GetName(), self.parent:GetFrame(), "BackdropTemplate,SecureActionButtonTemplate")
	button:SetBackdrop(ButtonTexture)
	button:SetBackdropColor(0, 0, 0, 1)
	button:SetBackdropBorderColor(0, 0, 0, 1)
	button:SetID(self.element)

	button.icon = button:CreateTexture(nil, 'ARTWORK')
	button.icon:SetTexCoord(unpack({0.08, 0.92, 0.08, 0.92}))
	UI.SetInside(button.icon)

	button.cooldown = CreateFrame('Cooldown', button:GetName() .. 'Cooldown', button, 'CooldownFrameTemplate')
	button.cooldown:SetReverse(true)
	button.cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	UI.SetInside(button.cooldown)

	-- any up event is a click
	button:RegisterForClicks("AnyUp")
	--- on right click, destroy totem for associated element
	button:SetAttribute("type2", "destroytotem")
	button:SetAttribute("totem-slot", self.element)

	-- allow button to be moved and swapped with others
	button:EnableMouse(true)
	button:SetMovable(true)
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnDragStart", function() self:OnDragStart() end)
	button:SetScript("OnDragStop", function() self:OnDragStop() end)
	button:Show()

	--[[
	button:SetScript(
		"OnAttributeChanged",
		function(self, attr, detail)
			Logging:Debug("OnAttributeChanged(%s) : %s = %s", self:GetName(), tostring(attr), Util.Objects.ToString(detail))
		end
	)
	--]]

	return button
end

--- @param totem Models.Totem.Totem
function TotemButton:Update(totem)
	totem = Util.Objects.IsNil(totem) and Totems():Get(self.element) or totem

	if not Util.Objects.Equals(self.element, totem:GetElement()) then
		Logging:Warn(
			"Update(%d, %d) : specified totem is not for the associated element",
			self.element, totem:GetElement()
		)
		return
	end

	local icon, desaturated, spellName = nil, nil
	if totem:IsPresent() then
		icon = totem:GetIcon()
		spellName = totem:GetNormalizedName()
	else
		local _, spell = Toolbox:GetTotemSet():Get(self.element)
		if spell then
			icon = spell:GetIcon()
			spellName = spell:GetName()
		else
			icon, desaturated = C.Icons.TotemGeneric, 1
		end
	end

	Logging:Trace(
		"UpdateButton(%d) : %s (present), %s (icon) %s (spell)",
		self.element, tostring(totem:IsPresent()), tostring(icon), tostring(spellName)
	)

	-- todo : in combat

	self._.icon:SetTexture(icon)
	self._.icon:SetDesaturated(desaturated)

	if Util.Objects.IsSet(spellName) then
		self._:SetAttribute("type", "spell")
		self._:SetAttribute("spell", spellName)
	else
		self._:SetAttribute("type", nil)
		self._:SetAttribute("spell", nil)
	end

	if totem:IsPresent() then
		CooldownFrame_Set(self._.cooldown, totem:GetStartTime(), totem:GetDuration(), 1, true, 1)
	else
		CooldownFrame_Clear(self._.cooldown)
	end
end

function TotemButton:PositionAndSize(index, size, spacing, grow)
	self._:SetSize(size, size)
	self._:ClearAllPoints()

	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self._:SetPoint('LEFT', ((index - 1) * size) + (spacing * index), 0)
		self.flyoutButton:PositionAndSize(size, spacing, grow)
	elseif Util.Objects.Equals(grow, C.Direction.Vertical)then
		self._:SetPoint('TOP', 0, -(((index - 1) * size) + (spacing * index)))
		self.flyoutButton:PositionAndSize(size, spacing, grow)
	else
		InvalidGrow(grow)
	end
end

function TotemButton:RestorePosition()
	self._:ClearAllPoints()
	self._:SetPoint(self.point[1], self.point[2], self.point[3])
end

function TotemButton:OnDragStart()
	if not AddOn:InCombatLockdown() and IsShiftKeyDown() then
		local point, _, _, x, y = self._:GetPoint()
		self.point = {point, x, y}
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
		self.point = nil
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
	return Util.Strings.Join('', self.parent:GetFrameName(), 'Flyout')
end

function TotemFlyoutButton:_CreateFrame()
	local button = UI:NewNamed('Button', self.parent:GetFrame(), self:GetName(), nil, "BackdropTemplate,SecureHandlerClickTemplate,SecureHandlerStateTemplate")
	button.Texture:SetColorTexture(0.25, 0.78, 0.92, 1)
	button.HighlightTexture:SetColorTexture(0.25, 0.78, 0.92, 1)
	button.HighlightTexture:SetGradientAlpha("VERTICAL", 0.05, 0.06, 0.09, 1, 0.20, 0.21, 0.25, 1)
	button:RegisterForClicks("LeftButtonDown")

	button:SetScript(
		"PreClick",
		function(b)
			Logging:Trace("PreClick(%d)", self:GetElement())
			local flyoutBar = self.parent:GetFlyoutBar()
			-- only reposition and update when not currently visible
			if not flyoutBar._:IsVisible() then
				flyoutBar:SetElement(self.parent.element)
				flyoutBar:Reposition(b)
				flyoutBar:UpdateButtons()
			end
		end
	)
	-- parent <- child hierarchy
	-- totem bar (ref to flyoutBar) <- totem button <- flyout button
	button:SetAttribute("_onclick",[[
		local flyoutBarFrame = self:GetParent():GetParent():GetFrameRef("flyoutBarFrame")
		if flyoutBarFrame:IsVisible() then
			flyoutBarFrame:Hide()
		else
			flyoutBarFrame:Show()
		end
	]])

	--button:SetScript(
	--	"OnClick",
	--	function(btn)
	--		local flyoutBar = self.parent.parent.flyoutBar
	--		flyoutBar:Toggle(btn, self.parent.element)
	--	end
	--)

	button:Show()

	return button
end

function TotemFlyoutButton:PositionAndSize(size, spacing, grow)
	self._:ClearAllPoints()
	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self._:SetSize(size, size/5)
		self._:SetPoint('BOTTOMLEFT', self._:GetParent(), 'TOPLEFT', 0, spacing/2)
	elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
		self._:SetSize(size/5, size)
		self._:SetPoint('TOPLEFT', self._:GetParent(), 'TOPRIGHT', spacing/2, 0)
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

--- @param parent TotemBar
function TotemFlyoutBar:initialize(parent)
	self.parent = parent
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
	--- @type table<number, TotemFlyoutBarButton>
	self.buttons = {}
	--- @type number
	self.element = nil
	self:CreateButtons()
	self:PositionAndSize()
	self:Hide()
end

function TotemFlyoutBar:SetElement(element)
	self.element = element
end

--- @return string
function TotemFlyoutBar:GetName()
	return AddOn:Qualify('TotemFlyoutBar')
end

function TotemFlyoutBar:_CreateFrame()
	local f = CreateFrame('Frame', self:GetName(), self.parent:GetFrame(), "BackdropTemplate,SecureHandlerBaseTemplate,SecureHandlerShowHideTemplate")
	self.parent._:SetFrameRef("flyoutBarFrame", f)
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
		self._:Height(FlyoutRows * (size + spacing))
		self._:Width(FlyoutColumns * (size + spacing))
	elseif Util.Objects.Equals(layout, C.Layout.Column) then
		if Util.Objects.Equals(grow, C.Direction.Horizontal) then
			self._:Height((size * buttonCount) + (spacing * buttonCount) + spacing)
			self._:Width(size + spacing * 2)
		elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
			self._:Width((size * buttonCount) + (spacing * buttonCount) + spacing)
			self._:Height(size + spacing * 2)
		else
			InvalidGrow(grow)
		end
	else
		InvalidLayout(layout)
	end

	for i=1, buttonCount do
		self.buttons[i]:PositionAndSize(size, spacing, grow, layout)
	end

	--[[
	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self._:Height((size * buttonCount) + (spacing * buttonCount) + spacing)
		self._:Width(size + spacing * 2)
	else
		self._:Width((size * buttonCount) + (spacing * buttonCount) + spacing)
		self._:Height(size + spacing * 2)
	end
	--]]
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

--[[
function TotemFlyoutBar:Toggle(at, element)
	if self._:IsVisible() then
		self.element = nil
		self:Hide()
	else
		local grow = Toolbox:GetBarGrow()
		self._:ClearAllPoints()
		if Util.Objects.Equals(grow, C.Direction.Horizontal) then
			self._:SetPoint('BOTTOM', at, "TOP", 0, 0)
		elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
			self._:SetPoint('LEFT', at, "RIHHT", 0, 0)
		end

		self:UpdateButtons(element)
		self:Show()
	end
end
--]]

function TotemFlyoutBar:UpdateButtons()
	if not self.element then
		for index = 1, #self.buttons do
			self.buttons[index]:Hide()
		end
	else
		local spells = Toolbox:GetSpellsByTotem(self.element)
		local spellCount, buttonCount = #spells, #self.buttons

		if spellCount > buttonCount then
			Logging:Warn("UpdateButtons(%d) : spell count exceeds available buttons", self.element)
		else
			Logging:Trace("UpdateButtons(%d) : %d (spells) %d (buttons)", self.element, spellCount, buttonCount)
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
function TotemFlyoutBarButton:initialize(parent, index)
	self.parent = parent
	self.index = index
	self.spell = nil
	FrameContainer.initialize(self, function() return self:_CreateFrame() end)
end

function TotemFlyoutBarButton:GetName()
	return Util.Strings.Join('', self.parent:GetFrameName(), 'Totem', tostring(self.index))
end

function TotemFlyoutBarButton:_CreateFrame()
	local button = CreateFrame('Button', self:GetName(), self.parent:GetFrame(), "BackdropTemplate,SecureActionButtonTemplate")
	button:SetBackdrop(ButtonTexture)
	button:SetBackdropColor(0, 0, 0, 1)
	button:SetBackdropBorderColor(0, 0, 0, 1)
	button:SetID(self.index)

	button.icon = button:CreateTexture(nil, 'ARTWORK')
	button.icon:SetTexCoord(unpack({0.08, 0.92, 0.08, 0.92}))
	UI.SetInside(button.icon)

	button:SetScript('OnEnter', function() if self.spell then UIUtil.Link(self._, self.spell.link) end end)
	button:SetScript('OnLeave', function() if self.spell then UIUtil:HideTooltip() end end)

	return button
end

function TotemFlyoutBarButton:Hide()
	self.spell = nil
	TotemFlyoutBarButton.super.Hide(self)
end

function TotemFlyoutBarButton:SetSpell(spell)
	Logging:Trace("SetSpell(%d) : %s", self._:GetID(), Util.Objects.ToString(spell and spell:toTable() or 'NONE'))
	self.spell = spell
end

function TotemFlyoutBarButton:Update()
	if self.spell then
		self._.icon:SetTexture(self.spell:GetIcon())
		self:Show()
	else
		self:Hide()
	end
end

--[[ index (row, column)
01 (0,0)    02 (0,1)    03  (0,2)
04 (1,0)    05 (1,1)    06  (1,2)
07 (2,0)    08 (2,1)    09  (2,2)
--]]
function TotemFlyoutBarButton:PositionAndSize(size, spacing, grow, layout)
	Logging:Debug("PositionAndSize(%d, %d, %s)", size, spacing, grow)
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
		Logging:Debug(
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

--[[

local CreateTotemBar, CreateTotemBarButton, CreateTotemBarMacro, UpdateTotemBarButton, UpdateTotemBarMacro, PositionAndSizeTotemBar

CreateTotemBar = function()
	local f = CreateFrame('Frame', AddOn:Qualify('TotemBar'), UIParent, "BackdropTemplate")
	f.buttons = {}
	f.macros = {}

	local storage = AddOn.db and Util.Tables.Get(AddOn.db.profile, 'ui.TotemBar') or {}
	f:EnableMouse(true)
	f:SetScale(storage.scale)
	Window:Embed(f)
	f:RegisterConfig(storage)
	f:RestorePosition()
	f:MakeDraggable()
	f:Show()

	f.CreateButton = CreateTotemBarButton
	f.CreateMacro = CreateTotemBarMacro
	f.UpdateButton = UpdateTotemBarButton
	f.UpdateMacro = UpdateTotemBarMacro
	f.GetMacro = function(self, element) return self.buttons[element] end
	f.PositionAndSize = PositionAndSizeTotemBar
	f.UpdateButtons = function(self)
		for element = 1, C.MaxTotems do
			self:UpdateButton(Totems():Get(element))
		end
	end
	f.CreateButtons = function(self)
		for element = 1, C.MaxTotems do
			local index = Toolbox:GetElementIndex(element)
			Logging:Trace("CreateButtons() : %d (element) => %d (index)", element, index)
			self.buttons[index] = self:CreateButton(element)
			--self.macros[element] = self:CreateMacro(element)
		end
	end

	f:CreateButtons()
	f:PositionAndSize()

	return f
end

CreateTotemBarButton = function(self, element)
	local button = CreateFrame('Button', self:GetName() ..'Totem'..element, self, "SecureActionButtonTemplate, BackdropTemplate")
	button:SetBackdrop(ButtonTexture)
	button:SetBackdropColor(0, 0, 0, 1)
	button:SetBackdropBorderColor(0, 0, 0, 1)
	button:SetID(element)

	button.icon = button:CreateTexture(nil, 'ARTWORK')
	button.icon:SetTexCoord(unpack({0.08, 0.92, 0.08, 0.92}))
	UI.SetInside(button.icon)

	button.cooldown = CreateFrame('Cooldown', button:GetName()..'Cooldown', button, 'CooldownFrameTemplate')
	button.cooldown:SetReverse(true)
	button.cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	UI.SetInside(button.cooldown)

	-- todo : border
	button.border = button:CreateTexture(nil, "BORDER")
	button.border:SetColorTexture(1, 0.96, 0.41, 1)
	UI.SetOutside(button.border)

	button.totemFlyoutButton = UI:NewNamed('Button', button, button:GetName()..'Flyout')
	button.totemFlyoutButton.Texture:SetColorTexture(0.25, 0.78, 0.92, 1)
	button.totemFlyoutButton.HighlightTexture:SetColorTexture(0.25, 0.78, 0.92, 1)
	button.totemFlyoutButton.HighlightTexture:SetGradientAlpha("VERTICAL", 0.05, 0.06, 0.09, 1, 0.20, 0.21, 0.25, 1)
	button.totemFlyoutButton:SetScript("OnClick", function(btn) self.totemFlyout:Toggle(btn, element) end)
	button.totemFlyoutButton.SetPositionAndSize = function(btn, size, spacing, grow)
		btn:ClearAllPoints()
		if Util.Objects.Equals(grow, C.Direction.Horizontal) then
			btn:SetSize(size, size/5)
			btn:SetPoint('BOTTOMLEFT', btn:GetParent(), 'TOPLEFT', 0, spacing/2)
		elseif Util.Objects.Equals(grow, C.Direction.Vertical)then
			btn:SetSize(size/5, size)
			btn:SetPoint('TOPLEFT', btn:GetParent(), 'TOPRIGHT', spacing/2, 0)
		end
	end
	button.totemFlyoutButton:Show()

	button.OnDragStart = function(btn)
		if IsShiftKeyDown() then
			Logging:Debug("OnDragStart(%d)", btn:GetID())
			btn.point, _, _, btn.x, btn.y = btn:GetPoint()
			btn:StartMoving()
		end
	end

	button.OnDragStop = function(btn)
		Logging:Debug("OnDragStop(%d)", btn:GetID())
		btn:StopMovingOrSizing()

		local buttons, target = btn:GetParent().buttons, nil
		for i = 1, #buttons do
			local candidate = buttons[i]
			if candidate:IsMouseOver() and candidate ~= btn then
				Logging:Trace("%d => %s", candidate:GetID(), Util.Objects.ToString({candidate:GetPoint()}))
				target = candidate
				break
			end
		end

		if target then
			btn:SwapPosition(target)
			Toolbox:SetElementIndices()
		else
			btn:RestorePosition()
		end
	end

	button.SwapPosition = function(btn, with)
		local id, withId = btn:GetID(), with:GetID()
		Logging:Trace("SwapPosition(%d, %d)", id, withId)

		local point, x, y =  btn.point, btn.x, btn.y
		local withPoint, _, _, withX, withY = with:GetPoint()

		btn:ClearAllPoints()
		btn:SetPoint(withPoint, withX, withY)

		with:ClearAllPoints()
		with:SetPoint(point, x, y)

		-- swap the actual buttons in the table
		local buttons = self.buttons
		local index = Util.Tables.Find(buttons, btn)
		local withIndex = Util.Tables.Find(buttons, with)

		Logging:Trace("SwapPosition(%d, %d) : %d, %d", id, withId, index, withIndex)

		buttons[index] = with
		buttons[withIndex] = btn
	end

	button.SetPositionAndSize = function(btn, index, size, spacing, grow)
		btn:SetSize(size, size)
		btn:ClearAllPoints()

		if Util.Objects.Equals(grow, C.Direction.Horizontal) then
			btn:SetPoint('LEFT', ((index - 1) * size) + (spacing * index), 0)
			btn.totemFlyoutButton:SetPositionAndSize(size, spacing, grow)
		elseif Util.Objects.Equals(grow, C.Direction.Vertical)then
			button:SetPoint('TOP', 0, -(((index - 1) * size) + (spacing * index)))
			btn.totemFlyoutButton:SetPositionAndSize(size, spacing, grow)
		end
	end

	button.RestorePosition = function(btn)
		btn:ClearAllPoints()
		btn:SetPoint(btn.point, btn.x, btn.y)
	end

	button:RegisterForClicks("AnyUp")
	button:SetAttribute("type2", "destroytotem")
	button:SetAttribute("totem-slot", element)

	button:EnableMouse(true)
	button:SetMovable(true)
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnDragStart", function(b) b:OnDragStart() end)
	button:SetScript("OnDragStop", function(b) b:OnDragStop() end)
	button:Show()

	return button
end

CreateTotemBarMacro = function(self, element)
	local macro = CreateFrame('Button', self:GetName() ..'Macro'.. element, self, "SecureActionButtonTemplate")
	macro:SetAttribute('type', 'macro');
	macro:SetAttribute('macrotext', nil);
	macro:Hide()
	return macro
end


UpdateTotemBarButton = function(self, totem)
	local element = totem:GetElement()
	local index = Toolbox:GetElementIndex(element)
	Logging:Trace("UpdateButton(%d, %d)", element, index)

	local button = self.buttons[index]
	local icon, desaturated, spellName = nil, nil

	if totem:IsPresent() then
		icon = totem:GetIcon()
		spellName = totem:GetNormalizedName()
	else
		local _, spell = Toolbox:GetTotemSet():Get(element)
		if spell then
			icon = spell:GetIcon()
			spellName = spell:GetName()
		else
			icon, desaturated = C.Icons.TotemGeneric, 1
		end
	end

	Logging:Trace(
		"UpdateButton(%d, %d) : %s (present), %s (icon) %s (spell)",
		element, index, tostring(totem:IsPresent()), tostring(icon), tostring(spellName)
	)

	button.icon:SetTexture(icon)
	button.icon:SetDesaturated(desaturated)

	if Util.Objects.IsSet(spellName) then
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell", spellName)
	else
		button:SetAttribute("type", nil)
		button:SetAttribute("spell", nil)
	end

	--self:UpdateMacro(element, spellName)

	if totem:IsPresent() then
		CooldownFrame_Set(button.cooldown, totem:GetStartTime(), totem:GetDuration(), 1, true, 1)
	else
		CooldownFrame_Clear(button.cooldown)
	end
end

-- todo : cannot swap macros while in combat
-- https://wowpedia.fandom.com/wiki/API_InCombatLockdown
UpdateTotemBarMacro = function(self, element, spellName)
	local macro = self.macros[element]

	if Util.Strings.IsSet(spellName) then
		macro:SetAttribute('macrotext', format('/cast %s', spellName))
	else
		macro:SetAttribute('macrotext', nil)
	end

	Logging:Debug("UpdateTotemBarMacro(%d, %s, %s) : %s", element, tostring(spellName), macro:GetName(), tostring(macro:GetAttribute('macrotext')))
end

PositionAndSizeTotemBar = function(self)
	local size, spacing, grow =
		Toolbox:GetButtonSize(), Toolbox:GetButtonSpacing(), Toolbox:GetBarGrow()

	local buttonCount = #self.buttons

	for i=1, buttonCount do
		local button = self.buttons[i]
		button:SetPositionAndSize(i, size, spacing, grow)
	end

	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self:Width((size * buttonCount) + (spacing * buttonCount) + spacing)
		self:Height(size + spacing * 2)
	else
		self:Height((size * buttonCount) + (spacing * buttonCount) + spacing)
		self:Width(size + spacing * 2)
	end
end

local CreateTotemFlyoutBar, CreateTotemFlyoutBarButton, PositionAndSizeTotemFlyoutBar

CreateTotemFlyoutBar = function(parent)
	local tf = CreateFrame('Frame', AddOn:Qualify('TotemBar', 'TotemFlyout'), parent, "BackdropTemplate")
	tf.buttons = {}
	tf.element = nil

	tf.GetTotemBar = function(self) return self:GetParent() end
	tf.CreateButton = CreateTotemFlyoutBarButton
	tf.PositionAndSize = PositionAndSizeTotemFlyoutBar
	tf.CreateButtons = function(self)
		for i = 1, FlyoutMaxButtons do
			self.buttons[i] = self:CreateButton(i)
		end
	end
	tf.UpdateButtons = function(self, element)
		local spells = Toolbox:GetSpellsByTotem(element)
		local spellCount, buttonCount = #spells, #self.buttons

		if spellCount > buttonCount then
			Logging:Warn("UpdateButtons(%d) : spell count exceeds available buttons", element)
		else
			Logging:Trace("UpdateButtons(%d) : %d (spells) %d (buttons)", element, spellCount, buttonCount)
		end

		self.element = element

		for index, spell in pairs(spells) do
			self.buttons[buttonCount - (index - 1)]:Update(spell)
		end

		for hideIndex = (buttonCount - spellCount), 1, -1 do
			self.buttons[hideIndex]:Hide()
		end
	end
	tf.Toggle = function(self, at, element)
		if self:IsVisible() then
			self.element = nil
			self:Hide()
		else
			local grow = Toolbox:GetBarGrow()
			self:ClearAllPoints()
			if Util.Objects.Equals(grow, C.Direction.Horizontal) then
				self:SetPoint('BOTTOM', at, "TOP", 0, 0)
			elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
				self:SetPoint('LEFT', at, "RIHHT", 0, 0)
			end
			self:UpdateButtons(element)
			self:Show()
		end
	end

	tf:CreateButtons()
	tf:PositionAndSize()
	tf:Hide()

	return tf
end

CreateTotemFlyoutBarButton = function(self, index)
	local button = CreateFrame('Button', self:GetName() .. 'Totem'.. index, self, "BackdropTemplate")
	button.spell = nil
	button:SetBackdrop(ButtonTexture)
	button:SetBackdropColor(0, 0, 0, 1)
	button:SetBackdropBorderColor(0, 0, 0, 1)
	button:SetID(index)

	button.icon = button:CreateTexture(nil, 'ARTWORK')
	button.icon:SetTexCoord(unpack({0.08, 0.92, 0.08, 0.92}))
	UI.SetInside(button.icon)

	button._Hide = button.Hide
	button.Hide = function(btn)
		btn.spell = nil
		btn:_Hide()
	end

	button.Update = function(btn, spell)
		Logging:Trace("Update(%d) : %s", btn:GetID(), Util.Objects.ToString(spell:toTable()))
		btn.spell = spell
		btn.icon:SetTexture(spell:GetIcon())
		btn:Show()
	end

	button:SetScript('OnEnter', function(btn) if btn.spell then UIUtil.Link(btn, btn.spell.link) end end)
	button:SetScript('OnLeave', function(btn) if btn.spell then UIUtil:HideTooltip() end end)
	button:SetScript(
		'OnClick',
		function(btn)
			local element, spell = self.element, btn.spell
			if Util.Objects.IsNumber(element) and not Util.Objects.IsNil(spell) then
				Logging:Trace("OnClick() : %d => %s", self.element, Util.Objects.ToString(btn.spell:toTable()))
				Toolbox:SetElementSpell(element, spell)
			end

			self:Hide()
		end
	)
	return button
end

PositionAndSizeTotemFlyoutBar = function(self)
	local size, spacing, grow =
		Toolbox:GetButtonSize(), Toolbox:GetButtonSpacing(), Toolbox:GetBarGrow()

	local buttonCount = #self.buttons

	for i=1, buttonCount do
		local button = self.buttons[i]
		button:SetSize(size, size)
		button:ClearAllPoints()

		if Util.Objects.Equals(grow, C.Direction.Horizontal) then
			button:SetPoint('TOP', 0, -(((i - 1) * size) + (spacing * i)))
		elseif Util.Objects.Equals(grow, C.Direction.Vertical) then
			button:SetPoint('LEFT', ((i - 1) * size) + (spacing * i), 0)
		end
	end

	if Util.Objects.Equals(grow, C.Direction.Horizontal) then
		self:Height((size * buttonCount) + (spacing * buttonCount) + spacing)
		self:Width(size + spacing * 2)
	else
		self:Width((size * buttonCount) + (spacing * buttonCount) + spacing)
		self:Height(size + spacing * 2)
	end
end
--]]

function Toolbox:GetFrame()
	if not self.totemBar then
		Logging:Trace("GetFrame() : Creating totem bar")
		local tb = TotemBar()

		--f.totemFlyout = CreateTotemFlyoutBar(f)

		--local tsf = CreateFrame('Frame', AddOn:Qualify('TotemBar', 'TotemSetFlyout'), f, "BackdropTemplate")
		--f.setFlyout = tsf
		--f.setFlyout:Hide()

		self.totemBar = tb
		self.totemBar:Show()
	end

	return self.totemBar
end