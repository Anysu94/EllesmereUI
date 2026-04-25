-- Sync helper coverage for profile and module synchronization state.

describe("EllesmereUI sync helpers", function()
    before_each(function()
        _G.EllesmereUIDB = nil
        EllesmereUI.Lite = nil
    end)

    it("reports unsynced modules when the database is missing", function()
        assert.is_false(EllesmereUI.IsModuleSynced("EllesmereUIBlizzardSkin"))
    end)

    it("reports synced modules from the saved database", function()
        _G.EllesmereUIDB = {
            syncedModules = {
                EllesmereUIBlizzardSkin = true,
                EllesmereUIChat = false,
            },
        }

        assert.is_true(EllesmereUI.IsModuleSynced("EllesmereUIBlizzardSkin"))
        assert.is_false(EllesmereUI.IsModuleSynced("EllesmereUIChat"))
        assert.is_false(EllesmereUI.IsModuleSynced("MissingModule"))
    end)

    it("stamps reskin modules as synced for a fresh single-profile setup", function()
        _G.EllesmereUIDB = {
            profiles = { Default = {} },
        }

        EllesmereUI._initSyncDefaults()

        assert.is_true(_G.EllesmereUIDB._syncDefaultsStamped)
        assert.is_table(_G.EllesmereUIDB.syncedModules)
        assert.is_true(_G.EllesmereUIDB.syncedModules.EllesmereUIBlizzardSkin)
        assert.is_true(_G.EllesmereUIDB.syncedModules.EllesmereUIChat)
        assert.is_nil(_G.EllesmereUIDB.syncedModules.EllesmereUIActionBars)
    end)

    it("does not auto-stamp sync defaults for multi-profile setups", function()
        _G.EllesmereUIDB = {
            profiles = {
                Default = {},
                Alt = {},
            },
        }

        EllesmereUI._initSyncDefaults()

        assert.is_true(_G.EllesmereUIDB._syncDefaultsStamped)
        assert.is_nil(_G.EllesmereUIDB.syncedModules)
    end)

    it("sets sync state explicitly even without profile data", function()
        _G.EllesmereUIDB = {}

        EllesmereUI.SetModuleSynced("EllesmereUIChat", true)
        assert.is_true(_G.EllesmereUIDB.syncedModules.EllesmereUIChat)

        EllesmereUI.SetModuleSynced("EllesmereUIChat", false)
        assert.is_false(_G.EllesmereUIDB.syncedModules.EllesmereUIChat)
    end)

    it("copies synced addon data to other profiles when enabled", function()
        local function deep_copy(value)
            if type(value) ~= "table" then
                return value
            end

            local copy = {}
            for key, nested in pairs(value) do
                copy[key] = deep_copy(nested)
            end
            return copy
        end

        EllesmereUI.Lite = {
            DeepCopy = deep_copy,
        }

        _G.EllesmereUIDB = {
            activeProfile = "Default",
            profiles = {
                Default = {
                    addons = {
                        EllesmereUIChat = {
                            alpha = 0.5,
                            nested = { enabled = true },
                        },
                    },
                },
                Alt = { addons = {} },
                Third = { addons = {} },
            },
        }

        EllesmereUI.SetModuleSynced("EllesmereUIChat", true)

        assert.is_true(_G.EllesmereUIDB.syncedModules.EllesmereUIChat)
        assert.are.same(_G.EllesmereUIDB.profiles.Default.addons.EllesmereUIChat, _G.EllesmereUIDB.profiles.Alt.addons.EllesmereUIChat)
        assert.are.same(_G.EllesmereUIDB.profiles.Default.addons.EllesmereUIChat, _G.EllesmereUIDB.profiles.Third.addons.EllesmereUIChat)

        _G.EllesmereUIDB.profiles.Alt.addons.EllesmereUIChat.nested.enabled = false
        assert.is_true(_G.EllesmereUIDB.profiles.Default.addons.EllesmereUIChat.nested.enabled)
    end)
end)