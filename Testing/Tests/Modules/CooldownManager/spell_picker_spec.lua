-- Focused helper coverage for the Cooldown Manager spell picker module.

describe("Cooldown Manager spell picker helpers", function()
    local modulePath = "EllesmereUICooldownManager/EllesmereUICdmSpellPicker.lua"
    local original_C_Spell
    local original_C_CooldownViewer
    local original_issecretvalue
    local original_GetTime
    local original_wipe
    local original_EllesmereUIDB
    local originalSetElementVisibility
    local originalUnregisterUnlockElement

    local function loadSpellPicker(ns)
        local chunk, err = loadfile(modulePath)
        assert.is_nil(err)
        chunk("EllesmereUICooldownManager", ns)
        return ns
    end

    local function buildNamespace()
        return {
            ECME = {},
            barDataByKey = {},
            cdmBarFrames = {},
            cdmBarIcons = {},
            GHOST_BUFF_BAR_KEY = "__ghost_buffs",
            GHOST_CD_BAR_KEY = "__ghost_cd",
            ResolveInfoSpellID = function(info)
                return info and info.spellID or nil
            end,
            ComputeTopRowStride = function()
                return 99, 1, 0
            end,
            _ecmeFC = {},
            CDM_BAR_ROOTS = {
                cooldowns = true,
                utility = true,
                buffs = true,
            },
            DEFAULT_MAPPING_NAME = "Default",
        }
    end

    before_each(function()
        original_C_Spell = _G.C_Spell
        original_C_CooldownViewer = _G.C_CooldownViewer
        original_issecretvalue = _G.issecretvalue
        original_GetTime = _G.GetTime
        original_wipe = _G.wipe
        original_EllesmereUIDB = _G.EllesmereUIDB
        originalSetElementVisibility = EllesmereUI and EllesmereUI.SetElementVisibility
        originalUnregisterUnlockElement = EllesmereUI and EllesmereUI.UnregisterUnlockElement

        _G.C_Spell = {
            GetBaseSpell = function(spellID)
                local baseBySpell = {
                    [200] = 100,
                    [201] = 100,
                    [300] = 100,
                }
                return baseBySpell[spellID]
            end,
            GetOverrideSpell = function(spellID)
                local overrideBySpell = {
                    [100] = 200,
                    [101] = 201,
                    [200] = 300,
                }
                return overrideBySpell[spellID]
            end,
        }

        _G.issecretvalue = function()
            return false
        end

        _G.GetTime = function()
            return 42.5
        end

        _G.wipe = function(target)
            for key in pairs(target) do
                target[key] = nil
            end
        end

        _G.C_CooldownViewer = nil
        _G.EllesmereUIDB = nil
    end)

    after_each(function()
        _G.C_Spell = original_C_Spell
        _G.C_CooldownViewer = original_C_CooldownViewer
        _G.issecretvalue = original_issecretvalue
        _G.GetTime = original_GetTime
        _G.wipe = original_wipe
        _G.EllesmereUIDB = original_EllesmereUIDB
        if EllesmereUI then
            EllesmereUI.SetElementVisibility = originalSetElementVisibility
            EllesmereUI.UnregisterUnlockElement = originalUnregisterUnlockElement
        end
    end)

    it("stores and resolves values across a spell variant family", function()
        local ns = loadSpellPicker(buildNamespace())
        local target = {}

        ns.StoreVariantValue(target, 100, "hero", false)

        assert.are.equal("hero", target[100])
        assert.are.equal("hero", target[200])
        assert.is_nil(target[300])
        assert.are.equal("hero", ns.ResolveVariantValue(target, 100))
        assert.are.equal("hero", ns.ResolveVariantValue(target, 200))
        assert.are.equal("hero", ns.ResolveVariantValue(target, 300))
    end)

    it("preserves existing variant values when requested", function()
        local ns = loadSpellPicker(buildNamespace())
        local target = { [200] = "existing" }

        ns.StoreVariantValue(target, 100, "new", true)

        assert.are.equal("existing", target[200])
        assert.are.equal("new", target[100])
        assert.is_nil(target[300])
        assert.are.equal("new", ns.ResolveVariantValue(target, 300))
    end)

    it("recognizes spells from the same variant family", function()
        local ns = loadSpellPicker(buildNamespace())

        assert.is_true(ns.IsVariantOf(100, 200))
        assert.is_true(ns.IsVariantOf(200, 300))
        assert.is_false(ns.IsVariantOf(100, 999))
        assert.is_false(ns.IsVariantOf("100", 200))
    end)

    it("infers legacy default bar types and buff families from bar keys", function()
        local ns = buildNamespace()
        ns.barDataByKey.custom = { key = "custom", barType = "buffs" }
        loadSpellPicker(ns)

        assert.are.equal("cooldowns", ns.GetBarType("cooldowns"))
        assert.are.equal("utility", ns.GetBarType("utility"))
        assert.are.equal("buffs", ns.GetBarType("buffs"))
        assert.are.equal("buffs", ns.GetBarType(ns.barDataByKey.custom))
        assert.is_true(ns.IsBarBuffFamily("buffs"))
        assert.is_true(ns.IsBarBuffFamily("__ghost_buffs"))
        assert.is_false(ns.IsBarBuffFamily("__ghost_cd"))
        assert.is_false(ns.IsBarBuffFamily("cooldowns"))
    end)

    it("seeds visible icon order before swapping tracked spells", function()
        local ns = buildNamespace()
        local reanchorCalls = 0
        local barState = { assignedSpells = {} }

        ns.cdmBarIcons.cooldowns = {
            { _spellID = 11 },
            { _spellID = 22 },
            { _spellID = 33 },
        }
        ns._ecmeFC[ns.cdmBarIcons.cooldowns[2]] = { spellID = 222 }
        ns.cdmBarFrames.cooldowns = { _blizzCache = true }
        ns.GetBarSpellData = function()
            return barState
        end
        ns.QueueReanchor = function()
            reanchorCalls = reanchorCalls + 1
        end

        loadSpellPicker(ns)
        local changed = ns.SwapTrackedSpells("cooldowns", 1, 3)

        assert.is_true(changed)
        assert.are.same({ 33, 222, 11 }, barState.assignedSpells)
        assert.is_nil(ns.cdmBarFrames.cooldowns._blizzCache)
        assert.are.equal(1, reanchorCalls)
    end)

    it("moves tracked spells by insertion and trims placeholder zeros", function()
        local ns = buildNamespace()
        local reanchorCalls = 0
        local barState = { assignedSpells = { 10, 20, 30 } }

        ns.GetBarSpellData = function()
            return barState
        end
        ns.cdmBarFrames.cooldowns = { _blizzCache = true }
        ns.QueueReanchor = function()
            reanchorCalls = reanchorCalls + 1
        end

        loadSpellPicker(ns)

        assert.is_true(ns.MoveTrackedSpell("cooldowns", 1, 3))
        assert.are.same({ 20, 30, 10 }, barState.assignedSpells)
        assert.is_nil(ns.cdmBarFrames.cooldowns._blizzCache)
        assert.are.equal(1, reanchorCalls)

        assert.is_false(ns.MoveTrackedSpell("cooldowns", 2, 2))
        assert.is_false(ns.MoveTrackedSpell("cooldowns", 0, 1))
    end)

    it("claims a spell for one non-buff bar and removes it from other bars in that family", function()
        local ns = buildNamespace()
        local routeMapRebuilds = 0
        local reanchorCalls = 0
        local spellData = {
            cooldowns = { assignedSpells = { 100 } },
            utility = { assignedSpells = {}, removedSpells = { [200] = true } },
            buffs = { assignedSpells = { 500 } },
            __ghost_cd = { assignedSpells = { 300 } },
        }

        ns.ECME.db = {
            profile = {
                cdmBars = {
                    bars = {
                        { key = "cooldowns", barType = "cooldowns" },
                        { key = "utility", barType = "utility" },
                        { key = "buffs", barType = "buffs" },
                        { key = "__ghost_cd", barType = "cooldowns" },
                    },
                },
            },
        }
        ns.barDataByKey.cooldowns = { key = "cooldowns", barType = "cooldowns" }
        ns.barDataByKey.utility = { key = "utility", barType = "utility" }
        ns.barDataByKey.buffs = { key = "buffs", barType = "buffs" }
        ns.barDataByKey.__ghost_cd = { key = "__ghost_cd", barType = "cooldowns" }
        ns.cdmBarFrames.utility = { _blizzCache = true, _prevVisibleCount = 3 }
        ns.GetBarSpellData = function(barKey)
            return spellData[barKey]
        end
        ns.RebuildSpellRouteMap = function()
            routeMapRebuilds = routeMapRebuilds + 1
        end
        ns.QueueReanchor = function()
            reanchorCalls = reanchorCalls + 1
        end

        loadSpellPicker(ns)

        assert.is_true(ns.AddTrackedSpell("utility", 200))
        assert.are.same({}, spellData.cooldowns.assignedSpells)
        assert.are.same({ 200 }, spellData.utility.assignedSpells)
        assert.is_nil(spellData.utility.removedSpells[200])
        assert.are.same({ 500 }, spellData.buffs.assignedSpells)
        assert.are.same({}, spellData.__ghost_cd.assignedSpells)
        assert.is_nil(ns.cdmBarFrames.utility._blizzCache)
        assert.is_nil(ns.cdmBarFrames.utility._prevVisibleCount)
        assert.are.equal(1, routeMapRebuilds)
        assert.are.equal(1, reanchorCalls)
    end)

    it("routes removed viewer spells to the matching ghost bar", function()
        local ns = buildNamespace()
        local routeMapRebuilds = 0
        local reanchorCalls = 0
        local spellData = {
            cooldowns = {
                assignedSpells = { 321 },
                customSpellDurations = { [321] = 18 },
                customSpellIDs = {},
                customSpellGroups = { [321] = 321, [322] = 321 },
            },
            __ghost_cd = { assignedSpells = {} },
        }

        ns.barDataByKey.cooldowns = { key = "cooldowns", barType = "cooldowns" }
        ns.barDataByKey.__ghost_cd = { key = "__ghost_cd", barType = "cooldowns" }
        ns.cdmBarFrames.cooldowns = { _blizzCache = true, _prevVisibleCount = 2 }
        ns.cdmBarFrames.__ghost_cd = { _blizzCache = true, _prevVisibleCount = 1 }
        ns.GetBarSpellData = function(barKey)
            return spellData[barKey]
        end
        ns.RebuildSpellRouteMap = function()
            routeMapRebuilds = routeMapRebuilds + 1
        end
        ns.QueueReanchor = function()
            reanchorCalls = reanchorCalls + 1
        end

        loadSpellPicker(ns)

        assert.is_true(ns.RemoveTrackedSpell("cooldowns", 1))
        assert.are.same({}, spellData.cooldowns.assignedSpells)
        assert.is_nil(spellData.cooldowns.customSpellDurations[321])
        assert.is_nil(spellData.cooldowns.customSpellGroups[321])
        assert.is_nil(spellData.cooldowns.customSpellGroups[322])
        assert.are.same({ 321 }, spellData.__ghost_cd.assignedSpells)
        assert.are.equal(1, routeMapRebuilds)
        assert.are.equal(1, reanchorCalls)
    end)

    it("stores presets differently for aura bars and regular cooldown bars", function()
        local ns = buildNamespace()
        local spellData = {
            cooldowns = { assignedSpells = {} },
            aura_bar = { assignedSpells = {} },
        }

        ns.barDataByKey.cooldowns = { key = "cooldowns", barType = "cooldowns" }
        ns.barDataByKey.aura_bar = { key = "aura_bar", barType = "custom_buff" }
        ns.GetBarSpellData = function(barKey)
            return spellData[barKey]
        end

        loadSpellPicker(ns)

        local preset = {
            spellIDs = { 700, 701, 702 },
            duration = 30,
        }

        assert.is_true(ns.AddPresetToBar("cooldowns", preset))
        assert.are.same({ 700 }, spellData.cooldowns.assignedSpells)
        assert.are.equal(30, spellData.cooldowns.customSpellDurations[700])
        assert.are.equal(700, spellData.cooldowns.customSpellGroups[700])
        assert.are.equal(700, spellData.cooldowns.customSpellGroups[701])
        assert.are.equal(700, spellData.cooldowns.customSpellGroups[702])

        assert.is_true(ns.AddPresetToBar("aura_bar", preset))
        assert.are.same({ 700 }, spellData.aura_bar.assignedSpells)
        assert.are.equal(30, spellData.aura_bar.spellDurations[700])
        assert.is_nil(spellData.aura_bar.customSpellGroups)
    end)

    it("creates a custom bar with initialized spell storage and refresh hooks", function()
        local ns = buildNamespace()
        local buildCalls = 0
        local layoutKeys = {}
        local registerCalls = 0
        local reanchorCalls = 0
        local spellData = {}

        ns.MAX_CUSTOM_BARS = 10
        ns.ECME.db = {
            profile = {
                cdmBars = {
                    bars = {
                        { key = "cooldowns", barType = "cooldowns" },
                        { key = "utility", barType = "utility" },
                        { key = "buffs", barType = "buffs" },
                        { key = "existing_custom", barType = "custom_buff" },
                    },
                },
            },
        }
        ns.BuildAllCDMBars = function()
            buildCalls = buildCalls + 1
        end
        ns.LayoutCDMBar = function(barKey)
            layoutKeys[#layoutKeys + 1] = barKey
        end
        ns.RegisterCDMUnlockElements = function()
            registerCalls = registerCalls + 1
        end
        ns.QueueReanchor = function()
            reanchorCalls = reanchorCalls + 1
        end
        ns.GetBarSpellData = function(barKey)
            spellData[barKey] = spellData[barKey] or {}
            return spellData[barKey]
        end

        loadSpellPicker(ns)

        local barKey = ns.AddCDMBar("custom_buff", nil, 3)
        local bars = ns.ECME.db.profile.cdmBars.bars
        local created = bars[#bars]

        assert.are.equal("custom_5_42_5", barKey)
        assert.are.equal(barKey, created.key)
        assert.are.equal("Custom Auras Bar 2", created.name)
        assert.are.equal("custom_buff", created.barType)
        assert.are.equal(3, created.numRows)
        assert.are.same({}, spellData[barKey].assignedSpells)
        assert.are.equal(1, buildCalls)
        assert.are.same({ barKey }, layoutKeys)
        assert.are.equal(1, registerCalls)
        assert.are.equal(1, reanchorCalls)
    end)

    it("removes a custom bar and cleans up persisted spell assignments", function()
        local ns = buildNamespace()
        local registerCalls = 0
        local routeMapRebuilds = 0
        local collectCalls = 0
        local hiddenFrames = {}

        ns.ECME.db = {
            profile = {
                cdmBars = {
                    bars = {
                        { key = "cooldowns", barType = "cooldowns" },
                        { key = "custom_remove", barType = "utility" },
                    },
                },
                cdmBarPositions = {
                    custom_remove = { point = "CENTER" },
                },
            },
        }
        ns.cdmBarFrames.custom_remove = { id = "frame" }
        ns.cdmBarIcons.custom_remove = { "icon" }
        ns.RegisterCDMUnlockElements = function()
            registerCalls = registerCalls + 1
        end
        ns.RebuildSpellRouteMap = function()
            routeMapRebuilds = routeMapRebuilds + 1
        end
        ns.CollectAndReanchor = function()
            collectCalls = collectCalls + 1
        end

        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    specA = { barSpells = { custom_remove = { assignedSpells = { 11 } } } },
                    specB = { barSpells = { custom_remove = { assignedSpells = { 22 } }, other = {} } },
                },
            },
        }

        EllesmereUI.SetElementVisibility = function(frame, visible)
            hiddenFrames[#hiddenFrames + 1] = { frame = frame, visible = visible }
        end
        EllesmereUI.UnregisterUnlockElement = function(_, key)
            hiddenFrames[#hiddenFrames + 1] = { unregister = key }
        end

        loadSpellPicker(ns)

        assert.is_true(ns.RemoveCDMBar("custom_remove"))
        assert.is_false(ns.RemoveCDMBar("cooldowns"))
        assert.are.equal(1, #ns.ECME.db.profile.cdmBars.bars)
        assert.is_nil(ns.ECME.db.profile.cdmBarPositions.custom_remove)
        assert.is_nil(ns.cdmBarFrames.custom_remove)
        assert.is_nil(ns.cdmBarIcons.custom_remove)
        assert.is_nil(_G.EllesmereUIDB.spellAssignments.specProfiles.specA.barSpells.custom_remove)
        assert.is_nil(_G.EllesmereUIDB.spellAssignments.specProfiles.specB.barSpells.custom_remove)
        assert.are.equal("CDM_custom_remove", hiddenFrames[2].unregister)
        assert.are.equal(1, registerCalls)
        assert.are.equal(1, routeMapRebuilds)
        assert.are.equal(1, collectCalls)
    end)

    it("rebuilds and reuses CDM spell caches until marked dirty again", function()
        local ns = buildNamespace()
        local categoryCalls = 0
        local infoByCooldownID = {
            [11] = { spellID = 101 },
            [12] = { spellID = 102, overrideSpellID = 202 },
            [21] = { spellID = 103 },
        }

        _G.C_CooldownViewer = {
            GetCooldownViewerCategorySet = function(category, includeAll)
                categoryCalls = categoryCalls + 1
                if category == 0 and not includeAll then
                    return { 11, 12 }
                end
                if category == 1 and includeAll then
                    return { 21 }
                end
                return nil
            end,
            GetCooldownViewerCooldownInfo = function(cooldownID)
                return infoByCooldownID[cooldownID]
            end,
        }
        ns.ResolveInfoSpellID = function(info)
            return info.overrideSpellID or info.spellID
        end

        loadSpellPicker(ns)

        assert.is_true(ns.IsSpellKnownInCDM(101))
        assert.is_true(ns.IsSpellKnownInCDM(202))
        assert.is_false(ns.IsSpellKnownInCDM(103))
        assert.is_true(ns.IsSpellInAnyCDMCategory(103))
        assert.is_false(ns.IsSpellKnownInCDM(0))
        assert.are.equal(8, categoryCalls)

        assert.is_true(ns.IsSpellKnownInCDM(101))
        assert.are.equal(8, categoryCalls)

        ns.MarkCDMSpellCacheDirty()
        assert.is_true(ns.IsSpellInAnyCDMCategory(103))
        assert.are.equal(16, categoryCalls)
    end)
end)