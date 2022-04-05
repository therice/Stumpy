--- @type AddOn
local _, AddOn = ...
local C = AddOn.Constants
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type LibLogging
local Logging = AddOn:GetLibrary("Logging")
--- @type Models.Totem.TotemSet
local TotemSet = AddOn.Package('Models.Totem').TotemSet
--- @type Models.Spell.Spells
local Spells = AddOn.RequireOnUse('Models.Spell.Spells')

-- https://wowpedia.fandom.com/wiki/API_GetMacroInfo
-- https://wowpedia.fandom.com/wiki/API_EditMacro
local GetMacroInfo, EditMacro = _G.GetMacroInfo, _G.EditMacro
local MaxMacros, MacroMarker = 138, C.Macros.Prefix .. '(%w*)[ ]?[^\n]*'

local MacroCommandToRegex = Util.Memoize.Memoize(
	function(cmd)
		return cmd, C.Macros.Prefix .. '(' .. cmd .. ')[ ]?([^\n]*)'
	end
)

--- @class Models.Macros.Macro
local Macro = AddOn.Package('Models.Macros'):Class('Macro')
function Macro:initialize(index, body)
	self.index = index
	self.body = body
	self.parsed = {}
	self.pendingSave = false
end

function Macro:Parse()
	local augmentation, skipFn
	for i, line in pairs(Util.Strings.Split(self.body, '\n')) do
		if not skipFn or not(skipFn(line)) then
			Util.Tables.Push(self.parsed, line)
			local augment, args = self:ShouldAugment(line)
			if augment then
				args = args and Util.Tables.Map(Util.Strings.Split(args, ' '), function(v) return Util.Strings.Trim(v) end) or {}
				Logging:Debug("Parse(%d) :  %s (args)", i, Util.Objects.ToString(args))
				augmentation, skipFn = self:Augment(unpack(args))
				if augmentation and Util.Tables.Count(augmentation) > 0 then
					for _, lineToAdd in pairs(augmentation) do
						Util.Tables.Push(self.parsed, lineToAdd)
					end

					self.pendingSave = true
				end
			end
		end
	end

	Logging:Debug("Parse(%d)[after] :  %s", self.index, Util.Objects.ToString(self.parsed))
end

function Macro:ShouldAugment(line)
	line = Util.Strings.Trim(line)
	local command, regex = MacroCommandToRegex(self:GetCommand())

	if Util.Strings.IsEmpty(line) or Util.Strings.IsEmpty(command) then
		return false
	end

	local cmd, args = line:match(regex)
	Logging:Debug("ShouldAugment(%s, %s) : %s", command, line, tostring(cmd))

	if Util.Strings.Equal(command, cmd) then
		return true, args
	end

	return false
end

function Macro:IsSavePending()
	return self.pendingSave
end

function Macro:Save()
	if self:IsSavePending() and not AddOn:InCombatLockdown() then
		EditMacro(self.index, nil, nil, Util.Strings.Join('\n', unpack(self.parsed)))
		self.pendingSave = false
	end
end

function Macro:Augment(...)
	error('No augmentation associated with macro')
end

function Macro:GetCommand()
	error('No command associated with macro')
end

function Macro:__tostring()
	return format("Macro(%s, %d) : %s", tostring(self:GetCommand()), self.index, self.body)
end

local CAST_SEQUENCE = "/castsequence"

--- @class Models.Macros.CastSequence
local CastSequence = AddOn.Package('Models.Macros'):Class('CastSequence', Macro)
function CastSequence:initialize(index, body)
	Macro.initialize(self, index, body)
end

function CastSequence:GetCommand()
	return C.Macros.CastSequence
end

local function CastSequenceSkipFn()
	local skipped = 0

	return function(line)
		if skipped < 1 then
			local skipLine =  line and Util.Strings.StartsWith(Util.Strings.ToString(line), CAST_SEQUENCE)
			if skipLine then
				skipped = skipped + 1
			end

			return skipLine
		end

		return false
	end
end

function CastSequence:Augment(reset)
	reset = tonumber(reset) or 6
	Logging:Debug("Augment() : %d (reset)", reset)

	local totemSet = AddOn:Toolbox():GetTotemSet()
	if totemSet then
		local spells = {}

		for element, spellId in totemSet:OrderedIterator() do
			Logging:Debug("Augment() : %d => %d", element, spellId)
			local spell = Spells():GetById(spellId)
			if Util.Objects.IsSet(spell) then
				Util.Tables.Push(spells, spell:GetName())
			end
		end

		local allSpells = Util.Tables.Count(spells) > 0 and Util.Strings.Join(", ", unpack(spells)) or ""
		Logging:Debug("Augment() : %s", allSpells)
		return {format("%s reset=%d %s", CAST_SEQUENCE, reset, allSpells)}, CastSequenceSkipFn()
	end

	return nil, Util.Functions.False
end

local CAST = "/cast"

--- @class Models.Macros.CastByElement
local CastByElement = AddOn.Package('Models.Macros'):Class('CastByElement', Macro)
function CastByElement:initialize(index, body)
	Macro.initialize(self, index, body, C.Macros.CastByElement)
end

function CastByElement:GetCommand()
	return C.Macros.CastByElement
end

local function CastByElementSkipFn()
	local skipped = 0

	return function(line)
		if skipped < 1 then
			local skipLine =  line and Util.Strings.StartsWith(Util.Strings.ToString(line), CAST)
			if skipLine then
				skipped = skipped + 1
			end

			return skipLine
		end

		return false
	end
end

function CastByElement:Augment(element)
	element = tonumber(element) or 0
	Logging:Debug("Augment() : %d (element)", element)

	local totemSet = AddOn:Toolbox():GetTotemSet()
	if totemSet then
		local _, spell = totemSet:Get(element)
		if spell then
			local spellName = spell:GetName()
			Logging:Debug("Augment() : %s", spellName)
			return {format("%s %s", CAST, spellName)}, CastByElementSkipFn()
		end
	end

	return nil, Util.Functions.False
end

--- @class Models.Macros.Macros
--- @field public macros table<number, Models.Macros.Macro>
local Macros = AddOn.Instance(
	'Models.Macros.Macros',
	function()
		return {
			mappings = {
				[C.Macros.CastByElement] = CastByElement,
				[C.Macros.CastSequence]  = CastSequence,
			}
		}
	end
)

function Macros:LoadAndParse()
	Logging:Debug("LoadAndParse()")
	for index = 1, MaxMacros do
		local _, _, body = GetMacroInfo(index)
		-- Logging:Debug("LoadAndParse(%d) : %s", index, tostring(body))
		-- if there is a body for macro and it matches any of the supported addon macros
		-- please note, currently do not support multiple macro types in the same macro
		if Util.Strings.IsSet(body) then
			local macroName = body:match(MacroMarker)
			if Util.Strings.IsSet(macroName) then
				local macro = self.mappings[macroName](index, body)
				--Logging:Debug("LoadAndParse(%d) : %s", index, tostring(macro))
				macro:Parse()
				if macro:IsSavePending() then
					macro:Save()
				end
			end
		end
	end
end