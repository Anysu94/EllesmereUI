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

    local function makeTexture(label)
        return {
            label = label,
            hidden = false,
            shown = false,
            size = nil,
            point = nil,
            hideCalls = 0,
            showCalls = 0,
            ClearAllPoints = function(self)
                self.point = nil
            end,
            SetColorTexture = function() end,
            SetSnapToPixelGrid = function() end,
            SetTexelSnappingBias = function() end,
            SetSize = function(self, width, height)
                self.size = { width, height }
            end,
            SetPoint = function(self, ...)
                self.point = { ... }
            end,
            Hide = function(self)
                self.hidden = true
                self.shown = false
                self.hideCalls = self.hideCalls + 1
            end,
            Show = function(self)
                self.hidden = false
                self.shown = true
                self.showCalls = self.showCalls + 1
            end,
        }
    end

    local function makeTextureFactory()
        local created = {}
        local owner = {
            CreateTexture = function(_, ...)
                local texture = makeTexture("created-" .. tostring(#created + 1))
                texture.createArgs = { ... }
                created[#created + 1] = texture
                return texture
            end,
        }
        return owner, created
    end

    local function makeStatusBar(width, height)
        local owner, created = makeTextureFactory()
        owner.GetWidth = function()
            return width
        end
        owner.GetHeight = function()
            return height
        end
        return owner, created
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

    it("parses threshold tick values and places only valid marks within the configured max", function()
        local ns = loadBuffBars(buildNamespace())
        local statusBar = makeStatusBar(100, 12)
        local tickParent, createdTextures = makeTextureFactory()
        local existingTexture = makeTexture("existing")
        local tickCache = { existingTexture }
        local onePx = (EllesmereUI and EllesmereUI.PP and EllesmereUI.PP.Scale and EllesmereUI.PP.Scale(1)) or 1
        local scaleValue = (EllesmereUI and EllesmereUI.PP and EllesmereUI.PP.Scale) or function(value)
            return value
        end

        ns.ApplyTBBTickMarks(statusBar, {
            stackThresholdEnabled = true,
            stackThresholdMaxEnabled = true,
            stackThresholdMax = 5,
            stackThresholdTicks = " 1, 0, bad, 5, 9 ",
        }, tickCache, false, tickParent)

        assert.are.equal(1, existingTexture.hideCalls)
        assert.are.equal(3, #tickCache)
        assert.are.equal(2, #createdTextures)

        assert.is_true(tickCache[1].shown)
        assert.same({ onePx, 12 }, tickCache[1].size)
        assert.same({ "TOPLEFT", statusBar, "TOPLEFT", scaleValue(20), 0 }, tickCache[1].point)

        assert.is_true(tickCache[2].shown)
        assert.same({ "TOPLEFT", statusBar, "TOPLEFT", scaleValue(100), 0 }, tickCache[2].point)

        assert.is_false(tickCache[3].shown)
        assert.is_nil(tickCache[3].point)
    end)

    it("hides cached ticks and exits early when threshold ticks do not produce usable values", function()
        local ns = loadBuffBars(buildNamespace())
        local statusBar, createdTextures = makeStatusBar(80, 10)
        local first = makeTexture("first")
        local second = makeTexture("second")
        local tickCache = { first, second }

        ns.ApplyTBBTickMarks(statusBar, {
            stackThresholdEnabled = true,
            stackThresholdMaxEnabled = true,
            stackThresholdMax = 5,
            stackThresholdTicks = "0, bad, -2",
        }, tickCache, true)

        assert.are.equal(1, first.hideCalls)
        assert.are.equal(1, second.hideCalls)
        assert.are.equal(0, #createdTextures)
        assert.is_false(first.shown)
        assert.is_false(second.shown)
    end)
end)