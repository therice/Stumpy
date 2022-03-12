--- @type AddOn
local _, AddOn = ...
local L, C = AddOn.Locale, AddOn.Constants
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util =  AddOn:GetLibrary("Util")
--- @type Core.SlashCommands
local SlashCommands = AddOn.Require('Core.SlashCommands')


local function ModeToggle(self, flag)
	local enabled

	if self.mode:Enabled(flag) then
		self.mode:Disable(flag)
		enabled = false
	else
		self.mode:Enable(flag)
		enabled = true
	end

	self:SendMessage(C.Messages.ModeChanged, self.mode, flag, enabled)
end


--- @return boolean
function AddOn:TestModeEnabled()
	return self.mode:Enabled(C.Modes.Test)
end

--- @return boolean
function AddOn:DevModeEnabled()
	return self.mode:Enabled(C.Modes.Develop)
end

--- @return boolean
function AddOn:PersistenceModeEnabled()
	return self.mode:Enabled(C.Modes.Persistence)
end

--- @return boolean
function AddOn:CombatEmulationEnabled()
	return self.mode:Enabled(C.Modes.EmulateCombat)
end

--- @return Toolbox
function AddOn:ToolboxModule()
	return self:GetModule("TotemBar")
end

function AddOn:RegisterChatCommands()
	Logging:Debug("RegisterChatCommands(%s)", self:GetName())
	SlashCommands:BulkSubscribe(
		{
			{'ec', 'emulateCombat'},
			L['chat_commands_ec'],
			function()
				ModeToggle(self, C.Modes.EmulateCombat)
				local emulatedAfter = self:CombatEmulationEnabled()
				self:Print("Combat Emulation = " .. tostring(emulatedAfter))

				-- only generate fake events if not actually in combat lockdown
				if not InCombatLockdown() then
					if emulatedAfter then
						AddOn:OnEnterCombat()
					else
						AddOn:OnExitCombat()
					end
				end
			end
        }
	)
end