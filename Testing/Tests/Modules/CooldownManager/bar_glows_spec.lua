describe("Cooldown Manager bar glow helpers", function()
    local modulePath = "EllesmereUICooldownManager/EllesmereUICdmBarGlows.lua"
    local original_CreateFrame
    local original_EllesmereUIDB
    local original_UnitClass
    local original_RAID_CLASS_COLORS
    local original_wipe
    local original_EABButton1
    local original_ActionButton2

    local createdFrames
    local glowEvents

    local function makeFrame(options)
        options = options or {}

        local frame = {
            _parent = options.parent,
            _shown = options.shown ~= false,
            _frameLevel = options.frameLevel or 1,
            _shapeName = options.shapeName,
            cooldownID = options.cooldownID,
        }

        function frame:GetParent()
            return self._parent
        end

        function frame:SetParent(parent)
            self._parent = parent
        end

        function frame:SetAllPoints(target)
            self._allPointsTarget = target
        end

        function frame:SetFrameLevel(level)
            self._frameLevel = level
        end

        function frame:GetFrameLevel()
            return self._frameLevel
        end

        function frame:SetAlpha(alpha)
            self._alpha = alpha
        end

        function frame:Show()
            self._shown = true
        end

        function frame:Hide()
            self._shown = false
        end

        function frame:IsShown()
            return self._shown
        end

        return frame
    end

    local function loadBarGlows(ns)
        local chunk, err = loadfile(modulePath)
        assert.is_nil(err)
        chunk("EllesmereUICooldownManager", ns)
        return ns
    end

    local function buildNamespace()
        return {
            ECME = {},
            cdmBarIcons = {},
            GetActiveSpecKey = function()
                return "spec"
            end,
        }
    end

    local function spellIDs(entries)
        local result = {}
        for index = 1, #entries do
            result[index] = entries[index].spellID
        end
        return result
    end

    before_each(function()
        original_CreateFrame = _G.CreateFrame
        original_EllesmereUIDB = _G.EllesmereUIDB
        original_UnitClass = _G.UnitClass
        original_RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
        original_wipe = _G.wipe
        original_EABButton1 = _G.EABButton1
        original_ActionButton2 = _G.ActionButton2

        createdFrames = {}
        glowEvents = {}

        _G.CreateFrame = function(_, name, parent)
            local frame = makeFrame({ parent = parent, shown = false })
            frame._name = name
            createdFrames[#createdFrames + 1] = frame
            return frame
        end

        _G.UnitClass = function()
            return "Mage", "MAGE"
        end

        _G.RAID_CLASS_COLORS = {
            MAGE = { r = 0.1, g = 0.2, b = 0.3 },
        }

        _G.wipe = function(target)
            for key in pairs(target) do
                target[key] = nil
            end
        end

        _G.EllesmereUIDB = nil
        _G.EABButton1 = nil
        _G.ActionButton2 = nil
    end)

    after_each(function()
        _G.CreateFrame = original_CreateFrame
        _G.EllesmereUIDB = original_EllesmereUIDB
        _G.UnitClass = original_UnitClass
        _G.RAID_CLASS_COLORS = original_RAID_CLASS_COLORS
        _G.wipe = original_wipe
        _G.EABButton1 = original_EABButton1
        _G.ActionButton2 = original_ActionButton2
    end)

    it("initializes persisted bar glow storage lazily for the active spec", function()
        local ns = loadBarGlows(buildNamespace())
        _G.EllesmereUIDB = {}

        local barGlows = ns.GetBarGlows()

        assert.is_true(barGlows.enabled)
        assert.are.equal("cooldowns", barGlows.selectedBar)
        assert.same({}, barGlows.assignments)
        assert.are.same(barGlows, EllesmereUIDB.spellAssignments.specProfiles.spec.barGlows)
    end)

    it("uses the same default selected bar for fallback reads without saved variables", function()
        local ns = loadBarGlows(buildNamespace())

        local barGlows = ns.GetBarGlows()

        assert.are.equal(
            "cooldowns",
            barGlows.selectedBar,
            "fallback reads without a saved-variable table should use the same default selected bar as persisted bar glow data"
        )
    end)

    it("returns keyed action-bar and cdm assignments", function()
        local ns = loadBarGlows(buildNamespace())
        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    spec = {
                        barGlows = {
                            enabled = true,
                            selectedBar = "cooldowns",
                            assignments = {
                                ["1_2"] = { { spellID = 10 } },
                                ["cdm_44"] = { { spellID = 20 } },
                            },
                        },
                    },
                },
            },
        }

        assert.same({ { spellID = 10 } }, ns.GetButtonAssignments(1, 2))
        assert.same({ { spellID = 20 } }, ns.GetCDMButtonAssignments(44))
    end)

    it("reports whether any bar glow assignments exist", function()
        local ns = loadBarGlows(buildNamespace())
        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    spec = {
                        barGlows = {
                            enabled = true,
                            selectedBar = "cooldowns",
                            assignments = {
                                ["1_1"] = {},
                            },
                        },
                    },
                },
            },
        }

        assert.is_false(ns.HasBarGlowAssignments())

        EllesmereUIDB.spellAssignments.specProfiles.spec.barGlows.assignments["1_1"] = {
            { spellID = 10 },
        }

        assert.is_true(ns.HasBarGlowAssignments())
    end)

    it("collects deduplicated buff-bar spells and splits tracked from hidden ones", function()
        local ns = loadBarGlows(buildNamespace())
        ns.ECME.db = {
            profile = {
                cdmBars = {
                    bars = {
                        { key = "buffs", name = "Buffs" },
                        { key = "custom_buff_1", name = "Raid Buffs" },
                        { key = "cooldowns", name = "Cooldowns" },
                    },
                },
            },
        }

        ns.IsBarBuffFamily = function(bar)
            return bar.key == "buffs" or bar.key == "custom_buff_1"
        end

        ns.GetCDMSpellsForBar = function(barKey)
            if barKey == "buffs" then
                return {
                    { spellID = 10, cdID = 1001, name = "A", icon = "icon-a", isKnown = true },
                    { spellID = 11, cdID = 1002, name = "B", icon = "icon-b", isKnown = true },
                    { spellID = 10, cdID = 1003, name = "A duplicate", icon = "icon-a", isKnown = true },
                }
            end

            if barKey == "custom_buff_1" then
                return {
                    { spellID = 12, cdID = 1004, name = "C", icon = "icon-c", isKnown = false },
                    { spellID = 13, cdID = 1005, name = "D", icon = "icon-d", isKnown = true },
                }
            end

            return nil
        end

        ns.IsSpellInBuffBarViewer = function(spellID)
            return spellID == 10 or spellID == 13
        end

        local tracked, untracked = ns.GetAllCDMBuffSpells()

        assert.same({ 10, 13 }, spellIDs(tracked))
        assert.same({ 11 }, spellIDs(untracked))
        assert.are.equal("Buffs", tracked[1].barName)
        assert.are.equal("Raid Buffs", tracked[2].barName)
    end)

    it("updates glow visuals only when aura state changes", function()
        local ns = buildNamespace()
        ns.StartNativeGlow = function(_, style, r, g, b)
            glowEvents[#glowEvents + 1] = { event = "start", style = style, r = r, g = g, b = b }
        end
        ns.StopNativeGlow = function()
            glowEvents[#glowEvents + 1] = { event = "stop" }
        end
        ns = loadBarGlows(ns)

        _G.EABButton1 = makeFrame({ frameLevel = 5 })
        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    spec = {
                        barGlows = {
                            enabled = true,
                            selectedBar = "cooldowns",
                            assignments = {
                                ["1_1"] = {
                                    { spellID = 10, mode = "ACTIVE", glowStyle = 3 },
                                },
                            },
                        },
                    },
                },
            },
        }

        ns._tickBlizzActiveCache = { [10] = true }

        ns.InitBarGlows()
        ns.UpdateOverlayVisuals()

        assert.are.equal(2, #glowEvents)
        assert.are.equal("stop", glowEvents[1].event)
        assert.are.equal("start", glowEvents[2].event)
        assert.are.equal(3, glowEvents[2].style)

        ns.UpdateOverlayVisuals()
        assert.are.equal(2, #glowEvents)

        ns._tickBlizzActiveCache = {}
        ns.UpdateOverlayVisuals()
        assert.are.equal(3, #glowEvents)
        assert.are.equal("stop", glowEvents[3].event)
    end)

    it("forces custom-shape glows and prefers class colors for cdm icons", function()
        local ns = buildNamespace()
        ns.StartNativeGlow = function(_, style, r, g, b)
            glowEvents[#glowEvents + 1] = { event = "start", style = style, r = r, g = g, b = b }
        end
        ns.StopNativeGlow = function()
            glowEvents[#glowEvents + 1] = { event = "stop" }
        end
        ns.cdmBarIcons = {
            buffs = {
                makeFrame({ cooldownID = 77, frameLevel = 7, shapeName = "hex" }),
            },
        }
        ns = loadBarGlows(ns)

        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    spec = {
                        barGlows = {
                            enabled = true,
                            selectedBar = "cooldowns",
                            assignments = {
                                ["cdm_77"] = {
                                    {
                                        spellID = 20,
                                        mode = "MISSING",
                                        glowStyle = 1,
                                        classColor = true,
                                        glowColor = { r = 0.9, g = 0.8, b = 0.7 },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        }

        ns._tickBlizzActiveCache = {}

        ns.RequestBarGlowUpdate()

        assert.are.equal(2, #glowEvents)
        assert.are.equal("start", glowEvents[2].event)
        assert.are.equal(2, glowEvents[2].style)
        assert.are.equal(0.1, glowEvents[2].r)
        assert.are.equal(0.2, glowEvents[2].g)
        assert.are.equal(0.3, glowEvents[2].b)
    end)

    it("falls back to Blizzard action buttons when no EAB button exists", function()
        local ns = buildNamespace()
        ns.StartNativeGlow = function(_, style, r, g, b)
            glowEvents[#glowEvents + 1] = { event = "start", style = style, r = r, g = g, b = b }
        end
        ns.StopNativeGlow = function()
            glowEvents[#glowEvents + 1] = { event = "stop" }
        end
        ns = loadBarGlows(ns)

        _G.ActionButton2 = makeFrame({ frameLevel = 9 })
        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    spec = {
                        barGlows = {
                            enabled = true,
                            selectedBar = "cooldowns",
                            assignments = {
                                ["1_2"] = {
                                    { spellID = 30, mode = "ACTIVE" },
                                },
                            },
                        },
                    },
                },
            },
        }

        ns._tickBlizzActiveCache = { [30] = true }

        ns.RequestBarGlowUpdate()

        assert.are.equal("start", glowEvents[2].event)
        assert.are.equal(_G.ActionButton2, createdFrames[#createdFrames]:GetParent())
    end)

    it("uses explicit glow colors and hides existing overlays when disabled", function()
        local ns = buildNamespace()
        ns.StartNativeGlow = function(_, style, r, g, b)
            glowEvents[#glowEvents + 1] = { event = "start", style = style, r = r, g = g, b = b }
        end
        ns.StopNativeGlow = function()
            glowEvents[#glowEvents + 1] = { event = "stop" }
        end
        ns = loadBarGlows(ns)

        _G.EABButton1 = makeFrame({ frameLevel = 5 })
        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    spec = {
                        barGlows = {
                            enabled = true,
                            selectedBar = "cooldowns",
                            assignments = {
                                ["1_1"] = {
                                    {
                                        spellID = 40,
                                        mode = "ACTIVE",
                                        glowStyle = 1,
                                        glowColor = { r = 0.4, g = 0.5, b = 0.6 },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        }

        ns._tickBlizzActiveCache = { [40] = true }

        ns.RequestBarGlowUpdate()

        assert.are.equal("start", glowEvents[2].event)
        assert.are.equal(0.4, glowEvents[2].r)
        assert.are.equal(0.5, glowEvents[2].g)
        assert.are.equal(0.6, glowEvents[2].b)
        assert.is_true(createdFrames[1]:IsShown())

        EllesmereUIDB.spellAssignments.specProfiles.spec.barGlows.enabled = false
        ns.RequestBarGlowUpdate()

        assert.is_false(createdFrames[1]:IsShown())
        assert.are.equal("stop", glowEvents[#glowEvents].event)
    end)
end)