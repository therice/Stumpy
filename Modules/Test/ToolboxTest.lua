
local AddOnName, AddOn, Util, C
--- @type Models.Dao
local Dao

describe("Toolbox", function()
	setup(function()
		AddOnName, AddOn = loadfile("Test/TestSetup.lua")(true, 'Modules_Toolbox')
		Util, C = AddOn:GetLibrary('Util'), AddOn.Constants
		Dao = AddOn.ImportPackage('Models').Dao
		AddOnLoaded(AddOnName, true)
		SetTime()
	end)

	teardown(function()
		After()
	end)

	describe("utilities", function()
		--- @type Toolbox
		local tb = AddOn:Toolbox()

		it("predicates", function()
			local result =
				tb.ExtraDetailPredicate(
					Dao.EventDetail(nil, nil, nil, nil,  {a = 1, b = 2}),
					"a", "b"
				)
			assert(result)
			result = tb.ExtraDetailPredicate(
				Dao.EventDetail(nil, nil, nil, nil,  {a = 1, b = 2}),
				"a", "z"
			)
			assert(not result)

			result = tb.ActiveTotemSetPredicate(
				Dao.EventDetail(nil, nil, nil, nil,  {setId = tb:GetActiveTotemSetId()})
			)
			assert(result)

			result = tb.ActiveTotemSetPredicate(
				Dao.EventDetail({ id = tb:GetActiveTotemSetId()}, nil, nil, nil)
			)
			assert(result)

			result = tb.ActiveTotemSetPredicate(
				Dao.EventDetail(nil, nil, nil, nil)
			)
			assert(not result)
		end)
	end)
end)