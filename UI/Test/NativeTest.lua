local AddOn, NativeUI, Class, Util

local function CustomWidget()
    local NativeWidget = AddOn.ImportPackage('UI.Native').Widget
    local Widget = Class('CustomWidget', NativeWidget)
    function Widget:initialize(parent, name, ...)
        NativeWidget.initialize(self, parent, name)
        self.args = {...}
    end

    function Widget:Create()
        return self
    end

    return Widget
end

describe("Native UI", function()
    setup(function()
        _, AddOn = loadfile("Test/TestSetup.lua")(true, 'UI_Native')
        NativeUI = AddOn.Require('UI.Native')
        Class = AddOn:GetLibrary('Class')
        Util = AddOn:GetLibrary('Util')
    end)

    teardown(function()
        After()
    end)

    describe("is", function()
        it("loaded and initialized", function()
            assert(NativeUI)
        end)
    end)

    describe("widget registration", function()
        it("fails with invalid arguments", function()
            assert.has.errors(function () NativeUI:RegisterWidget() end, "Widget type was not provided")
            assert.has.errors(function () NativeUI:RegisterWidget('awidget') end, "Widget class was not provided")
            assert.has.errors(function () NativeUI:RegisterWidget('awidget', true) end, "Widget class was not provided")
        end)
        it("succeeds with valid arguments", function()
            NativeUI:RegisterWidget('awidget', CustomWidget())
            NativeUI:UnregisterWidget('awidget')
        end)
    end)

    describe("widget creation", function()
        it("fails with invalid arguments", function()
            assert.has.errors(function () NativeUI:New('xyz') end, "(Native UI) No widget available for type 'xyz'")
            assert.has.errors(function () NativeUI:New() end, "Widget type was not provided")
        end)
        it("succeeds with valid arguments", function()
            NativeUI:RegisterWidget('awidget', CustomWidget())
            local w = NativeUI:New('awidget')
            assert(w.clazz.name == 'CustomWidget')
            assert(w.name == format('%s_UI_awidget_%d', AddOn.Constants.name, 1))
            assert(w.parent == _G.UIParent)
            -- assert(w.SetMultipleScripts and type(w.SetMultipleScripts) == 'function')
            w = NativeUI:NewNamed('awidget', {}, 'WidgetName')
            assert(w.clazz.name == 'CustomWidget')
            assert(w.name == 'WidgetName')
            assert.are.same(w.parent, { })
            -- assert(w.SetMultipleScripts and type(w.SetMultipleScripts) == 'function')
            NativeUI:UnregisterWidget('awidget')
        end)
    end)

    describe("frame container creation", function()
        --- @type UI.Native.FrameContainer
        local FrameContainer = AddOn.ImportPackage('UI.Native').FrameContainer

        it("delegates methods to frame", function()
            local container = FrameContainer(function() return CreateFrame('Frame') end)
            --
            ----local dict = rawget(container, '__index')
            --local metatable = getmetatable(container)
            --print(Util.Objects.ToString(metatable, 10))
            --
            --local orig = metatable.__index
            --print(Util.Objects.ToString(orig, 10))
            --
            --metatable.__index = function(self, k, ...)
            --    print(tostring(self) .. '.' .. tostring(k))
            --    print(dump(...))
            --
            --    if orig[k] then
            --        return orig[k]
            --    else
            --        return self.frame[k]
            --    end
            --end
            --
            --setmetatable(container, metatable)

            --container.__call = function(...)
            --    print(Util.Objects.ToString(...))
            --end

            --print(Util.Objects.ToString(container._))
            container._:GetID()
            container._:SetID(-99)
            print(container._:GetID())

            --FrameContainer.__index = function(...) print(Util.Objects.ToString({...})) end

            --print(Util.Objects.ToString(container.clazz.__index, 10))
            container:GetFrame()
            --container:GetFrameName()
            --container:SetID(-99)
            --print(container:GetID())
            --print(container:GetPoint())
        end)
    end)
end)