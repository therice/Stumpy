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
--- @type Toolbox
local Toolbox = AddOn:GetModule("Toolbox", true)
--- @type LibDialog
local Dialog = AddOn:GetLibrary("Dialog")
--- @type LibTotem
local LibTotem = AddOn:GetLibrary("Totem")
--- @type Models.Spell.Spells
local Spells = AddOn.RequireOnUse('Models.Spell.Spells')

local Tabs = {
	[L["totems"]]  = L["totems_desc"],
	[L["general"]] = L["general_desc"],
}

function Toolbox:LayoutTotemSetInterface(container)
	local module = self

	container.setList =
		UI:New('ScrollList', container)
	        :Size(230, 540)
	        :Point(1, -66)
	        :LinePaddingLeft(2)
	        :ScrollWidth(12)
	        :LineTexture(15, UIUtil.ColorWithAlpha(C.Colors.White, 0.5), UIUtil.ColorWithAlpha(C.Colors.ItemArtifact, 0.6))
	        :HideBorders()
			:LineTextFormatter(function(s) return s.name end)
			:IconSupplier(function(s) return s.icon end)
			:SortFunction(
				function(list)
					return Util.Tables.Map(
						Util.Tables.Sort(Util.Tables.Values(list), function(s1, s2) return s1.name < s2.name end),
						function(s) return s.id end
					)
				end
			)
	container.setList.frame.ScrollBar:Size(10,0):Point("TOPRIGHT",0,0):Point("BOTTOMRIGHT",0,0)
	container.setList.frame.ScrollBar.buttonUp:HideBorders()
	container.setList.frame.ScrollBar.buttonDown:HideBorders()
	container.setList:SetList(module.totemSets:GetAll())
	container.setList.SetListValue = function(self, index, button, ...)
		self:GetParent():Update()
	end
	-- returns the currently selected configuration
	--- @return Models.Totem.TotemSet
	local function SelectedTotemSet()
		return container.setList:Selected()
	end

	-- background in which  buttons are located
	local bg =
		UI:New('DecorationLine', container, true,"BACKGROUND",-5)
	        :Point("TOPLEFT", container.setList, 0, 20)
	        :Point("BOTTOMRIGHT",container.setList,"TOPRIGHT",0, 0)

	-- background (colored) which extends beyond the previous one
	container.banner =
		UI:New('DecorationLine', container, true, "BACKGROUND",-5)
	        :Point("TOPLEFT", bg, "TOPRIGHT", 0, 0)
	        :Point("BOTTOMRIGHT", container, "TOPRIGHT", -2, -66)
	        :Color(0.25, 0.78, 0.92, 1, 0.50)

	-- vertical lines on right side of list
	UI:New('DecorationLine', container)
		:Point("TOPLEFT", container.setList,"TOPRIGHT", -1, 1)
	    :Point("BOTTOMLEFT",container:GetParent(),"BOTTOM",0, 0)
	    :Size(1,0)

	container.delete =
		UI:New('ButtonMinus', container)
			:Point("TOPRIGHT", container.setList, "TOPRIGHT", -5, 20)
	        :Tooltip(L["delete"])
	        :Size(18,18)
	        :OnClick(function(...) module.OnDeleteSetClick(SelectedTotemSet()) end)

	container.add =
		UI:New('ButtonPlus', container)
	        :Point("TOPRIGHT", container.delete, "TOPRIGHT", -25, 0)
	        :Tooltip(L["add"])
	        :Size(18,18)
	        :OnClick(
				function(...)
					local set = module.totemSets:Create()
					Logging:Debug("Add() : %s", tostring(set))
					container.setList:Add(set)
					module.totemSets:Add(set)
					container.setList:SetToLast()
					container:Update()
				end
			)

	-- various tabs related to set attributes
	container.setSettings =
		UI:New('Tabs', container, unpack(Util.Tables.Sort(Util.Tables.Keys(Tabs))))
			:Point("TOPLEFT", container.banner, "TOPLEFT", 0, -20):Size(600, 570)
	container.setSettings:SetBackdropBorderColor(0, 0, 0, 0)
	container.setSettings:SetBackdropColor(0, 0, 0, 0)
	container.setSettings:First():SetPoint("TOPLEFT", 0, 20)
	container.setSettings:SetTo(1)

	for index, key in ipairs(Util.Tables.Sort(Util.Tables.Keys(Tabs))) do
		container.setSettings.tabs[index]:Tooltip(Tabs[key])
	end

	container.SetButtonsEnabled = function(self, set)
		local enabled = set or false
		self.delete:SetEnabled(enabled)
	end

	container.Update = function(self)
		self:SetButtonsEnabled(SelectedTotemSet())

		for _, childTab in self.setSettings:IterateTabs() do
			if childTab.Update then
				childTab:Update()
			end
		end
	end

	container.Refresh = function(self, set)
		--Logging:Debug("Refresh()")
		if set then
			self.setList:Set(set, function(item) return Util.Strings.Equal(set.id, item.id) end)
		else
			self.setList:SetList(module.totemSets:GetAll())
		end
		self.setList:Update()
	end

	self:LayoutTotemSetGeneralTab(
		container.setSettings:GetByName(L["general"]),
		SelectedTotemSet
	)

	self:LayoutTotemSetTotemsTab(
		container.setSettings:GetByName(L["totems"]),
		SelectedTotemSet
	)

	container:Update()
	self.setInterfaceFrame = container
end

function Toolbox.OnDeleteSetClick(set)
	Dialog:Spawn(C.Popups.ConfirmDeleteTotemSet, set)
end

function Toolbox.DeleteTotemSetOnShow(frame, set)
	UIUtil.DecoratePopup(frame)
	frame.text:SetText(format(L['confirm_delete_entry'], UIUtil.ColoredDecorator(C.Colors.ItemArtifact):decorate(set.name)))
end

function Toolbox:DeleteTotemSetOnClickYes(_, set)
	Logging:Debug("DeleteTotemSetOnClickYes(%s)", tostring(set))
	self.totemSets:Remove(set)
	self.setInterfaceFrame.setList:RemoveSelected()
	self.setInterfaceFrame:Update()
end

local MarcoIcons = Util.Memoize.Memoize(
	function()
		local icons = GetMacroIcons()
		return Util.Tables.CopyFilter(
			icons,
			function(v) return Util.Objects.IsSet(v) end
		)
	end
)

local IconWidth, IconHeight, IconsPerRow, IconRows, IconPadding = 32, 32, 10, 5, 5
local IconListWidth, IconListHeight = (IconWidth + IconPadding) * IconsPerRow,  (IconHeight + IconPadding) * IconRows

function Toolbox:LayoutTotemSetGeneralTab(tab, setSupplier)
	local module, generalTab = self, tab:GetParent():GetParent()

	tab.icon =
		UI:New('Button', tab, L["icon"])
	        :Size(32, 32)
			:Point("TOPLEFT", tab, "TOPLEFT", 15, -30)
			:Tooltip(L['totem_set_icon_desc'])
	tab.icon.Text:Hide()
	tab.icon:HideBorders()
	tab.icon.SetIcon = function(self, id, save)
		save = Util.Objects.Default(save, false)
		self:SetNormalTexture(id)
		self.PushedTexture:SetTexture(id)

		if save then
			local set = setSupplier()
			set.icon = tonumber(id)
			module.totemSets:Update(set, 'icon')
			generalTab:Refresh(set)
		end
	end
	tab.icon:OnClick(
		function(_)
			local iconList = tab.iconList
			if iconList:IsVisible() then
				iconList:Hide()
			else
				iconList:Show()
			end
		end
	)

	tab.name =
		UI:New('EditBox', tab)
	        :Size(255,20)
	        :Point("LEFT", tab.icon, "RIGHT", 15, 0)
	        :Tooltip(L["name"], L["totem_set_icon_desc"])
			:OnChange(
				Util.Functions.Debounce(
					function(self, userInput)
						if userInput then
							local set = setSupplier()
							set.name = self:GetText()
							module.totemSets:Update(set, 'name')
							generalTab:Refresh(set)
						end
					end, -- function
					1.5,   -- seconds
					true -- leading
				)
			)


	-- this is the list of available icons
	tab.iconList =
		UI:New('ScrollFrame', tab)
			:Point("TOPLEFT", tab.icon, "BOTTOMLEFT", 0, -10)
			:Size(IconListWidth + 16 --[[ stupid scroll bar width --]], IconListHeight)
			:Height(IconListHeight - (IconHeight * 4))
			:MouseWheelRange(IconsPerRow)
	tab.iconList.ScrollBar:Range(0, #MarcoIcons() - (IconsPerRow * IconRows) + 1, IconsPerRow, true)
	tab.iconList:LayerBorder(0)
	tab.iconList.icons = {}

	for rowIndex=1, ceil(IconListHeight/(IconHeight + IconPadding)) do
		for colIndex=1, ceil(IconListWidth/(IconWidth + IconPadding)) do
			local iconButton =
				UI:NewNamed('Button', tab.iconList.content, AddOn:Qualify(format('TotemSetIcon_%d_%d', rowIndex, colIndex)))
					:Size(IconWidth, IconHeight)
					:Point("TOPLEFT", (colIndex - 1) * (IconWidth + IconPadding), -(rowIndex - 1) * (IconHeight + IconPadding))
					:OnClick(function(self) tab.icon:SetIcon(self.icon, true) end)
			iconButton:HideBorders()
			iconButton.Text:Hide()
			iconButton:SetNormalTexture(136008) -- default that is later replaced
			iconButton:GetNormalTexture():SetTexCoord(unpack({ 0.08, 0.92, 0.08, 0.92}))
			iconButton.SetIcon = function(self, id)
				self.icon = id
				self:SetNormalTexture(id)
				self.PushedTexture:SetTexture(id)
			end
			iconButton:Hide()

			Util.Tables.Push(tab.iconList.icons, iconButton)
		end
	end

	tab.iconList.Update = function(self)
		--Logging:Warn("Update() : %.2f", self.ScrollBar:GetValue())
		local scroll = math.floor(self.ScrollBar:GetValue())
		self:SetVerticalScroll(scroll % IconHeight)
		local start = scroll + 1

		--Logging:Warn("Update() : %d => %d", scroll, start)
		local lineCount = 1
		local icons = MarcoIcons()

		for index = start, #icons do
			local iconButton = self.icons[lineCount]
			if not iconButton then break end

			local iconTexture = icons[index]
			iconButton:SetIcon(iconTexture)
			--Logging:Debug("Update() : %d : %d (%d) => %s", lineCount, index, #icons, tostring(icons[index]))
			iconButton:Show()
			lineCount = lineCount + 1
		end

		for i = lineCount, #self.icons do
			self.icons[i]:Hide()
			--Logging:Warn("Update() : hiding %d", lineCount)
		end
	end

	tab.iconList.ScrollBar.slider:SetScript(
		"OnValueChanged",
		function(self)
			self:GetParent():GetParent():Update()
			self:UpdateButtons()
		end
	)

	tab.SetFieldsEnabled = function(self, set)
		local enabled = set and true or false
		self.name:SetEnabled(enabled)
		self.icon:SetEnabled(enabled)
	end

	-- will be invoked when a set is selected
	tab.Update = function(self)
		if self:IsVisible() then
			local set = setSupplier()
			self:SetFieldsEnabled(set)
			if set then
				self.name:Text(set.name)
				self.icon:SetIcon(set.icon)
			end
		end
	end

	tab.iconList:Update()
	tab.iconList:Hide()

	tab:SetScript("OnShow", function(self) self:Update() end)
	self.setGeneralTab = tab
end

local TotemWidth, TotemHeight = 225, 30

function Toolbox:LayoutTotemSetTotemsTab(tab, setSupplier)
	local module = self

	local function TotemCoord(self, xAdjust, yAdjust)
		xAdjust = Util.Objects.IsNumber(xAdjust) and xAdjust or 0
		yAdjust = Util.Objects.IsNumber(yAdjust) and yAdjust or 0
		return 10 + xAdjust, (-(TotemHeight/4) - ((self.order - 1) * (TotemHeight + (TotemHeight/4)))) + yAdjust
	end

	local function Swap(one, two)
		Logging:Debug("SwapButtons(%d, %d)", one.element, two.element)
		local pointOne, xOne, yOne =  unpack(one.point)
		local pointTwo, _, _, xTwo, yTwo = two:GetPoint()
		local orderOne, orderTwo = one.order, two.order

		one:ClearAllPoints()
		one:SetPoint(pointTwo, xTwo, yTwo)
		one.order = orderTwo

		two:ClearAllPoints()
		two:SetPoint(pointOne, xOne, yOne)
		two.order = orderOne

		--- @type Models.Totem.TotemSet
		local set = setSupplier()
		if set then
			set:SetOrder(one.element, one.order)
			set:SetOrder(two.element, two.order)
			module.totemSets:Update(set, 'totems')
		end
	end

	local function EditOnDragStart(self)
		if self:IsMovable() then
			self:CapturePoint()
			self:StartMoving()
		end
	end

	local function EditOnDragStop(self)
		self:StopMovingOrSizing()

		local target
		for i = 1, #tab.totems do
			local candidate = tab.totems[i]
			if candidate:IsMouseOver() and candidate ~= self then
				target = candidate
				break
			end
		end

		if target then
			Swap(self, target)
		else
			self:RestorePosition()
		end

		self:ClearPoint()
	end

	tab.totems = {}

	for element = 1, LibTotem.Constants.MaxTotems do
		local totem =
			UI:New('EditBox', tab)
		        :Size(TotemWidth, TotemHeight)
				--:ColorBorder(C.Colors.Grey:GetRGBA())
				:BackgroundText(
					tostring(LibTotem.Constants.Totems.ElementIdToName[element]),
					UIUtil.GetTotemColor(element):GetRGBA()
				)

		tab.totems[element] = totem
		totem.element = element
		totem.order = element
		totem:Point("TOPLEFT", TotemCoord(totem))
		totem:SetEnabled(false)
		totem:SetMovable(false)

		local dd =
			UI:New('Dropdown', totem)
				:Size(TotemWidth - 40)
				:Point("RIGHT", totem, "RIGHT", -5, 0)
				:SetTextDecorator(function(item) return item.value.name end)
				:SetList(Spells():GetHighestRanksByTotemElement(element))
				:SetClickHandler(
					function(_, _, item)
						--- @type Models.Totem.TotemSet
						local set = setSupplier()
						if set then
							set:SetSpell(element, tonumber(item.value:GetId()))
							module.totemSets:Update(set, 'totems')
						end

						return true
					end
				)
		dd:IterateItems(function(item) item.icon = item.value.icon end)
		dd:SetFrameLevel(totem:GetFrameLevel() + 1)
		totem.dd = dd

		totem.SetActive = function(self, active)
			self:SetMovable(active)
			self:RegisterForDrag(active and C.Buttons.Left or nil)
			self:SetScript("OnDragStart", active and EditOnDragStart or nil)
			self:SetScript("OnDragStop", active and EditOnDragStop or nil)
			self.dd:SetEnabled(active)
		end

		totem.ClearPoint = function(self)
			self.point = nil
		end

		totem.CapturePoint = function(self)
			local point, _, _, x, y = self:GetPoint()
			self.point = {point, x, y}
		end

		totem.RestorePosition = function(self)
			self:ClearAllPoints()
			self:SetPoint(self.point[1], self.point[2], self.point[3])
		end

		totem:SetActive(true)
	end

	tab.UpdateTotems = function(self)
		--Logging:Debug("UpdateTotems()")
		--- @type Models.Totem.TotemSet
		local set = setSupplier()
		if set then
			for _, totem in pairs(self.totems) do
				local order, spell = set:Get(totem.element)
				--Logging:Debug("UpdateTotems(%d) : %s, %s", totem.element, tostring(order), tostring(spell))
				totem.order = order
				totem.dd:SetViaValue(spell)
				totem:Point("TOPLEFT", TotemCoord(totem))
			end
		end
	end

	tab.SetFieldsEnabled = function(self, set)
		local enabled = set or false
		for _, totem in pairs(self.totems) do
			totem:SetActive(enabled)
		end
	end

	tab.Update = function(self)
		--Logging:Debug("Update()")
		if self:IsVisible() then
			self:SetFieldsEnabled(setSupplier())
			self:UpdateTotems()
		end
	end

	tab:SetScript("OnShow", function(self) self:Update() end)
	self.setTotemsTab = tab
end