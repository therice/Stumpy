--- @type AddOn
local _, AddOn = ...
--- @type LibUtil
local Util = AddOn:GetLibrary("Util")
--- @type LibLogging
local Logging = AddOn:GetLibrary("Logging")
--- @type Models.Totem.Totems
local Totems = AddOn.RequireOnUse('Models.Totem.Totems')

--- @class Models.Totem.TotemTimer
local TotemTimer = AddOn.Package('Models.Totem'):Class('TotemTimer')
function TotemTimer:initialize(name, fn, interval)
	--- @type string
	self.name = name
	--- @type function<Models.Totem.Totem>
	self.fn = fn
	--- @type number
	self.interval = interval
	--- @type table<number>
	self.totems = {}
	--- @type table
	self.timer = nil
end

function TotemTimer:GetTotemCount()
	return Util.Tables.CountOnly(self.totems, true)
end

local function ElementFromTotem(totem)
	if Util.Objects.IsInstanceOf(totem,  AddOn.Package('Models.Totem').Totem) then
		return totem:GetElement()
	elseif Util.Objects.IsString(totem) then
		return tostring(totem)
	elseif Util.Objects.IsNumber(totem) then
		return totem
	end

	error(format("Unsupported type '%s'", type(totem)))
end

--- @param totem Models.Totem.Totem|string|number
function TotemTimer:AddTotem(totem)
	self.totems[ElementFromTotem(totem)] = true
	if not self:IsRunning() then
		self:Start()
	end
end

--- @param totem Models.Totem.Totem|string|number
function TotemTimer:RemoveTotem(totem)
	self.totems[ElementFromTotem(totem)] = false
	if self:IsRunning() and self:GetTotemCount() == 0 then
		self:Cancel()
	end
end

--- @param self Models.Totem.TotemTimer
local function Execute(self)
	Logging:Trace("Execute() : %s", Util.Objects.ToString(self.totems))
	for element, execute in pairs(self.totems) do
		if execute then
			Util.Functions.try(
				function() self.fn(Totems():Get(element)) end
			).catch(
				function(error) Logging:Error("TotemTimer.Execute(#s, %d) : %s", self.name, element, error) end
			)
		end
	end
end

function TotemTimer:IsRunning()
	return self.timer and not Util.Objects.Default(self.timer.cancelled, false)
end

function TotemTimer:Cancel()
	if self.timer then
		AddOn:CancelTimer(self.timer)
		self.timer = nil
	end
end

function TotemTimer:Start()
	if not self.timer then
		AddOn.Timer.After(
			0,
			function()
				self:Cancel()
				self.timer = AddOn:ScheduleRepeatingTimer(function() Execute(self) end, self.interval)
			end
		)
	end
end

function TotemTimer:__tostring()
	return format("TotemTimer(%s)", self.name)
end

local TestTimer = TotemTimer("LogTotem", function(totem) Logging:Debug("LogTotem(%s)", tostring(totem)) end, 2)

--- @class Models.Totem.TotemTimers
local TotemTimers = AddOn.Instance(
	'Models.Totem.TotemTimers',
	function()
		return {
			--- @type table<string, Models.Totem.TotemTimer>
			timers = {}
		}
	end
)

--- @param timer Models.Totem.TotemTimer|string|nil nil means to add to all timers
--- @param totem Models.Totem.Totem
function TotemTimers:AddTotem(timer, totem)
	Util.Tables.Call(
		self.timers,
		function(t)
			if t and (Util.Objects.IsEmpty(timer) or Util.Objects.Equals(t.name, timer.name)) then
				t:AddTotem(totem)
			end
		end
	)
end

--- @param timer Models.Totem.TotemTimer|string|nil nil means to add to all timers
--- @param totem Models.Totem.Totem
function TotemTimers:RemoveTotem(timer, totem)
	Util.Tables.Call(
		self.timers,
		function(t)
			if t and (Util.Objects.IsEmpty(timer) or Util.Objects.Equals(t.name, timer.name)) then
				t:RemoveTotem(totem)
			end
		end
	)
end

--- @param timer Models.Totem.TotemTimer
function TotemTimers:AddTimer(timer)
	if not timer then return end
	Logging:Debug("AddTimer(%s)", tostring(timer))
	self.timers[timer.name] = timer
end


--[[
--- @param timer Models.Totem.TotemTimer|string
function TotemTimers:RemoveTimer(timer)
	if not timer then return end
	local name
	if Util.Objects.IsInstanceOf(timer,TotemTimer) then
		name = timer.name
	elseif Util.Objects.IsString(timer) then
		name = timer
	else
		return
	end

	self.timers[name] = nil
end
--]]

--[[
do
	-- setup standard timers
	TotemTimers:AddTimer(TestTimer)
end
--]]