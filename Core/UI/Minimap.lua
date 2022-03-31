--- @type AddOn
local name, AddOn = ...
local L, C, Util, DbIcon, DataBroker =
    AddOn.Locale, AddOn.Constants, AddOn:GetLibrary("Util"), AddOn:GetLibrary("DbIcon"), AddOn:GetLibrary("DataBroker")
local MinimapButton = AddOn.Package('Core.UI'):Class('MinimapButton')
local TooltipEntry = "|cFFCFCFCF%s:|r %s"

function MinimapButton:initialize()
    self.dataBroker = DataBroker:NewDataObject(
            name,
            {
                type = 'launcher',
                text = name,
                icon = format("Interface\\AddOns\\%s\\Media\\Textures\\icon.blp", name),
                OnTooltipShow = function(tooltip)
                    tooltip:AddDoubleLine(format("|cfffe7b2c%s|r", name), format("|cffFFFFFF%s|r", tostring(AddOn.version)))
                    tooltip:AddLine(format(TooltipEntry, L["left_click"], L["open_config"]))
                    tooltip:AddLine(format(TooltipEntry, L["shift_left_click"], L['logging_window_toggle']))
                end,
                OnClick = function(_, button)
                    if button == C.Buttons.Right then

                    elseif button == C.Buttons.Left then
                        if IsShiftKeyDown() then
                            AddOn:Logging():Toggle()
                        else
                            AddOn:ToggleLaunchpad()
                        end
                    end
                end,
            }
    )
end

local mm = MinimapButton()
function AddOn:AddMinimapButton()
    local db = {}
    if AddOn.db then db = Util.Tables.Get(AddOn.db, 'profile.ui.minimap') or {} end
    DbIcon:Register(name, mm.dataBroker, db)
end