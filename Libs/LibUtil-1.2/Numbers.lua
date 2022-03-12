local MAJOR_VERSION = "LibUtil-1.2"
local MINOR_VERSION = 20502

local lib, minor = LibStub(MAJOR_VERSION, true)
if not lib or next(lib.Numbers) or (minor or 0) > MINOR_VERSION then return end

local Util = lib
--- @class LibUtil.Numbers
local Self = Util.Numbers

function Self.Round(num, p)
    p = math.pow(10, p or 0)
    return math.floor(num * p + .5) / p
end

function Self.Round2(num, p)
    if type(num) ~= "number" then return nil end
    return tonumber(string.format("%." .. (p or 0) .. "f", num))
end

function Self.Between(num, a, b)
    return num > a and num < b
end

function Self.In(num, a, b)
    return num >= a and num <= b
end

function Self.ToHex(num, minLength)
    return ("%." .. (minLength or 1) .. "x"):format(num)
end

function Self.BinaryRepr(n)
    local bits =math.max(1, select(2, math.frexp(n)))
    local t = {}
    for i=bits,0,-1 do
        t[#t+1] = math.floor(n / 2^i)
        n = n % 2^i
    end
    return table.concat(t)
end

local RomanToDecimal = { ["M"] = 1000, ["D"] = 500, ["C"] = 100, ["L"] = 50, ["X"] = 10, ["V"] = 5, ["I"] = 1 }

function Self.IsRoman(roman)
    roman = string.upper(roman):trim()
    for index = 1, string.len(roman) do
        if not RomanToDecimal[string.sub(roman,index,index)] then
            return false
        end
    end

    return true
end

function Self.DecodeRoman(roman)
    roman = string.upper(roman):trim()
    local numeral, i, strlen = 0, 1, string.len(roman)
    while i < strlen do
        local z1, z2 = RomanToDecimal[string.sub(roman,i,i) ], RomanToDecimal[string.sub(roman,i+1,i+1) ]
        if z1 < z2 then
            numeral = numeral + ( z2 - z1 )
            i = i + 2
        else
            numeral = numeral + z1
            i = i + 1
        end
    end

    if i <= strlen then
        numeral = numeral + RomanToDecimal[string.sub(roman,i,i)]
    end

    return numeral
end