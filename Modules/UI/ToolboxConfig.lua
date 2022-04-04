--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type UI.Native
local UI = AddOn.Require('UI.Native')
--- @type Toolbox
local Toolbox = AddOn:GetModule("Toolbox", true)

local Tabs = {
	[L["bar"]] = L["bar_desc"],
	[L["totem_flyout"]] = L["totem_flyout_desc"],
	[L["totem_set_flyout"]] = L["totem_set_flyout_desc"]
}

function Toolbox:LayoutConfigInterface(container)
	container.tabs =
		UI:New('Tabs', container, unpack(Util.Tables.Sort(Util.Tables.Keys(Tabs))))
	        :Point(0, -36):Size(1000, 580):SetTo(1)
	container.tabs:SetBackdropBorderColor(0, 0, 0, 0)
	container.tabs:SetBackdropColor(0, 0, 0, 0)
	container.tabs:First():SetPoint("TOPLEFT", 0, 20)

	for index, key in ipairs(Util.Tables.Sort(Util.Tables.Keys(Tabs))) do
		container.tabs.tabs[index]:Tooltip(Tabs[key])
	end

	self:LayoutBarTab(container.tabs:Get(1))
	self:LayoutTotemFlyoutTab(container.tabs:Get(2))
	self:LayoutSetFlyoutTab(container.tabs:Get(3))

	self.configInterfaceFrame = container
end


local function CreateSizeAndSpacingWidgets(tab)
	local size =
		UI:New('Slider', tab, true)
			:SetText(L["button_size"])
			:Tooltip(L["button_size_desc"])
			:Size(250)
			:EditBox()
	local spacing =
		UI:New('Slider', tab, true)
	        :SetText(L["button_spacing"])
	        :Tooltip(L["button_spacing_desc"])
	        :Size(250)
	        :EditBox()

	return size, spacing
end

function Toolbox:LayoutBarTab(tab)
	local module = self

	tab.orientationLabel =
		UI:New('Text', tab, L["orientation"]):Point("TOPLEFT", tab, "TOPLEFT", 15, -40)
	tab.orientation =
		UI:New('Dropdown', tab)
			:Size(250)
			:Tooltip(L["orientation_desc"])
			:Point("TOPLEFT", tab.orientationLabel, "BOTTOMLEFT", 0, -5)
			:SetList(Util.Tables.Flip(C.Direction))
			:Datasource(
				module,
				module.db.profile,
				'toolbox.grow'
			)

	local size, spacing = CreateSizeAndSpacingWidgets(tab)

	tab.size =
		size:Point("TOPLEFT", tab.orientation, "BOTTOMLEFT", 0, -25):Range(40, 75)
			:Datasource(
				module,
				module.db.profile,
				'toolbox.size'
			)

	tab.spacing =
		spacing:Point("TOPLEFT", tab.size, "BOTTOMLEFT", 0, -40):Range(0, 15)
			:Datasource(
				module,
				module.db.profile,
				'toolbox.spacing'
			)

	tab.pulse =
		UI:New('Slider', tab, true)
	        :SetText(L["pulse_timer"])
	        :Tooltip(L["pulse_timer_desc"])
	        :Size(250)
	        :EditBox()
			:Point("TOPLEFT", tab.spacing, "BOTTOMLEFT", 0, -40):Range(10, 20)
			:Datasource(
				module,
				module.db.profile,
				'pulse.size'
			)

	self.barTab = tab
end

local function CreateLayoutWidgets(tab)
	local label = UI:New('Text', tab, L["layout"])
	local layout =
		UI:New('Dropdown', tab)
	        :Size(250)
	        :Tooltip(L["layout_desc"])
	        :Point("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
	        :SetList(Util.Tables.Flip(C.Layout))

	return label, layout, CreateSizeAndSpacingWidgets(tab)
end

function Toolbox:LayoutTotemFlyoutTab(tab)
	local module = self

	local label, layout, size, spacing = CreateLayoutWidgets(tab)

	tab.layoutLabel = label:Point("TOPLEFT", tab, "TOPLEFT", 15, -20)
	tab.layout =
		layout:Point("TOPLEFT", tab.layoutLabel, "BOTTOMLEFT", 0, -5)
	        :Datasource(
				module,
				module.db.profile,
				'flyout.layout'
			)
	tab.size =
		size:Point("TOPLEFT", tab.layout, "BOTTOMLEFT", 0, -25):Range(25, 75)
		    :Datasource(
				module,
				module.db.profile,
				module.db.profile,
				'flyout.size'
			)

	tab.spacing =
		spacing:Point("TOPLEFT", tab.size, "BOTTOMLEFT", 0, -40):Range(0, 15)
	       :Datasource(
				module,
				module.db.profile,
				'flyout.spacing'
			)

	self.totemTab = tab
end

function Toolbox:LayoutSetFlyoutTab(tab)
	local module = self

	local label, layout, size, spacing = CreateLayoutWidgets(tab)

	tab.layoutLabel = label:Point("TOPLEFT", tab, "TOPLEFT", 15, -20)
	tab.layout =
		layout:Point("TOPLEFT", tab.layoutLabel, "BOTTOMLEFT", 0, -5)
			:Datasource(
				module,
				module.db.profile,
				'set.layout'
			)
	tab.size =
		size:Point("TOPLEFT", tab.layout, "BOTTOMLEFT", 0, -25):Range(25, 75)
			:Datasource(
				module,
				module.db.profile,
				'set.size'
			)

	tab.spacing =
		spacing:Point("TOPLEFT", tab.size, "BOTTOMLEFT", 0, -40):Range(0, 15)
			:Datasource(
				module,
				module.db.profile,
				'set.spacing'
			)

	self.totemSetTab = tab
end