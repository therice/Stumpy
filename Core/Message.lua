--- @type AddOn
local _, AddOn = ...
--- @type LibLogging
local Logging =  AddOn:GetLibrary("Logging")
--- @type LibUtil
local Util =  AddOn:GetLibrary("Util")
--- @type LibRx
local Rx = AddOn:GetLibrary("Rx")
--- @type rx.Subject
local Subject = Rx.rx.Subject
local AceEvent = AddOn:GetLibrary('AceEvent')

-- private stuff only for use within this scope
--- @class Core.Messages
--- @field public registered
--- @field public subjects
--- @field public AceEvent
local Messages = AddOn.Package('Core'):Class('Messages')
function Messages:initialize()
	self.registered = {}
	self.subjects = {}
	self.AceEvent = {}
	AceEvent:Embed(self.AceEvent)
end

--- @return rx.Subject
function Messages:Subject(msg)
	local name = msg
	if not self.subjects[name] then
		self.subjects[name] = Subject.create()
	end
	return self.subjects[name]
end

function Messages:HandleMessage(msg, ...)
	Logging:Debug("HandleMessage(%s) : %s", msg, Util.Objects.ToString({ ...}))
	self:Subject(msg):next(msg, ...)
end

function Messages:RegisterMessage(msg)
	Logging:Trace("RegisterMessage(%s)", msg)

	if not self.registered[msg] then
		Logging:Trace("RegisterMessage(%s) : registering 'self' with AceEvent", msg)
		self.registered[msg] = true
		self.AceEvent:RegisterMessage(
			msg,
			function(e, ...) return self:HandleMessage(e, ...) end
		)
	end
end

-- anything attached to 'Message' will be available via the instance
--- @class Core.Message
local Message = AddOn.Instance(
	'Core.Message',
	function()
		return {
			private = Messages()
		}
	end
)

--- @return rx.Subscription
function Message:Subscribe(msg, func)
	assert(Util.Strings.IsSet(msg), "'message' was not provided")
	assert(Util.Objects.IsFunction(func), "'func' was not provided")
	Logging:Trace("Subscribe(%s) : %s", tostring(msg), Util.Objects.ToString(func))
	self.private:RegisterMessage(msg)
	return self.private:Subject(msg):subscribe(func)
end

--- @return table<number, rx.Subscription>
function Message:BulkSubscribe(funcs)
	assert(
		funcs and
			Util.Objects.IsTable(funcs) and
			Util.Tables.CountFn(
				funcs,
				function(v, k)
					if Util.Objects.IsString(k) and Util.Objects.IsFunction(v) then
						return 1
					end
					return 0
				end,
				true, false
			) == Util.Tables.Count(funcs),
		"each 'func' table entry must be an message(string) to function mapping"
	)

	Logging:Trace("BulkSubscribe(%d)", Util.Tables.Count(funcs))

	local subs, idx = {}, 1
	for event, func in pairs(funcs) do
		subs[idx] = self:Subscribe(event, func)
		idx = idx + 1
	end
	return subs
end
