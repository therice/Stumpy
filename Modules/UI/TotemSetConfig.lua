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

function Toolbox:LayoutTotemSetInterface(container)

end