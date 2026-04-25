-- Visibility helper coverage for the pure decision helpers.

describe("EllesmereUI visibility helpers", function()
    local original_GetInstanceInfo
    local original_UnitExists
    local original_UnitCanAttack
    local original_IsMounted
    local original_C_Garrison
    local original_C_Housing
    local original_C_UnitAuras

    before_each(function()
        original_GetInstanceInfo = _G.GetInstanceInfo
        original_UnitExists = _G.UnitExists
        original_UnitCanAttack = _G.UnitCanAttack
        original_IsMounted = _G.IsMounted
        original_C_Garrison = _G.C_Garrison
        original_C_Housing = _G.C_Housing
        original_C_UnitAuras = _G.C_UnitAuras

        _G.GetInstanceInfo = function()
            return nil, "none", 0
        end
        _G.UnitExists = function()
            return false
        end
        _G.UnitCanAttack = function()
            return false
        end
        _G.IsMounted = function()
            return false
        end
        _G.C_Garrison = nil
        _G.C_Housing = nil
        _G.C_UnitAuras = nil
    end)

    after_each(function()
        _G.GetInstanceInfo = original_GetInstanceInfo
        _G.UnitExists = original_UnitExists
        _G.UnitCanAttack = original_UnitCanAttack
        _G.IsMounted = original_IsMounted
        _G.C_Garrison = original_C_Garrison
        _G.C_Housing = original_C_Housing
        _G.C_UnitAuras = original_C_UnitAuras
    end)

    it("returns false when no non-macro visibility options are provided", function()
        assert.is_false(EllesmereUI.CheckVisibilityOptionsNonMacro(nil))
    end)

    it("hides outside valid instances when only-instance visibility is enabled", function()
        assert.is_true(EllesmereUI.CheckVisibilityOptionsNonMacro({ visOnlyInstances = true }))

        _G.GetInstanceInfo = function()
            return nil, "party", 8
        end

        assert.is_false(EllesmereUI.CheckVisibilityOptionsNonMacro({ visOnlyInstances = true }))
    end)

    it("does not treat garrison maps as valid instances", function()
        _G.GetInstanceInfo = function()
            return nil, "party", 8
        end
        _G.C_Garrison = {
            IsOnGarrisonMap = function()
                return true
            end,
        }

        assert.is_true(EllesmereUI.CheckVisibilityOptionsNonMacro({ visOnlyInstances = true }))
    end)

    it("hides while inside housing when configured", function()
        _G.C_Housing = {
            IsInsideHouseOrPlot = function()
                return true
            end,
        }

        assert.is_true(EllesmereUI.CheckVisibilityOptionsNonMacro({ visHideHousing = true }))
    end)

    it("hides while mounted when configured", function()
        _G.IsMounted = function()
            return true
        end

        assert.is_true(EllesmereUI.CheckVisibilityOptionsNonMacro({ visHideMounted = true }))
    end)

    it("hides without a target when requested", function()
        assert.is_true(EllesmereUI.CheckVisibilityOptions({ visHideNoTarget = true }))

        _G.UnitExists = function(unit)
            return unit == "target"
        end

        assert.is_false(EllesmereUI.CheckVisibilityOptions({ visHideNoTarget = true }))
    end)

    it("hides without an enemy target when requested", function()
        assert.is_true(EllesmereUI.CheckVisibilityOptions({ visHideNoEnemy = true }))

        _G.UnitExists = function(unit)
            return unit == "target"
        end
        _G.UnitCanAttack = function(player, target)
            return player == "player" and target == "target"
        end

        assert.is_false(EllesmereUI.CheckVisibilityOptions({ visHideNoEnemy = true }))
    end)

    it("maps visibility mode strings to the expected show state", function()
        local state = { inCombat = true, inRaid = false, inParty = true }

        assert.is_false(EllesmereUI.CheckVisibilityMode("disabled", state))
        assert.is_false(EllesmereUI.CheckVisibilityMode("never", state))
        assert.is_true(EllesmereUI.CheckVisibilityMode("in_combat", state))
        assert.is_false(EllesmereUI.CheckVisibilityMode("out_of_combat", state))
        assert.is_false(EllesmereUI.CheckVisibilityMode("in_raid", state))
        assert.is_true(EllesmereUI.CheckVisibilityMode("in_party", state))
        assert.is_false(EllesmereUI.CheckVisibilityMode("solo", state))
        assert.is_true(EllesmereUI.CheckVisibilityMode("always", state))
        assert.is_true(EllesmereUI.CheckVisibilityMode("mouseover", state))
    end)
end)