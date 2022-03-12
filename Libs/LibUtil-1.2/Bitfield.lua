local MAJOR_VERSION = "LibUtil-1.2"
local MINOR_VERSION = 20502

local lib, minor = LibStub(MAJOR_VERSION, true)
if not lib or next(lib.Bitfield) or (minor or 0) > MINOR_VERSION then return end

local Util = lib
--- @class LibUtil.Bitfield
local Self = Util.Bitfield
--- @type LibClass
local Class = LibStub("LibClass-1.0")

local function bbit(p) return 2 ^ (p - 1) end
local function hasbit(x, p) return x % (p + p) >= p end
local function setbit(x, p) return hasbit(x, p) and x or x + p end
local function clearbit(x, p) return hasbit(x, p) and x - p or x end

--- @class LibUtil.Bitfield.Bitfield
local Bitfield = Class('Bitfield')
Self.Bitfield = Bitfield

function Bitfield:initialize(initial)
	self.bitfield = bbit(initial)
end

function Bitfield:Enable(...)
	for _, p in Util.Objects.Each(...) do
		self.bitfield = setbit(self.bitfield, p)
	end
	return self
end

function Bitfield:Disable(...)
	for _, p in Util.Objects.Each(...) do
		self.bitfield = clearbit(self.bitfield, p)
	end
	return self
end

function Bitfield:ToggleBits(...)
	for _, b in Util.Objects.Each(...) do
		self.bitfield = bit.bxor(self.bitfield, bbit(b))
	end
	return self
end

function Bitfield:Enabled(flag)
	return bit.band(self.bitfield, flag) == flag
end

function Bitfield:Disabled(flag)
	return bit.band(self.bitfield, flag) == 0
end

function Bitfield:BitEnabled(b)
	return bit.band(self.bitfield, bbit(b)) ~= 0
end

function Bitfield:BitDisabled(bit)
	return not self:BitEnabled(bit)
end

function Bitfield:AnyBitEnabled()
	local bits = math.max(1, select(2, math.frexp(self.bitfield)))
	for i=bits,0,-1 do
		if self:BitEnabled(i) then
			return true
		end
	end
	return false
end

function Bitfield:__tostring()
	return Util.Numbers.BinaryRepr(self.bitfield)
end

--- @return LibUtil.Bitfield.Bitfield
function Self.Create(initial)
	return Bitfield(initial or 0)
end

function Self.CreateAndEnableBits(...)
	return Self.Create():ToggleBits(...)
end