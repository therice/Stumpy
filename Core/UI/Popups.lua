--- @type AddOn
local _, AddOn = ...
local L, C  = AddOn.Locale, AddOn.Constants
--- @type LibUtil
local Util =  AddOn:GetLibrary("Util")
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibDialog
local Dialog = AddOn:GetLibrary("Dialog")
---@type UI.Util
local UIUtil = AddOn.Require('UI.Util')

local MachuPicchu = "hey, ho, let's go!"

Dialog:Register(C.Popups.ConfirmDeleteTotemSet, {
    text = MachuPicchu,
    on_show = AddOn:Toolbox().DeleteTotemSetOnShow,
    width = 400,
    buttons = {
        {
            text = _G.YES,
            on_click = function(...) AddOn:Toolbox():DeleteTotemSetOnClickYes(...) end,
        },
        {
            text = _G.NO,
            on_click = Util.Functions.Noop
        },
    },
    hide_on_escape = true,
    show_while_dead = true,
})
