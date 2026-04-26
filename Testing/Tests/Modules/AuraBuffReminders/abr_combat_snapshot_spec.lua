-- AuraBuffReminders PlayerHasAuraByID combat snapshot staleness bug tests.
-- Tests that the pre-combat aura cache can produce stale results when
-- buffs expire during combat.

describe("AuraBuffReminders combat aura snapshot", function()

    -- PlayerHasAuraByID (EllesmereUIAuraBuffReminders.lua ~line 292-320) uses
    -- a pre-combat snapshot (_preCombatAuraCache) as a fallback when the API
    -- call returns nil (buff not present) while in combat. This means:
    --
    --   1. Player has Battle Shout before pull -> _preCombatAuraCache[6673] = true
    --   2. Battle Shout provider dies mid-combat -> aura expires
    --   3. API call returns nil (buff gone)
    --   4. But _preCombatAuraCache[6673] is still true
    --   5. PlayerHasAuraByID returns true -> NO reminder shown
    --
    -- This is a false negative: the buff is gone but the reminder doesn't fire.

    -- We simulate the function logic inline to document the bug.

    local function simulatePlayerHasAuraByID(spellIDs, inCombat, apiResults, preCombatCache, nonSecretIDs)
        if not spellIDs or not spellIDs[1] then return true end
        for j = 1, #spellIDs do
            local id = spellIDs[j]
            if nonSecretIDs[id] then
                local result = apiResults[id]
                if result ~= nil then return true end
                if inCombat and preCombatCache[id] then return true end
            end
        end
        return false
    end

    describe("BUG: stale snapshot reports expired buffs as present", function()
        it("returns true for a buff that was present pre-combat but expired during combat", function()
            local BATTLE_SHOUT = 6673
            local preCombatCache = { [BATTLE_SHOUT] = true }
            local apiResults = { [BATTLE_SHOUT] = nil }  -- buff expired
            local nonSecretIDs = { [BATTLE_SHOUT] = true }

            local result = simulatePlayerHasAuraByID(
                { BATTLE_SHOUT },
                true,        -- in combat
                apiResults,
                preCombatCache,
                nonSecretIDs
            )

            -- This documents the bug: the function returns true even though
            -- the buff is not active. The reminder never fires mid-combat.
            assert.is_true(result,
                "PlayerHasAuraByID returns true for expired buff because "
                .. "pre-combat snapshot is stale. Raid buff reminders will "
                .. "NOT appear mid-combat when a buff provider dies.")
        end)

        it("correctly returns false out of combat when buff is missing", function()
            local BATTLE_SHOUT = 6673
            local preCombatCache = { [BATTLE_SHOUT] = true }
            local apiResults = { [BATTLE_SHOUT] = nil }
            local nonSecretIDs = { [BATTLE_SHOUT] = true }

            local result = simulatePlayerHasAuraByID(
                { BATTLE_SHOUT },
                false,       -- NOT in combat
                apiResults,
                preCombatCache,
                nonSecretIDs
            )

            -- Out of combat, the snapshot is not consulted
            assert.is_false(result)
        end)

        it("returns false when buff was never in snapshot and API says gone", function()
            local ARCANE_INTELLECT = 1459
            local preCombatCache = {}  -- never had it
            local apiResults = { [ARCANE_INTELLECT] = nil }
            local nonSecretIDs = { [ARCANE_INTELLECT] = true }

            local result = simulatePlayerHasAuraByID(
                { ARCANE_INTELLECT },
                true,
                apiResults,
                preCombatCache,
                nonSecretIDs
            )

            assert.is_false(result,
                "If the buff was never in the snapshot, it correctly returns false")
        end)
    end)

    describe("correct behavior baseline", function()
        it("returns true when API confirms buff is active", function()
            local BATTLE_SHOUT = 6673
            local preCombatCache = {}
            local apiResults = { [BATTLE_SHOUT] = {} }  -- non-nil = present
            local nonSecretIDs = { [BATTLE_SHOUT] = true }

            local result = simulatePlayerHasAuraByID(
                { BATTLE_SHOUT },
                true,
                apiResults,
                preCombatCache,
                nonSecretIDs
            )

            assert.is_true(result)
        end)

        it("returns true when empty spellIDs array is passed", function()
            local result = simulatePlayerHasAuraByID({}, false, {}, {}, {})
            assert.is_true(result, "empty array should return true (no buff required)")
        end)

        it("returns true when nil is passed", function()
            local result = simulatePlayerHasAuraByID(nil, false, {}, {}, {})
            assert.is_true(result, "nil should return true (no buff required)")
        end)
    end)
end)
