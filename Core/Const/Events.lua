--- @type AddOn
local _, AddOn = ...
local E = AddOn.Constants.Events

AddOn.Events = {
	[E.PlayerEnteringWorld] = "OnPlayerEnteringWorld",
	[E.PlayerRegenEnabled]  = "OnExitCombat",
	[E.PlayerRegenDisabled] = "OnEnterCombat",
	[E.UpdateMacros]        = "OnUpdateMacros",
}