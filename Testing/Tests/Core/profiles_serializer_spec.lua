-- Profiles Serializer round-trip and edge-case tests.
-- Tests Serializer.Serialize / Deserialize, DeepCopy, DeepMerge, ProfileChangesFont.

describe("Profiles serializer and utilities", function()
    local modulePath = "EllesmereUI_Profiles.lua"

    local original_EllesmereUI
    local original_EllesmereUIDB
    local original_StaticPopupDialogs
    local original_LibStub
    local original_UnitName
    local original_GetRealmName
    local original_GetSpecialization
    local original_C_AddOns
    local original_ReloadUI
    local original_SLASH_EUIPROFILES1
    local original_SlashCmdList

    local Serializer, DeepCopy, ProfileChangesFont

    local function loadProfiles()
        -- Minimal stubs for the module loading
        _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
        _G.LibStub = function() return nil end
        _G.ReloadUI = function() end
        _G.UnitName = function() return "TestPlayer" end
        _G.GetRealmName = function() return "TestRealm" end
        _G.GetSpecialization = function() return 1 end
        _G.C_AddOns = { IsAddOnLoaded = function() return false end }

        _G.EllesmereUI = _G.EllesmereUI or {}
        _G.EllesmereUI.Lite = _G.EllesmereUI.Lite or {}
        _G.EllesmereUI.Lite._dbRegistry = {}
        _G.EllesmereUI.Lite.DeepMergeDefaults = function() end
        _G.EllesmereUI.Lite.RegisterPreLogout = function() end
        _G.EllesmereUI.GetFontsDB = function()
            return { global = "Expressway", outlineMode = "shadow" }
        end
        _G.EllesmereUI.GetCustomColorsDB = function() return {} end
        _G.EllesmereUIDB = { profiles = {}, profileOrder = {}, specProfiles = {} }

        local handle = assert(io.open(modulePath, "rb"))
        local source = assert(handle:read("*a"))
        handle:close()
        source = source:gsub("^\239\187\191", "")
        source = source:gsub("\r\n", "\n")

        local chunk, err = loadstring(source, "@" .. modulePath)
        assert.is_nil(err, "loadstring: " .. tostring(err))
        chunk("EllesmereUI")

        Serializer = _G.EllesmereUI._Serializer
        DeepCopy = _G.EllesmereUI._DeepCopy
        ProfileChangesFont = _G.EllesmereUI.ProfileChangesFont
    end

    before_each(function()
        original_EllesmereUI = _G.EllesmereUI
        original_EllesmereUIDB = _G.EllesmereUIDB
        original_StaticPopupDialogs = _G.StaticPopupDialogs
        original_LibStub = _G.LibStub
        original_UnitName = _G.UnitName
        original_GetRealmName = _G.GetRealmName
        original_GetSpecialization = _G.GetSpecialization
        original_C_AddOns = _G.C_AddOns
        original_ReloadUI = _G.ReloadUI
        original_SlashCmdList = _G.SlashCmdList

        loadProfiles()
    end)

    after_each(function()
        _G.EllesmereUI = original_EllesmereUI
        _G.EllesmereUIDB = original_EllesmereUIDB
        _G.StaticPopupDialogs = original_StaticPopupDialogs
        _G.LibStub = original_LibStub
        _G.UnitName = original_UnitName
        _G.GetRealmName = original_GetRealmName
        _G.GetSpecialization = original_GetSpecialization
        _G.C_AddOns = original_C_AddOns
        _G.ReloadUI = original_ReloadUI
        _G.SlashCmdList = original_SlashCmdList
    end)

    -- Serializer -----------------------------------------------------------
    describe("Serializer", function()
        it("round-trips a simple table", function()
            local input = { name = "test", value = 42 }
            local encoded = Serializer.Serialize(input)
            local decoded = Serializer.Deserialize(encoded)
            assert.equals("test", decoded.name)
            assert.equals(42, decoded.value)
        end)

        it("round-trips booleans", function()
            local input = { enabled = true, disabled = false }
            local decoded = Serializer.Deserialize(Serializer.Serialize(input))
            assert.is_true(decoded.enabled)
            assert.is_false(decoded.disabled)
        end)

        it("round-trips nested tables", function()
            local input = { outer = { inner = { deep = 99 } } }
            local decoded = Serializer.Deserialize(Serializer.Serialize(input))
            assert.equals(99, decoded.outer.inner.deep)
        end)

        it("round-trips arrays", function()
            local input = { 10, 20, 30, "hello" }
            local decoded = Serializer.Deserialize(Serializer.Serialize(input))
            assert.equals(10, decoded[1])
            assert.equals(20, decoded[2])
            assert.equals(30, decoded[3])
            assert.equals("hello", decoded[4])
        end)

        it("round-trips mixed array and hash keys", function()
            local input = { "first", "second", name = "test" }
            local decoded = Serializer.Deserialize(Serializer.Serialize(input))
            assert.equals("first", decoded[1])
            assert.equals("second", decoded[2])
            assert.equals("test", decoded.name)
        end)

        it("round-trips strings with special characters", function()
            local input = { msg = "hello:world;test{}" }
            local decoded = Serializer.Deserialize(Serializer.Serialize(input))
            assert.equals("hello:world;test{}", decoded.msg)
        end)

        it("round-trips empty table", function()
            local input = {}
            local decoded = Serializer.Deserialize(Serializer.Serialize(input))
            assert.is_table(decoded)
            assert.is_nil(next(decoded))
        end)

        it("round-trips color tables", function()
            local input = { color = { r = 0.5, g = 0.8, b = 1.0 } }
            local decoded = Serializer.Deserialize(Serializer.Serialize(input))
            assert.is_near(0.5, decoded.color.r, 0.0001)
            assert.is_near(0.8, decoded.color.g, 0.0001)
            assert.is_near(1.0, decoded.color.b, 0.0001)
        end)

        it("returns nil for empty string", function()
            assert.is_nil(Serializer.Deserialize(""))
        end)

        it("returns nil for nil input", function()
            assert.is_nil(Serializer.Deserialize(nil))
        end)

        it("round-trips numeric keys > array length as hash", function()
            local input = { [1] = "a", [5] = "b" }
            local decoded = Serializer.Deserialize(Serializer.Serialize(input))
            assert.equals("a", decoded[1])
            assert.equals("b", decoded[5])
        end)

        it("round-trips negative numbers", function()
            local input = { x = -42.5 }
            local decoded = Serializer.Deserialize(Serializer.Serialize(input))
            assert.is_near(-42.5, decoded.x, 0.0001)
        end)
    end)

    -- DeepCopy --------------------------------------------------------------
    describe("DeepCopy", function()
        it("creates independent copy", function()
            local original = { a = { b = 1 } }
            local copy = DeepCopy(original)
            copy.a.b = 2
            assert.equals(1, original.a.b)
        end)

        it("returns non-table values unchanged", function()
            assert.equals(42, DeepCopy(42))
            assert.equals("hi", DeepCopy("hi"))
            assert.is_true(DeepCopy(true))
        end)

        it("handles cyclic references", function()
            local t = { x = 1 }
            t.self = t
            local copy = DeepCopy(t)
            assert.equals(1, copy.x)
            assert.equals(copy, copy.self)
            assert.are_not.equal(t, copy)
        end)

        it("skips userdata values", function()
            local ud = newproxy(true)
            local t = { val = ud, name = "test" }
            local copy = DeepCopy(t)
            assert.is_nil(copy.val)
            assert.equals("test", copy.name)
        end)

        it("skips function values", function()
            local t = { fn = function() end, name = "test" }
            local copy = DeepCopy(t)
            assert.is_nil(copy.fn)
            assert.equals("test", copy.name)
        end)
    end)

    -- ProfileChangesFont ---------------------------------------------------
    describe("ProfileChangesFont", function()
        it("returns false for nil profileData", function()
            assert.is_false(ProfileChangesFont(nil))
        end)

        it("returns false for missing fonts key", function()
            assert.is_false(ProfileChangesFont({ addons = {} }))
        end)

        it("returns false when fonts match current", function()
            assert.is_false(ProfileChangesFont({ fonts = { global = "Expressway", outlineMode = "shadow" } }))
        end)

        it("returns true when font family differs", function()
            assert.is_true(ProfileChangesFont({ fonts = { global = "Arial", outlineMode = "shadow" } }))
        end)

        it("returns true when outline mode differs", function()
            assert.is_true(ProfileChangesFont({ fonts = { global = "Expressway", outlineMode = "outline" } }))
        end)

        it("treats 'none' and 'shadow' as identical", function()
            -- Current is "shadow", incoming is "none" -> no change
            assert.is_false(ProfileChangesFont({ fonts = { global = "Expressway", outlineMode = "none" } }))
        end)

        it("uses defaults when keys are missing", function()
            -- Missing global defaults to "Expressway", missing outlineMode defaults to "shadow"
            assert.is_false(ProfileChangesFont({ fonts = {} }))
        end)
    end)
end)
