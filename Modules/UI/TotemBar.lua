--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type UI.Native
local UI = AddOn.Require('UI.Native')
--- @type LibWindow
local Window = AddOn:GetLibrary('Window')
--- @type TotemBar
local TotemBar = AddOn:GetModule("TotemBar", true)
--- @type Models.Totem.Totems
local Totems = AddOn.RequireOnUse('Models.Totem.Totems')
local CooldownFrame_Set = CooldownFrame_Set
local MAX_TOTEMS = MAX_TOTEMS

-- todo : replace these with DB values
local DefaultTextureByElement = {
	[C.TotemElements.Fire]  = 135825,
	[C.TotemElements.Earth] = 136098,
	[C.TotemElements.Water] = 135127,
	[C.TotemElements.Air]   = 136114,
}

function TotemBar:GetSize()
	return self.db.profile.size
end

function TotemBar:GetSpacing()
	return self.db.profile.spacing
end

function TotemBar:GetGrow()
	return self.db.profile.grow
end

function TotemBar:GetSort()
	return self.db.profile.sort
end

function TotemBar:GetFrame()
	if not self.frame then
		local f = CreateFrame('Frame', AddOn:Qualify('TotemBar'), UIParent, BackdropTemplateMixin and "BackdropTemplate")
		f.buttons = {}

		local storage = AddOn.db and Util.Tables.Get(AddOn.db.profile, 'ui.TotemBar') or {}
		f:EnableMouse(true)
		f:SetScale(storage.scale)
		Window:Embed(f)
		f:RegisterConfig(storage)
		f:RestorePosition()
		f:MakeDraggable()
		f:Show()

		f.CreateButton = function(self, element)
			local button = CreateFrame('Button', self:GetName()..'Totem'..element, self, 'BackdropTemplate')
			button:SetID(element)
			button:SetTemplate()
			button:StyleButton()
			button:Hide()

			button.holder = CreateFrame('Frame', nil, button)
			button.holder:SetAlpha(0)
			button.holder:SetAllPoints()

			button.iconTexture = button:CreateTexture(nil, 'ARTWORK')
			button.iconTexture:SetTexCoord(unpack({0.08, 0.92, 0.08, 0.92}))
			button.iconTexture:SetInside()

			button.cooldown = CreateFrame('Cooldown', button:GetName()..'Cooldown', button, 'CooldownFrameTemplate')
			button.cooldown:SetReverse(true)
			button.cooldown:SetInside()

			button:Show()

			return button
		end

		f.UpdateButton = function(self, totem)
			local button = self.buttons[totem.element]

			if totem.present then
				button.iconTexture:SetTexture(totem.icon)
				button.iconTexture:SetDesaturated(nil)
				CooldownFrame_Set(button.cooldown, totem.startTime, totem.duration, 1, true, 1)
			else
				-- button.iconTexture:SetTexture(DefaultTextureByElement[totem.element])
				button.iconTexture:SetDesaturated(1)
				CooldownFrame_Set(button.cooldown, 0, 0)
			end

		end

		f.CreateButtons = function(self)
			for element = 1, MAX_TOTEMS do
				self.buttons[element] = self:CreateButton(element)
			end
		end

		f.PositionAndSize = function(self)
			local size, spacing, grow, sort =
				TotemBar:GetSize(), TotemBar:GetSpacing(), TotemBar:GetGrow(), TotemBar:GetSort()

			for i=1, MAX_TOTEMS do
				local button = self.buttons[i]
				local prevButton = self.buttons[i-1]
				button:Size(size)
				button:ClearAllPoints()

				if Util.Objects.Equals(grow, C.Direction.Horizontal) and Util.Objects.Equals(sort, C.Sort.Ascending) then
					if i == 1 then
						button:Point('LEFT', self, 'LEFT', spacing, 0)
					elseif prevButton then
						button:Point('LEFT', prevButton, 'RIGHT', spacing, 0)
					end
				elseif Util.Objects.Equals(grow, "VERTICAL") and Util.Objects.Equals(sort, C.Sort.Ascending) then
					if i == 1 then
						button:Point('TOP', self, 'TOP', 0, -spacing)
					elseif prevButton then
						button:Point('TOP', prevButton, 'BOTTOM', 0, -spacing)
					end
				elseif Util.Objects.Equals(grow, C.Direction.Horizontal) and Util.Objects.Equals(sort, C.Sort.Descending) then
					if i == 1 then
						button:Point('RIGHT', self, 'RIGHT', -spacing, 0)
					elseif prevButton then
						button:Point('RIGHT', prevButton, 'LEFT', -spacing, 0)
					end
				else
					if i == 1 then
						button:Point('BOTTOM', self, 'BOTTOM', 0, spacing)
					elseif prevButton then
						button:Point('BOTTOM', prevButton, 'TOP', 0, spacing)
					end
				end
			end

			if Util.Objects.Equals(grow, C.Direction.Horizontal) then
				self:Width(size * (MAX_TOTEMS) + spacing*(MAX_TOTEMS) + spacing)
				self:Height(size + spacing *2)
			else
				self:Height(size * (MAX_TOTEMS) + spacing*(MAX_TOTEMS) + spacing)
				self:Width(size + spacing *2)
			end
		end

		f:CreateButtons()
		f:PositionAndSize()

		self.frame = f
	end

	return self.frame
end

--- @param event string
--- @param totem Models.Totem.Totem
function TotemBar:Update(event, totem)
	Logging:Debug("Update(%s) : %s", event, Util.Objects.ToString(totem:toTable()))

	if self.frame then
		if Util.Objects.Equals(Totems().Events.TotemUpdated, event) then
			self.frame:UpdateButton(totem)
		end
	end
end