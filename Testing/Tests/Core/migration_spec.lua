-- Migration system tests.
-- Tests RegisterMigration validation, RunOne flag stamping, RoundSizeFields,
-- and scope routing (global/profile/specProfile).

describe("Migration system", function()
    local modulePath = "EllesmereUI_Migration.lua"

    local original_EllesmereUI
    local original_EllesmereUIDB
    local original_GetTime

    local function loadMigration()
        local handle = assert(io.open(modulePath, "rb"))
        local source = assert(handle:read("*a"))
        handle:close()
        source = source:gsub("^\239\187\191", "")
        source = source:gsub("\r\n", "\n")

        -- We need fresh state each time, so we reset EllesmereUI
        _G.EllesmereUI = _G.EllesmereUI or {}

        local chunk, err = loadstring(source, "@" .. modulePath)
        assert.is_nil(err, "loadstring: " .. tostring(err))
        chunk("EllesmereUI")
    end

    before_each(function()
        original_EllesmereUI = _G.EllesmereUI
        original_EllesmereUIDB = _G.EllesmereUIDB
        original_GetTime = _G.GetTime

        _G.GetTime = function() return 100 end
        _G.EllesmereUI = {}
        _G.EllesmereUIDB = {
            profiles = {},
            spellAssignments = { specProfiles = {} },
        }
        _G.SLASH_EUIMIGRATIONS1 = nil
        _G.SLASH_EUIMIGRATIONS2 = nil
        _G.SlashCmdList = _G.SlashCmdList or {}

        loadMigration()
    end)

    after_each(function()
        _G.EllesmereUI = original_EllesmereUI
        _G.EllesmereUIDB = original_EllesmereUIDB
        _G.GetTime = original_GetTime
    end)

    -- RoundSizeFields -------------------------------------------------------
    describe("RoundSizeFields", function()
        it("rounds specified fields to nearest integer", function()
            local t = { width = 10.4, height = 20.6, name = "bar" }
            EllesmereUI.RoundSizeFields({ "width", "height" }, { t })
            assert.equals(10, t.width)
            assert.equals(21, t.height)
            assert.equals("bar", t.name)
        end)

        it("skips non-numeric fields", function()
            local t = { width = "auto", height = 15.5 }
            EllesmereUI.RoundSizeFields({ "width", "height" }, { t })
            assert.equals("auto", t.width)
            assert.equals(16, t.height)
        end)

        it("handles multiple tables", function()
            local a = { width = 5.3 }
            local b = { width = 7.7 }
            EllesmereUI.RoundSizeFields({ "width" }, { a, b })
            assert.equals(5, a.width)
            assert.equals(8, b.width)
        end)

        it("handles nil tables in the list", function()
            local a = { width = 5.3 }
            -- should not error
            EllesmereUI.RoundSizeFields({ "width" }, { a, "not_a_table" })
            assert.equals(5, a.width)
        end)

        it("handles missing keys gracefully", function()
            local t = { height = 10.5 }
            EllesmereUI.RoundSizeFields({ "width", "height" }, { t })
            assert.is_nil(t.width)
            assert.equals(11, t.height)
        end)
    end)

    -- RegisterMigration validation ------------------------------------------
    describe("RegisterMigration", function()
        it("rejects non-table spec", function()
            assert.has_error(function()
                EllesmereUI.RegisterMigration("not_a_table")
            end)
        end)

        it("rejects missing id", function()
            assert.has_error(function()
                EllesmereUI.RegisterMigration({ scope = "global", body = function() end })
            end)
        end)

        it("rejects empty string id", function()
            assert.has_error(function()
                EllesmereUI.RegisterMigration({ id = "", scope = "global", body = function() end })
            end)
        end)

        it("rejects missing body", function()
            assert.has_error(function()
                EllesmereUI.RegisterMigration({ id = "test", scope = "global" })
            end)
        end)

        it("rejects invalid scope", function()
            assert.has_error(function()
                EllesmereUI.RegisterMigration({ id = "test", scope = "invalid", body = function() end })
            end)
        end)

        it("rejects duplicate id", function()
            EllesmereUI.RegisterMigration({ id = "unique_1", scope = "global", body = function() end })
            assert.has_error(function()
                EllesmereUI.RegisterMigration({ id = "unique_1", scope = "global", body = function() end })
            end)
        end)

        it("accepts valid global migration", function()
            assert.has_no.errors(function()
                EllesmereUI.RegisterMigration({ id = "valid_global", scope = "global", body = function() end })
            end)
        end)

        it("accepts valid profile migration", function()
            assert.has_no.errors(function()
                EllesmereUI.RegisterMigration({ id = "valid_profile", scope = "profile", body = function() end })
            end)
        end)

        it("accepts valid specProfile migration", function()
            assert.has_no.errors(function()
                EllesmereUI.RegisterMigration({ id = "valid_spec", scope = "specProfile", body = function() end })
            end)
        end)
    end)

    -- RunRegisteredMigrations -----------------------------------------------
    describe("RunRegisteredMigrations", function()
        it("stamps global migration flag on success", function()
            local ran = false
            EllesmereUI.RegisterMigration({
                id = "g_test_1",
                scope = "global",
                body = function(ctx)
                    ran = true
                    assert.is_table(ctx.db)
                end,
            })
            EllesmereUI.RunRegisteredMigrations()
            assert.is_true(ran)
            assert.is_true(EllesmereUIDB._migrations["g_test_1"])
        end)

        it("does not re-run already-flagged global migration", function()
            local count = 0
            EllesmereUI.RegisterMigration({
                id = "g_test_norepeat",
                scope = "global",
                body = function() count = count + 1 end,
            })
            EllesmereUI.RunRegisteredMigrations()
            EllesmereUI.RunRegisteredMigrations()
            assert.equals(1, count)
        end)

        it("stamps profile migration flag per profile", function()
            _G.EllesmereUIDB.profiles = {
                Default = { addons = {} },
                Alt = { addons = {} },
            }
            local visited = {}
            EllesmereUI.RegisterMigration({
                id = "p_test_1",
                scope = "profile",
                body = function(ctx)
                    visited[ctx.profileName] = true
                end,
            })
            EllesmereUI.RunRegisteredMigrations()
            assert.is_true(visited["Default"])
            assert.is_true(visited["Alt"])
            assert.is_true(EllesmereUIDB.profiles.Default._migrations["p_test_1"])
            assert.is_true(EllesmereUIDB.profiles.Alt._migrations["p_test_1"])
        end)

        it("stamps specProfile migration flag per spec profile", function()
            _G.EllesmereUIDB.spellAssignments = {
                specProfiles = {
                    ["spec1"] = { bars = {} },
                    ["spec2"] = { bars = {} },
                },
            }
            local visited = {}
            EllesmereUI.RegisterMigration({
                id = "sp_test_1",
                scope = "specProfile",
                body = function(ctx)
                    visited[ctx.specKey] = true
                end,
            })
            EllesmereUI.RunRegisteredMigrations()
            assert.is_true(visited["spec1"])
            assert.is_true(visited["spec2"])
        end)

        it("catches errors in migration body without crashing", function()
            local secondRan = false
            EllesmereUI.RegisterMigration({
                id = "error_test",
                scope = "global",
                body = function() error("intentional") end,
            })
            EllesmereUI.RegisterMigration({
                id = "after_error",
                scope = "global",
                body = function() secondRan = true end,
            })
            EllesmereUI.RunRegisteredMigrations()
            -- First migration should NOT have its flag set (body errored)
            assert.is_nil(EllesmereUIDB._migrations["error_test"])
            -- Second migration should still run
            assert.is_true(secondRan)
            -- Error should be recorded
            local errors = EllesmereUI._migrationErrors
            assert.is_true(#errors > 0)
            assert.equals("error_test", errors[1].id)
        end)

        it("does nothing when EllesmereUIDB is nil", function()
            _G.EllesmereUIDB = nil
            -- Should not crash
            assert.has_no.errors(function()
                EllesmereUI.RunRegisteredMigrations()
            end)
        end)
    end)

    -- GetMigrationStatus ---------------------------------------------------
    describe("GetMigrationStatus", function()
        it("reports registered migrations and run state", function()
            EllesmereUI.RegisterMigration({
                id = "status_test",
                scope = "global",
                body = function() end,
            })
            EllesmereUI.RunRegisteredMigrations()

            local status = EllesmereUI.GetMigrationStatus()
            assert.is_true(#status.registered >= 1)
            -- Find our specific migration in the list
            local found
            for _, entry in ipairs(status.registered) do
                if entry.id == "status_test" then
                    found = entry
                    break
                end
            end
            assert.is_truthy(found)
            assert.equals("global", found.scope)
            assert.is_true(found.ranScopes[1].ran)
        end)
    end)
end)
