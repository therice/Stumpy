--- @type LibUtil
local Util
--- @type LibTotem
local Totem

describe("LibTotem", function()
	setup(function()
		loadfile("Test/TestSetup.lua")(false, 'LibTotem')
		loadfile("Libs/LibTotem-1.0/Test/BaseTest.lua")()
		LoadDependencies()
		ConfigureLogging()
		Util= LibStub('LibUtil-1.2')
		Totem = LibStub('LibTotem-1.0')
	end)

	teardown(function()
		After()
	end)

	describe("functionality", function()
		it("populates totems", function()
			for _, t in pairs(Totem.Constants.Totems.Totem) do
				print(tostring(t))
			end

			local totemCount = Util.Tables.Count(Totem.Constants.Totems.Totem)

			for spellId, index in pairs(Totem.Indices.BySpellId) do
				print(tostring(spellId) .. ' => ' .. tostring(index))
			end

			local bySpellIdCount = Util.Tables.Count(Totem.Indices.BySpellId)

			assert.equal(totemCount, bySpellIdCount)

			assert.Nil(Totem:GetElementBySpellId(1234))
			assert.equal(Totem:GetElementBySpellId(5394), Totem.Constants.Totems.Element.Water)
		end)
	end)
end)