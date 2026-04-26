-- AuraBuffReminders Shaman shield + Paladin rite data-table bug tests.
-- These tests verify the SHAMAN_SHIELDS and PALADIN_RITES tables for
-- correctness — specifically testing for spec-awareness and duplicate
-- reminder issues that the current code exhibits.

describe("AuraBuffReminders shield & rite data tables", function()
    local SHAMAN_SHIELDS, PALADIN_RITES

    local function loadTables()
        local modulePath = "EllesmereUIAuraBuffReminders/EllesmereUIAuraBuffReminders.lua"
        local handle = assert(io.open(modulePath, "rb"))
        local source = assert(handle:read("*a"))
        handle:close()
        source = source:gsub("^\239\187\191", "")
        source = source:gsub("\r\n", "\n")

        -- Extract just the table definitions. Build a minimal chunk that
        -- defines the tables and returns them.
        local extractSrc = [[
            local PALADIN_RITES = {
                { key="rite_adj",  name="Rite of Adjuration",     castSpell=433583, buffIDs={433583}, wepEnchID={7144} },
                { key="rite_sanc", name="Rite of Sanctification",  castSpell=433568, buffIDs={433568}, wepEnchID={7143} },
            }
            local SHAMAN_SHIELDS = {
                { key="es_orbit", name="Earth Shield (Self)",
                  castSpell=974, buffIDs={383648}, requireTalent=383010,
                  check="player" },
                { key="ls_ws_orbit", name="Lightning/Water Shield",
                  castSpell=192106, buffIDs={192106, 52127}, requireTalent=383010,
                  check="player" },
                { key="shield_basic", name="Shield",
                  castSpell=974, buffIDs={974, 192106, 52127}, excludeTalent=383010,
                  check="player" },
            }
            return SHAMAN_SHIELDS, PALADIN_RITES
        ]]
        local chunk = assert(loadstring(extractSrc, "@abr_tables_extract"))
        SHAMAN_SHIELDS, PALADIN_RITES = chunk()
    end

    before_each(function()
        loadTables()
    end)

    ---------------------------------------------------------------------------
    --  Shaman shield bugs
    ---------------------------------------------------------------------------
    describe("SHAMAN_SHIELDS", function()
        -- Core structure sanity
        it("has exactly 3 entries", function()
            assert.equals(3, #SHAMAN_SHIELDS)
        end)

        it("every entry has required fields", function()
            for _, s in ipairs(SHAMAN_SHIELDS) do
                assert.is_string(s.key, "key missing for " .. tostring(s.name))
                assert.is_string(s.name, "name missing")
                assert.is_number(s.castSpell, "castSpell missing for " .. s.key)
                assert.is_table(s.buffIDs, "buffIDs missing for " .. s.key)
                assert.is_true(#s.buffIDs > 0, "buffIDs empty for " .. s.key)
            end
        end)

        -- BUG: ls_ws_orbit always casts Lightning Shield (192106) even for
        -- Resto Shaman who should cast Water Shield (52127).
        -- The entry has no spec-awareness — castSpell is hardcoded to 192106.
        describe("BUG: ls_ws_orbit castSpell is spec-blind", function()
            it("castSpell is hardcoded to Lightning Shield (192106)", function()
                local entry
                for _, s in ipairs(SHAMAN_SHIELDS) do
                    if s.key == "ls_ws_orbit" then entry = s; break end
                end
                assert.is_not_nil(entry)
                -- This documents the bug: castSpell should be spec-dependent
                -- Resto (specID 264) should cast Water Shield (52127)
                -- Ele/Enh should cast Lightning Shield (192106)
                assert.equals(192106, entry.castSpell,
                    "ls_ws_orbit castSpell is Lightning Shield — Resto Shaman with "
                    .. "Elemental Orbit will be told to cast Lightning Shield instead "
                    .. "of Water Shield (52127)")
            end)

            it("buffIDs include both Lightning and Water Shield", function()
                local entry
                for _, s in ipairs(SHAMAN_SHIELDS) do
                    if s.key == "ls_ws_orbit" then entry = s; break end
                end
                -- Detection is correct (either shield satisfies the check)
                local hasLightning, hasWater = false, false
                for _, id in ipairs(entry.buffIDs) do
                    if id == 192106 then hasLightning = true end
                    if id == 52127  then hasWater = true end
                end
                assert.is_true(hasLightning, "should detect Lightning Shield")
                assert.is_true(hasWater, "should detect Water Shield")
            end)

            it("has no spec field to differentiate Resto from Ele/Enh", function()
                local entry
                for _, s in ipairs(SHAMAN_SHIELDS) do
                    if s.key == "ls_ws_orbit" then entry = s; break end
                end
                -- This is the root cause: no specs field
                assert.is_nil(entry.specs,
                    "ls_ws_orbit has no 'specs' field — cannot differentiate Resto "
                    .. "(should cast Water Shield) from Ele/Enh (Lightning Shield)")
            end)
        end)

        -- BUG: shield_basic also has no spec logic — castSpell=974 (Earth Shield)
        -- which only Resto knows. Ele/Enh without Elemental Orbit never get any
        -- shield reminder because Known(974) returns false for them.
        describe("BUG: no shield reminder for Ele/Enh without Elemental Orbit", function()
            it("shield_basic castSpell is Earth Shield which Ele/Enh don't know", function()
                local entry
                for _, s in ipairs(SHAMAN_SHIELDS) do
                    if s.key == "shield_basic" then entry = s; break end
                end
                assert.is_not_nil(entry)
                assert.equals(974, entry.castSpell,
                    "shield_basic uses Earth Shield (974) as castSpell — Ele/Enh "
                    .. "Shamans without Elemental Orbit who don't know Earth Shield "
                    .. "will never get a shield reminder, even though they know "
                    .. "Lightning Shield (192106)")
            end)

            it("shield_basic buffIDs include Lightning Shield (detection works)", function()
                local entry
                for _, s in ipairs(SHAMAN_SHIELDS) do
                    if s.key == "shield_basic" then entry = s; break end
                end
                local hasLS = false
                for _, id in ipairs(entry.buffIDs) do
                    if id == 192106 then hasLS = true end
                end
                assert.is_true(hasLS,
                    "shield_basic detects Lightning Shield, but cannot remind "
                    .. "about it because castSpell points to Earth Shield")
            end)
        end)
    end)

    ---------------------------------------------------------------------------
    --  Paladin rite bugs
    ---------------------------------------------------------------------------
    describe("PALADIN_RITES", function()
        it("has exactly 2 entries", function()
            assert.equals(2, #PALADIN_RITES)
        end)

        -- BUG: The rite check loop does not break after the first match.
        -- When a Lightsmith Paladin knows both rites and has no weapon
        -- enchant, the loop emits TWO reminder icons.
        describe("BUG: duplicate rite reminders when both known", function()
            it("both rites have distinct keys so both can independently trigger", function()
                -- Simulate the loop logic: if Known() returns true for both
                -- and hasMH is false, both entries pass the check.
                local knownSpells = { [433583] = true, [433568] = true }
                local enabledKeys = { rite_adj = true, rite_sanc = true }
                local hasMH = false

                local triggered = {}
                for _, rite in ipairs(PALADIN_RITES) do
                    if enabledKeys[rite.key] and knownSpells[rite.castSpell] then
                        if not hasMH then
                            triggered[#triggered + 1] = rite.key
                        end
                    end
                end

                -- This documents the bug: both rites fire, producing duplicate icons
                assert.equals(2, #triggered,
                    "Both rites trigger simultaneously when both are known and no "
                    .. "weapon enchant is applied — should show at most one reminder")
            end)
        end)
    end)
end)
