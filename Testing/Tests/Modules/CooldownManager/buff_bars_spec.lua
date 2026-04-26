describe("Cooldown Manager tracked buff bar helpers", function()
    local modulePath = "EllesmereUICooldownManager/EllesmereUICdmBuffBars.lua"
    local original_GetTime
    local original_C_UnitAuras
    local original_C_Spell
    local original_EllesmereUIDB
    local original_issecretvalue
    local original_RAID_CLASS_COLORS
    local original_UnitClass

    local function loadBuffBars(ns)
        local chunk, err = loadfile(modulePath)
        assert.is_nil(err)
        chunk("EllesmereUICooldownManager", ns)
        return ns
    end

    local function buildNamespace()
        return {
            ECME = {},
            BUFF_BAR_PRESETS = {
                { key = "preset-a", spellID = 100, duration = 12 },
            },
            GetActiveSpecKey = function()
                return "spec"
            end,
        }
    end

    before_each(function()
        original_GetTime = _G.GetTime
        original_C_UnitAuras = _G.C_UnitAuras
        original_C_Spell = _G.C_Spell
        original_EllesmereUIDB = _G.EllesmereUIDB
        original_issecretvalue = _G.issecretvalue
        original_RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
        original_UnitClass = _G.UnitClass

        _G.GetTime = function()
            return 100
        end

        _G.C_UnitAuras = {
            GetPlayerAuraBySpellID = function()
                return nil
            end,
            GetAuraDataBySpellName = function()
                return nil
            end,
            GetAuraDataByAuraInstanceID = function()
                return nil
            end,
        }

        _G.C_Spell = {
            GetSpellName = function(spellID)
                return "Spell " .. tostring(spellID)
            end,
        }

        _G.EllesmereUIDB = nil
        _G.issecretvalue = function()
            return false
        end
        _G.RAID_CLASS_COLORS = {
            MAGE = { r = 0.11, g = 0.22, b = 0.33 },
        }
        _G.UnitClass = function()
            return "Mage", "MAGE"
        end
        _G.UnitExists = function(unit)
            return unit == "target"
        end
    end)

    after_each(function()
        _G.GetTime = original_GetTime
        _G.C_UnitAuras = original_C_UnitAuras
        _G.C_Spell = original_C_Spell
        _G.EllesmereUIDB = original_EllesmereUIDB
        _G.issecretvalue = original_issecretvalue
        _G.RAID_CLASS_COLORS = original_RAID_CLASS_COLORS
        _G.UnitClass = original_UnitClass
    end)

    it("detects the pandemic window from player auras", function()
        _G.C_UnitAuras.GetPlayerAuraBySpellID = function(spellID)
            if spellID == 10 then
                return {
                    duration = 20,
                    expirationTime = 105,
                }
            end
        end

        local ns = loadBuffBars(buildNamespace())

        assert.is_true(ns.IsInPandemicWindow(10))
        assert.is_false(ns.IsInPandemicWindow(11))
        assert.is_false(ns.IsInPandemicWindow(0))
    end)

    it("falls back to target debuffs when no player aura is active", function()
        _G.C_UnitAuras.GetAuraDataBySpellName = function(unit, name, filter)
            assert.are.equal("target", unit)
            assert.are.equal("Spell 20", name)
            assert.are.equal("HARMFUL|PLAYER", filter)
            return {
                duration = 12,
                expirationTime = 103,
            }
        end

        local ns = loadBuffBars(buildNamespace())

        assert.is_true(ns.IsInPandemicWindow(20))
    end)

    it("checks pandemic state from a Blizzard child aura instance", function()
        _G.C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, auraInstanceID)
            assert.are.equal("party1", unit)
            assert.are.equal(9001, auraInstanceID)
            return {
                duration = 30,
                expirationTime = 108,
            }
        end

        local ns = loadBuffBars(buildNamespace())

        assert.is_true(ns.IsInPandemicFromChild({
            auraInstanceID = 9001,
            auraDataUnit = "party1",
        }))
        assert.is_false(ns.IsInPandemicFromChild(nil))
    end)

    it("initializes tracked buff bar and position storage lazily per spec", function()
        local ns = loadBuffBars(buildNamespace())
        _G.EllesmereUIDB = {}

        local trackedBuffBars = ns.GetTrackedBuffBars()
        local positions = ns.GetTBBPositions()

        assert.are.equal(1, trackedBuffBars.selectedBar)
        assert.same({}, trackedBuffBars.bars)
        assert.same({}, positions)
        assert.are.same(trackedBuffBars, EllesmereUIDB.spellAssignments.specProfiles.spec.trackedBuffBars)
        assert.are.same(positions, EllesmereUIDB.spellAssignments.specProfiles.spec.tbbPositions)
    end)

    it("adds a tracked buff bar by copying generic settings and resetting spell-specific fields", function()
        local ns = loadBuffBars(buildNamespace())
        local rebuildCalls = 0
        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    spec = {
                        trackedBuffBars = {
                            selectedBar = 1,
                            bars = {
                                {
                                    spellID = 55,
                                    name = "Seed",
                                    width = 320,
                                    height = 28,
                                    iconDisplay = "left",
                                    stackThresholdEnabled = true,
                                    stackThreshold = 7,
                                    stackThresholdTicks = "1,2,3",
                                },
                            },
                        },
                    },
                },
            },
        }

        ns.BuildTrackedBuffBars = function()
            rebuildCalls = rebuildCalls + 1
        end

        local index = ns.AddTrackedBuffBar()
        local bars = EllesmereUIDB.spellAssignments.specProfiles.spec.trackedBuffBars.bars
        local added = bars[2]

        assert.are.equal(2, index)
        assert.are.equal(1, rebuildCalls)
        assert.are.equal(2, EllesmereUIDB.spellAssignments.specProfiles.spec.trackedBuffBars.selectedBar)
        assert.are.equal(0, added.spellID)
        assert.are.equal("Bar 2", added.name)
        assert.are.equal(320, added.width)
        assert.are.equal("left", added.iconDisplay)
        assert.are.equal(false, added.stackThresholdEnabled)
        assert.are.equal(5, added.stackThreshold)
        assert.are.equal("", added.stackThresholdTicks)
        assert.is_nil(added.popularKey)
        assert.is_nil(added.spellIDs)
    end)

    it("removes tracked buff bars safely and clamps the selected index", function()
        local ns = loadBuffBars(buildNamespace())
        local rebuildCalls = 0
        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    spec = {
                        trackedBuffBars = {
                            selectedBar = 3,
                            bars = {
                                { name = "Bar 1" },
                                { name = "Bar 2" },
                                { name = "Bar 3" },
                            },
                        },
                    },
                },
            },
        }

        ns.BuildTrackedBuffBars = function()
            rebuildCalls = rebuildCalls + 1
        end

        ns.RemoveTrackedBuffBar(2)

        local trackedBuffBars = EllesmereUIDB.spellAssignments.specProfiles.spec.trackedBuffBars
        assert.are.equal(2, #trackedBuffBars.bars)
        assert.are.equal("Bar 3", trackedBuffBars.bars[2].name)
        assert.are.equal(2, trackedBuffBars.selectedBar)
        assert.are.equal(1, rebuildCalls)

        ns.RemoveTrackedBuffBar(99)
        assert.are.equal(1, rebuildCalls)
    end)
end)