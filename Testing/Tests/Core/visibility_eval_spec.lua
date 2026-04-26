-- EvalVisibility state machine tests.
-- Tests the core mode evaluation (always/never/mouseover/combat/group/solo).

describe("EvalVisibility state machine", function()
    local modulePath = "EllesmereUI_Visibility.lua"

    local original_EllesmereUI
    local original_IsInGroup
    local original_IsInRaid
    local original_C_Timer
    local original_CreateFrame
    local original_GetInstanceInfo
    local original_UnitExists
    local original_UnitCanAttack
    local original_IsMounted
    local original_C_Garrison
    local original_C_Housing
    local original_C_UnitAuras

    local EvalVisibility
    local _setInCombat  -- function to simulate combat state

    local function replaceExact(source, oldText, newText, label)
        local startIndex = source:find(oldText, 1, true)
        assert.is_truthy(startIndex, "expected exact replacement for " .. label)
        local endIndex = startIndex + #oldText - 1
        return source:sub(1, startIndex - 1) .. newText .. source:sub(endIndex + 1)
    end

    local function loadVisibility()
        local handle = assert(io.open(modulePath, "rb"))
        local source = assert(handle:read("*a"))
        handle:close()
        source = source:gsub("^\239\187\191", "")
        source = source:gsub("\r\n", "\n")

        -- Export _inCombat setter
        source = replaceExact(
            source,
            "EUI.IsInCombat = IsInCombat",
            "EUI.IsInCombat = IsInCombat\nEUI._setInCombat = function(v) _inCombat = v end",
            "_inCombat setter export"
        )

        local chunk, err = loadstring(source, "@" .. modulePath)
        assert.is_nil(err, "loadstring: " .. tostring(err))
        chunk("EllesmereUI")

        EvalVisibility = _G.EllesmereUI.EvalVisibility
        _setInCombat = _G.EllesmereUI._setInCombat
    end

    before_each(function()
        original_EllesmereUI = _G.EllesmereUI
        original_IsInGroup = _G.IsInGroup
        original_IsInRaid = _G.IsInRaid
        original_C_Timer = _G.C_Timer
        original_CreateFrame = _G.CreateFrame
        original_GetInstanceInfo = _G.GetInstanceInfo
        original_UnitExists = _G.UnitExists
        original_UnitCanAttack = _G.UnitCanAttack
        original_IsMounted = _G.IsMounted
        original_C_Garrison = _G.C_Garrison
        original_C_Housing = _G.C_Housing
        original_C_UnitAuras = _G.C_UnitAuras

        -- Stubs
        _G.IsInGroup = function() return false end
        _G.IsInRaid = function() return false end
        _G.C_Timer = { After = function() end }
        _G.GetInstanceInfo = function() return nil, "none", 0 end
        _G.UnitExists = function() return false end
        _G.UnitCanAttack = function() return false end
        _G.IsMounted = function() return false end
        _G.C_Garrison = nil
        _G.C_Housing = nil
        _G.C_UnitAuras = nil

        _G.EllesmereUI = _G.EllesmereUI or {}

        loadVisibility()
    end)

    after_each(function()
        _G.EllesmereUI = original_EllesmereUI
        _G.IsInGroup = original_IsInGroup
        _G.IsInRaid = original_IsInRaid
        _G.C_Timer = original_C_Timer
        _G.CreateFrame = original_CreateFrame
        _G.GetInstanceInfo = original_GetInstanceInfo
        _G.UnitExists = original_UnitExists
        _G.UnitCanAttack = original_UnitCanAttack
        _G.IsMounted = original_IsMounted
        _G.C_Garrison = original_C_Garrison
        _G.C_Housing = original_C_Housing
        _G.C_UnitAuras = original_C_UnitAuras
    end)

    it("returns true for nil config", function()
        assert.is_true(EvalVisibility(nil))
    end)

    it("returns true for 'always' mode", function()
        assert.is_true(EvalVisibility({ visibility = "always" }))
    end)

    it("returns false for 'never' mode", function()
        assert.is_false(EvalVisibility({ visibility = "never" }))
    end)

    it("returns 'mouseover' for mouseover mode", function()
        assert.equals("mouseover", EvalVisibility({ visibility = "mouseover" }))
    end)

    it("returns true for 'in_combat' when in combat", function()
        _setInCombat(true)
        assert.is_true(EvalVisibility({ visibility = "in_combat" }))
    end)

    it("returns false for 'in_combat' when out of combat", function()
        _setInCombat(false)
        assert.is_false(EvalVisibility({ visibility = "in_combat" }))
    end)

    it("returns true for 'out_of_combat' when out of combat", function()
        _setInCombat(false)
        assert.is_true(EvalVisibility({ visibility = "out_of_combat" }))
    end)

    it("returns false for 'out_of_combat' when in combat", function()
        _setInCombat(true)
        assert.is_false(EvalVisibility({ visibility = "out_of_combat" }))
    end)

    it("returns true for 'in_raid' when in a raid", function()
        _G.IsInRaid = function() return true end
        assert.is_true(EvalVisibility({ visibility = "in_raid" }))
    end)

    it("returns false for 'in_raid' when not in a raid", function()
        _G.IsInRaid = function() return false end
        assert.is_false(EvalVisibility({ visibility = "in_raid" }))
    end)

    it("returns true for 'in_party' when in group but not raid", function()
        _G.IsInGroup = function() return true end
        _G.IsInRaid = function() return false end
        assert.is_true(EvalVisibility({ visibility = "in_party" }))
    end)

    it("returns false for 'in_party' when in raid", function()
        _G.IsInGroup = function() return true end
        _G.IsInRaid = function() return true end
        assert.is_false(EvalVisibility({ visibility = "in_party" }))
    end)

    it("returns false for 'in_party' when solo", function()
        _G.IsInGroup = function() return false end
        assert.is_false(EvalVisibility({ visibility = "in_party" }))
    end)

    it("returns true for 'solo' when not in group", function()
        _G.IsInGroup = function() return false end
        assert.is_true(EvalVisibility({ visibility = "solo" }))
    end)

    it("returns false for 'solo' when in group", function()
        _G.IsInGroup = function() return true end
        assert.is_false(EvalVisibility({ visibility = "solo" }))
    end)

    it("defaults to true for unknown mode", function()
        assert.is_true(EvalVisibility({ visibility = "unknown_mode" }))
    end)

    it("defaults to 'always' when visibility key is nil", function()
        assert.is_true(EvalVisibility({}))
    end)
end)
