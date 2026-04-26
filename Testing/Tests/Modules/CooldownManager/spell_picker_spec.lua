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
    local original_EssentialCooldownViewer
    local original_UtilityCooldownViewer
    local original_BuffIconCooldownViewer

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

    local function makeActivePool(frames)
        return {
            EnumerateActive = function()
                local index = 0
                return function()
                    index = index + 1
                    return frames[index]
                end
            end,
        }
    end

    local function formatList(values)
        if type(values) ~= "table" then
            return tostring(values)
        end

        local parts = {}
        for index = 1, #values do
            parts[#parts + 1] = tostring(values[index])
        end
        return "{" .. table.concat(parts, ", ") .. "}"
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
        original_EssentialCooldownViewer = _G.EssentialCooldownViewer
        original_UtilityCooldownViewer = _G.UtilityCooldownViewer
        original_BuffIconCooldownViewer = _G.BuffIconCooldownViewer

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
            GetSpellName = function(spellID)
                local names = {
                    [101] = "Alpha Utility",
                    [200] = "Zulu Essential",
                    [201] = "Buff Variant",
                }
                return names[spellID]
            end,
            GetSpellTexture = function(spellID)
                return "icon-" .. tostring(spellID)
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
        _G.EssentialCooldownViewer = nil
        _G.UtilityCooldownViewer = nil
        _G.BuffIconCooldownViewer = nil
    end)

    after_each(function()
        _G.C_Spell = original_C_Spell
        _G.C_CooldownViewer = original_C_CooldownViewer
        _G.issecretvalue = original_issecretvalue
        _G.GetTime = original_GetTime
        _G.wipe = original_wipe
        _G.EllesmereUIDB = original_EllesmereUIDB
        _G.EssentialCooldownViewer = original_EssentialCooldownViewer
        _G.UtilityCooldownViewer = original_UtilityCooldownViewer
        _G.BuffIconCooldownViewer = original_BuffIconCooldownViewer
        if EllesmereUI then
            EllesmereUI.SetElementVisibility = originalSetElementVisibility
            EllesmereUI.UnregisterUnlockElement = originalUnregisterUnlockElement
        end
    end)

    -- Variant-family helpers are the low-level contract that keeps base spells,
    -- override spells, and their shared stored values in sync.

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

    it("resolves through a base spell's override when only that family member has a stored value", function()
        local ns = loadSpellPicker(buildNamespace())
        local target = { [200] = "family" }

        assert.are.equal("family", ns.ResolveVariantValue(target, 201))
    end)

    it("recognizes spells from the same variant family", function()
        local ns = loadSpellPicker(buildNamespace())

        assert.is_true(ns.IsVariantOf(100, 200))
        assert.is_true(ns.IsVariantOf(200, 300))
        assert.is_false(ns.IsVariantOf(100, 999))
        assert.is_false(ns.IsVariantOf("100", 200))
    end)

    -- Viewer-frame helpers define which spellID the picker stores before any
    -- bar routing or persistence logic runs.

    it("resolves canonical frame spellIDs using the documented priority order", function()
        local ns = loadSpellPicker(buildNamespace())

        assert.are.equal(200, ns.GetCanonicalSpellIDForFrame({
            GetSpellID = function()
                return 200
            end,
        }))

        assert.are.equal(201, ns.GetCanonicalSpellIDForFrame({
            GetAuraSpellID = function()
                return 201
            end,
        }))

        assert.are.equal(300, ns.GetCanonicalSpellIDForFrame({
            GetSpellID = function()
                return "secret"
            end,
            cooldownInfo = { overrideSpellID = 300, spellID = 100 },
        }))

        assert.are.equal(101, ns.GetCanonicalSpellIDForFrame({
            cooldownInfo = { spellID = 101 },
        }))

        assert.are.equal(201, ns.GetCanonicalSpellIDForFrame({
            cooldownInfo = { linkedSpellIDs = { "bad", 201, 999 } },
        }))

        assert.are.equal(200, ns.GetCanonicalSpellIDForFrame({
            GetSpellID = function()
                return 200
            end,
            GetCooldownInfo = function()
                return { spellID = "bad" }
            end,
        }))

        assert.are.equal(101, ns.GetCanonicalSpellIDForFrame({
            GetSpellID = function()
                return "bad"
            end,
            GetCooldownInfo = function()
                return { spellID = 101 }
            end,
        }))

        assert.is_nil(ns.GetCanonicalSpellIDForFrame({
            GetSpellID = function()
                return "bad"
            end,
            GetCooldownInfo = function()
                return { linkedSpellIDs = { "still bad" } }
            end,
        }))

        local callCount = 0
        assert.are.equal(100, ns.GetCanonicalSpellIDForFrame({
            GetSpellID = function()
                callCount = callCount + 1
                if callCount == 1 then
                    return "bad"
                end
                return 200
            end,
        }))

        callCount = 0
        assert.are.equal(999, ns.GetCanonicalSpellIDForFrame({
            GetSpellID = function()
                callCount = callCount + 1
                if callCount == 1 then
                    return "bad"
                end
                return 999
            end,
        }))
    end)

    it("enumerates viewer spells in viewer and layout order while skipping duplicates and hidden empty frames", function()
        local ns = loadSpellPicker(buildNamespace())

        _G.EssentialCooldownViewer = {
            itemFramePool = makeActivePool({
                {
                    cooldownID = 11,
                    layoutIndex = 2,
                    IsShown = function()
                        return true
                    end,
                    GetSpellID = function()
                        return 200
                    end,
                },
                {
                    cooldownID = 12,
                    layoutIndex = 1,
                    IsShown = function()
                        return false
                    end,
                    cooldownInfo = { spellID = 101 },
                },
                {
                    cooldownID = 13,
                    layoutIndex = 3,
                    IsShown = function()
                        return true
                    end,
                    GetSpellID = function()
                        return 200
                    end,
                },
                {
                    cooldownID = 14,
                    layoutIndex = 4,
                    IsShown = function()
                        return false
                    end,
                },
            }),
        }

        _G.UtilityCooldownViewer = {
            itemFramePool = makeActivePool({
                {
                    cooldownID = 21,
                    layoutIndex = 1,
                    IsShown = function()
                        return true
                    end,
                    cooldownInfo = { spellID = 101 },
                },
                {
                    cooldownID = 22,
                    layoutIndex = 0,
                    IsShown = function()
                        return true
                    end,
                    GetAuraSpellID = function()
                        return 201
                    end,
                },
            }),
        }

        local entries = ns.EnumerateCDMViewerSpells(false)

        assert.are.equal(3, #entries)
        assert.are.equal(101, entries[1].sid)
        assert.are.equal(12, entries[1].cdID)
        assert.are.equal("EssentialCooldownViewer", entries[1].viewerName)
        assert.are.equal(200, entries[2].sid)
        assert.are.equal(11, entries[2].cdID)
        assert.are.equal(201, entries[3].sid)
        assert.are.equal(22, entries[3].cdID)
        assert.are.equal("UtilityCooldownViewer", entries[3].viewerName)
    end)

    it("enumerates buff viewer spells and breaks same-layout ties by spellID", function()
        local ns = loadSpellPicker(buildNamespace())

        _G.BuffIconCooldownViewer = {
            itemFramePool = makeActivePool({
                {
                    cooldownID = 31,
                    layoutIndex = 0,
                    IsShown = function()
                        return true
                    end,
                    GetAuraSpellID = function()
                        return 201
                    end,
                },
                {
                    cooldownID = 32,
                    layoutIndex = 0,
                    IsShown = function()
                        return true
                    end,
                    cooldownInfo = { spellID = 101 },
                },
            }),
        }

        local entries = ns.EnumerateCDMViewerSpells(true)

        assert.are.equal(2, #entries)
        assert.are.equal(101, entries[1].sid)
        assert.are.equal(201, entries[2].sid)
    end)

    it("finds negative IDs by exact equality and rejects invalid lookup requests", function()
        local ns = loadSpellPicker(buildNamespace())

        assert.is_nil(ns.FindVariantIndexInList(nil, -13))
        assert.are.equal(2, ns.FindVariantIndexInList({ -13, -14 }, -14))
    end)

    it("builds picker spell rows from viewer entries and marks variant-family spells as already assigned", function()
        local ns = buildNamespace()
        local spellData = {
            cooldowns = { assignedSpells = { 100 } },
        }

        ns.GetBarSpellData = function(barKey)
            return spellData[barKey]
        end

        _G.EssentialCooldownViewer = {
            itemFramePool = makeActivePool({
                {
                    cooldownID = 11,
                    layoutIndex = 1,
                    IsShown = function()
                        return true
                    end,
                    GetSpellID = function()
                        return 200
                    end,
                },
            }),
        }
        _G.UtilityCooldownViewer = {
            itemFramePool = makeActivePool({
                {
                    cooldownID = 21,
                    layoutIndex = 1,
                    IsShown = function()
                        return true
                    end,
                    cooldownInfo = { spellID = 101 },
                },
            }),
        }

        loadSpellPicker(ns)
        local spells = ns.GetCDMSpellsForBar("cooldowns")

        assert.are.equal(2, #spells)
        assert(spells[1].spellID == 200 and spells[1].onEUIBar == true, "GetCDMSpellsForBar should mark variant-family matches as already assigned on the target bar")
        assert.are.equal("Zulu Essential", spells[1].name)
        assert.are.equal("icon-200", spells[1].icon)
        assert.are.equal("cooldown", spells[1].cdmCatGroup)
        assert(spells[2].spellID == 101 and spells[2].onEUIBar == false, "GetCDMSpellsForBar should leave unrelated viewer spells unclaimed")
    end)

    it("sorts picker rows alphabetically within the same viewer group", function()
        local ns = buildNamespace()
        ns.GetBarSpellData = function()
            return { assignedSpells = {} }
        end

        _G.C_Spell.GetSpellName = function(spellID)
            local names = {
                [101] = "Alpha Utility",
                [200] = "Zulu Essential",
            }
            return names[spellID]
        end
        _G.EssentialCooldownViewer = {
            itemFramePool = makeActivePool({
                {
                    cooldownID = 11,
                    layoutIndex = 1,
                    IsShown = function()
                        return true
                    end,
                    cooldownInfo = { spellID = 200 },
                },
                {
                    cooldownID = 12,
                    layoutIndex = 2,
                    IsShown = function()
                        return true
                    end,
                    cooldownInfo = { spellID = 101 },
                },
            }),
        }
        _G.UtilityCooldownViewer = {
            itemFramePool = makeActivePool({}),
        }

        loadSpellPicker(ns)
        local spells = ns.GetCDMSpellsForBar("cooldowns")

        assert.are.equal("Alpha Utility", spells[1].name)
        assert.are.equal("Zulu Essential", spells[2].name)
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

    it("treats custom_buff and unknown bars as non-buff-family entries", function()
        local ns = buildNamespace()
        ns.barDataByKey.aura_bar = { key = "aura_bar", barType = "custom_buff" }
        ns.barDataByKey.custom_cd = { key = "custom_cd", barType = "cooldowns" }
        ns.barDataByKey.untyped = { key = "untyped" }
        loadSpellPicker(ns)

        assert.are.equal("custom_buff", ns.GetBarType("aura_bar"))
        assert.are.equal("cooldowns", ns.GetBarType(ns.barDataByKey.custom_cd))
        assert.is_nil(ns.GetBarType("missing_bar"))
        assert.is_nil(ns.GetBarType(ns.barDataByKey.untyped))
        assert.is_false(ns.IsBarBuffFamily("aura_bar"))
        assert.is_false(ns.IsBarBuffFamily(ns.barDataByKey.custom_cd))
        assert.is_false(ns.IsBarBuffFamily("missing_bar"))
    end)

    -- Reorder operations should preserve the visible icon order that users see
    -- in the editor, even before a bar has persisted order data.

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

    -- Claiming and removing tracked spells is the core routing behavior of the
    -- picker: one spell has one home, and removed viewer spells fall back to a
    -- matching ghost bar instead of disappearing from the route map.

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

    it("collapses duplicate variant-family entries when replacing a tracked spell on the same bar", function()
        local ns = buildNamespace()
        local reanchorCalls = 0
        local spellData = {
            cooldowns = {
                assignedSpells = { 100, 999 },
                removedSpells = { [200] = true },
            },
        }

        ns.barDataByKey.cooldowns = { key = "cooldowns", barType = "cooldowns" }
        ns.cdmBarFrames.cooldowns = { _blizzCache = true, _prevVisibleCount = 2 }
        ns.GetBarSpellData = function(barKey)
            return spellData[barKey]
        end
        ns.QueueReanchor = function()
            reanchorCalls = reanchorCalls + 1
        end

        loadSpellPicker(ns)

        assert.is_true(ns.ReplaceTrackedSpell("cooldowns", 2, 200))
        assert(
            #spellData.cooldowns.assignedSpells == 1
                and spellData.cooldowns.assignedSpells[1] == 200,
            "replacing with a spell variant that is already represented on the bar should collapse the family to one entry; got assignedSpells="
                .. formatList(spellData.cooldowns.assignedSpells)
        )
        assert.is_nil(spellData.cooldowns.removedSpells[200])
        assert.is_nil(ns.cdmBarFrames.cooldowns._blizzCache)
        assert.is_nil(ns.cdmBarFrames.cooldowns._prevVisibleCount)
        assert.are.equal(1, reanchorCalls)
    end)

    it("detects displayed Blizzard cooldown children by direct or nested cooldownID", function()
        local ns = buildNamespace()
        local childA = { cooldownID = 11 }
        local childB = { cooldownInfo = { cooldownID = 22 } }

        ns.BLIZZ_CDM_FRAMES = { cooldowns = "TestCooldownViewer" }
        _G.TestCooldownViewer = {
            GetNumChildren = function()
                return 2
            end,
            GetChildren = function()
                return childA, childB
            end,
        }

        loadSpellPicker(ns)

        assert(ns.IsSpellDisplayedInCDM("cooldowns", 11) == true, "IsSpellDisplayedInCDM should match child.cooldownID values directly")
        assert(ns.IsSpellDisplayedInCDM("cooldowns", 22) == true, "IsSpellDisplayedInCDM should also inspect child.cooldownInfo.cooldownID")
        assert.is_false(ns.IsSpellDisplayedInCDM("cooldowns", 99))
        assert.is_false(ns.IsSpellDisplayedInCDM("missing", 11))
    end)

    it("merges dormant spells back into assigned positions once per spec without duplicating active entries", function()
        local ns = buildNamespace()

        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    specA = {
                        barSpells = {
                            cooldowns = {
                                assignedSpells = { 50 },
                                dormantSpells = {
                                    [50] = 3,
                                    [60] = 1,
                                    [70] = 5,
                                },
                            },
                        },
                    },
                },
            },
        }
        ns.GetActiveSpecKey = function()
            return "specA"
        end

        loadSpellPicker(ns)
        ns.MergeDormantSpellsIntoAssigned()

        local profile = _G.EllesmereUIDB.spellAssignments.specProfiles.specA
        assert.are.same({ 60, 50, 70 }, profile.barSpells.cooldowns.assignedSpells)
        assert.is_nil(profile.barSpells.cooldowns.dormantSpells)
        assert(profile._dormantMerged == true, "MergeDormantSpellsIntoAssigned should stamp the spec after folding dormant entries back in")
    end)

    it("reports other tracking buff bars that already use a spell via spellID or spellIDs lists", function()
        local ns = buildNamespace()
        ns.GetTrackedBuffBars = function()
            return {
                bars = {
                    { name = "Single Target", spellID = 10 },
                    { name = "Variant Group", spellIDs = { 20, 30 } },
                },
            }
        end

        loadSpellPicker(ns)

        assert.are.equal("Single Target", ns.SpellUsedOnAnyOtherTBB(10, 2))
        assert.are.equal("Variant Group", ns.SpellUsedOnAnyOtherTBB(30, 1))
        assert.is_nil(ns.SpellUsedOnAnyOtherTBB(10, 1))
        assert.is_nil(ns.SpellUsedOnAnyOtherTBB(99, 1))
    end)

    it("treats AddSpellToBar and RemoveSpellFromBar as variant-aware low-level helpers", function()
        local ns = buildNamespace()
        local spellData = {
            cooldowns = {
                assignedSpells = { 100 },
                customSpellDurations = { [100] = 15 },
                customSpellIDs = { [100] = 9001 },
                customSpellGroups = { [100] = 100, [200] = 100 },
            },
        }

        ns.cdmBarFrames.cooldowns = { _blizzCache = true, _prevVisibleCount = 1 }
        ns.GetBarSpellData = function(barKey)
            return spellData[barKey]
        end

        loadSpellPicker(ns)

        assert.is_false(ns.AddSpellToBar("cooldowns", 200))
        assert.are.same({ 100 }, spellData.cooldowns.assignedSpells)

        local removed = ns.RemoveSpellFromBar("cooldowns", 200)
        assert.are.equal(100, removed)
        assert.are.same({}, spellData.cooldowns.assignedSpells)
        assert.is_nil(spellData.cooldowns.customSpellDurations[100])
        assert.is_nil(spellData.cooldowns.customSpellIDs[100])
        assert.is_nil(spellData.cooldowns.customSpellGroups[100])
        assert.is_nil(spellData.cooldowns.customSpellGroups[200])
        assert.is_nil(ns.cdmBarFrames.cooldowns._blizzCache)
        assert.is_nil(ns.cdmBarFrames.cooldowns._prevVisibleCount)
    end)

    it("migrates unassigned CDM viewer/category spells into the ghost cooldown bar while removing orphan bar data", function()
        local ns = buildNamespace()

        _G.Enum = {
            CooldownViewerCategory = {
                Essential = 0,
                Utility = 1,
            },
        }
        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    specA = {
                        barSpells = {
                            cooldowns = { assignedSpells = { 100 } },
                            utility = { assignedSpells = {} },
                            __ghost_cd = { assignedSpells = { 300 } },
                            orphan_bar = { assignedSpells = { 999 } },
                        },
                    },
                },
            },
        }
        ns.ECME.db = {
            profile = {
                cdmBars = {
                    bars = {
                        { key = "cooldowns", barType = "cooldowns", enabled = true },
                        { key = "utility", barType = "utility", enabled = true },
                        { key = "buffs", barType = "buffs", enabled = true },
                    },
                },
            },
        }
        ns.GetActiveSpecKey = function()
            return "specA"
        end

        _G.EssentialCooldownViewer = {
            itemFramePool = makeActivePool({
                {
                    cooldownID = 11,
                    layoutIndex = 1,
                    IsShown = function()
                        return true
                    end,
                    GetSpellID = function()
                        return 200
                    end,
                },
                {
                    cooldownID = 12,
                    layoutIndex = 2,
                    IsShown = function()
                        return true
                    end,
                    cooldownInfo = { spellID = 400 },
                },
            }),
        }
        _G.UtilityCooldownViewer = {
            itemFramePool = makeActivePool({
                {
                    cooldownID = 21,
                    layoutIndex = 1,
                    IsShown = function()
                        return true
                    end,
                    cooldownInfo = { spellID = 300 },
                },
            }),
        }
        _G.C_CooldownViewer = {
            GetCooldownViewerCategorySet = function(category)
                if category == 0 then
                    return { 31 }
                end
                if category == 1 then
                    return { 41 }
                end
                return nil
            end,
            GetCooldownViewerCooldownInfo = function(cooldownID)
                local infos = {
                    [31] = { spellID = 300 },
                    [41] = { spellID = 500 },
                }
                return infos[cooldownID]
            end,
        }

        loadSpellPicker(ns)
        local addedCount = ns.MigrateSpecToBarFilterModelV6()

        local profile = _G.EllesmereUIDB.spellAssignments.specProfiles.specA
        assert.are.equal(2, addedCount)
        assert.is_nil(profile.barSpells.orphan_bar)
        assert(profile._barFilterModelV6 == true, "MigrateSpecToBarFilterModelV6 should stamp the spec after a successful migration")

        local ghostSet = {}
        for _, sid in ipairs(profile.barSpells.__ghost_cd.assignedSpells) do
            ghostSet[sid] = true
        end
        assert(ghostSet[300] == true and ghostSet[400] == true and ghostSet[500] == true, "migration should preserve existing ghosted spells and append newly unassigned viewer/category spells")
        assert(ghostSet[200] ~= true, "migration should not ghost a spell whose variant family is already explicitly assigned to a visible bar")
    end)

    it("creates the ghost cooldown bar during migration when it does not exist yet", function()
        local ns = buildNamespace()

        _G.Enum = {
            CooldownViewerCategory = {
                Essential = 0,
                Utility = 1,
            },
        }
        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    specA = {
                        barSpells = {
                            cooldowns = { assignedSpells = { 100 } },
                            utility = { assignedSpells = {} },
                        },
                    },
                },
            },
        }
        ns.ECME.db = {
            profile = {
                cdmBars = {
                    bars = {
                        { key = "cooldowns", barType = "cooldowns", enabled = true },
                        { key = "utility", barType = "utility", enabled = true },
                    },
                },
            },
        }
        ns.GetActiveSpecKey = function()
            return "specA"
        end
        _G.EssentialCooldownViewer = {
            itemFramePool = makeActivePool({
                {
                    cooldownID = 11,
                    layoutIndex = 1,
                    IsShown = function()
                        return true
                    end,
                    cooldownInfo = { spellID = 400 },
                },
            }),
        }
        _G.UtilityCooldownViewer = {
            itemFramePool = makeActivePool({}),
        }
        _G.C_CooldownViewer = {
            GetCooldownViewerCategorySet = function()
                return nil
            end,
            GetCooldownViewerCooldownInfo = function()
                return nil
            end,
        }

        loadSpellPicker(ns)
        assert.are.equal(1, ns.MigrateSpecToBarFilterModelV6())
        assert.are.same({ 400 }, _G.EllesmereUIDB.spellAssignments.specProfiles.specA.barSpells.__ghost_cd.assignedSpells)
    end)

    it("stamps the migration immediately when default cooldown and utility bars are empty", function()
        local ns = buildNamespace()

        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    specA = {
                        barSpells = {
                            cooldowns = { assignedSpells = {} },
                            utility = { assignedSpells = {} },
                        },
                    },
                },
            },
        }
        ns.ECME.db = {
            profile = {
                cdmBars = {
                    bars = {
                        { key = "cooldowns", barType = "cooldowns", enabled = true },
                        { key = "utility", barType = "utility", enabled = true },
                    },
                },
            },
        }
        ns.GetActiveSpecKey = function()
            return "specA"
        end

        loadSpellPicker(ns)
        assert.is_nil(ns.MigrateSpecToBarFilterModelV6())
        assert(_G.EllesmereUIDB.spellAssignments.specProfiles.specA._barFilterModelV6 == true, "empty default bars should mark the migration complete without trying to build ghost assignments")
    end)

    it("stamps the migration when the spec profile has no persisted barSpells yet", function()
        local ns = buildNamespace()

        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    specA = {},
                },
            },
        }
        ns.GetActiveSpecKey = function()
            return "specA"
        end

        loadSpellPicker(ns)

        assert.is_nil(ns.MigrateSpecToBarFilterModelV6())
        assert.is_true(_G.EllesmereUIDB.spellAssignments.specProfiles.specA._barFilterModelV6)
    end)

    it("treats only enabled cooldown and utility bars as visible assignments during migration", function()
        local ns = buildNamespace()

        _G.Enum = {
            CooldownViewerCategory = {
                Essential = 0,
                Utility = 1,
            },
        }
        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    specA = {
                        barSpells = {
                            cooldowns = { assignedSpells = { 100 } },
                            utility = { assignedSpells = {} },
                            disabled_custom = { assignedSpells = { 400 } },
                            buffs = { assignedSpells = { 500 } },
                            aura_bar = { assignedSpells = { 600 } },
                        },
                    },
                },
            },
        }
        ns.ECME.db = {
            profile = {
                cdmBars = {
                    bars = {
                        { key = "cooldowns", barType = "cooldowns", enabled = true },
                        { key = "utility", barType = "utility", enabled = true },
                        { key = "disabled_custom", barType = "cooldowns", enabled = false },
                        { key = "buffs", barType = "buffs", enabled = true },
                        { key = "aura_bar", barType = "custom_buff", enabled = true },
                    },
                },
            },
        }
        ns.GetActiveSpecKey = function()
            return "specA"
        end
        _G.EssentialCooldownViewer = {
            itemFramePool = makeActivePool({
                {
                    cooldownID = 11,
                    layoutIndex = 1,
                    IsShown = function()
                        return true
                    end,
                    cooldownInfo = { spellID = 400 },
                },
                {
                    cooldownID = 12,
                    layoutIndex = 2,
                    IsShown = function()
                        return true
                    end,
                    cooldownInfo = { spellID = 500 },
                },
                {
                    cooldownID = 13,
                    layoutIndex = 3,
                    IsShown = function()
                        return true
                    end,
                    cooldownInfo = { spellID = 600 },
                },
            }),
        }
        _G.UtilityCooldownViewer = {
            itemFramePool = makeActivePool({}),
        }
        _G.C_CooldownViewer = {
            GetCooldownViewerCategorySet = function()
                return nil
            end,
            GetCooldownViewerCooldownInfo = function()
                return nil
            end,
        }

        loadSpellPicker(ns)

        assert.are.equal(3, ns.MigrateSpecToBarFilterModelV6())
        local ghostSet = {}
        for _, sid in ipairs(_G.EllesmereUIDB.spellAssignments.specProfiles.specA.barSpells.__ghost_cd.assignedSpells) do
            ghostSet[sid] = true
        end
        assert.is_true(ghostSet[400])
        assert.is_true(ghostSet[500])
        assert.is_true(ghostSet[600])
        assert.is_true(_G.EllesmereUIDB.spellAssignments.specProfiles.specA._barFilterModelV6)
    end)

    it("leaves the migration unstamped when viewer pools are still empty and it must retry later", function()
        local ns = buildNamespace()

        _G.EllesmereUIDB = {
            spellAssignments = {
                specProfiles = {
                    specA = {
                        barSpells = {
                            cooldowns = { assignedSpells = { 100 } },
                            utility = { assignedSpells = {} },
                        },
                    },
                },
            },
        }
        ns.ECME.db = {
            profile = {
                cdmBars = {
                    bars = {
                        { key = "cooldowns", barType = "cooldowns", enabled = true },
                        { key = "utility", barType = "utility", enabled = true },
                    },
                },
            },
        }
        ns.GetActiveSpecKey = function()
            return "specA"
        end

        loadSpellPicker(ns)
        assert.is_nil(ns.MigrateSpecToBarFilterModelV6())
        assert.is_nil(_G.EllesmereUIDB.spellAssignments.specProfiles.specA._barFilterModelV6)
    end)

    -- These preset tests intentionally describe the desired custom_buff bar
    -- semantics. They currently fail and therefore document real bugs.

    it("stores preset primary IDs and group metadata on standard bars", function()
        local ns = buildNamespace()
        local spellData = {
            cooldowns = { assignedSpells = {} },
        }

        ns.barDataByKey.cooldowns = { key = "cooldowns", barType = "cooldowns" }
        ns.cdmBarFrames.cooldowns = { _blizzCache = true, _prevVisibleCount = 4 }
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
        assert.is_nil(ns.cdmBarFrames.cooldowns._blizzCache)
        assert.is_nil(ns.cdmBarFrames.cooldowns._prevVisibleCount)
    end)

    it("rejects duplicate primary preset IDs on standard bars without mutating metadata", function()
        local ns = buildNamespace()
        local spellData = {
            cooldowns = {
                assignedSpells = { 700 },
                customSpellDurations = { [700] = 15 },
                customSpellGroups = { [700] = 700, [701] = 700 },
            },
        }

        ns.barDataByKey.cooldowns = { key = "cooldowns", barType = "cooldowns" }
        ns.GetBarSpellData = function(barKey)
            return spellData[barKey]
        end

        loadSpellPicker(ns)

        local ok, reason = ns.AddPresetToBar("cooldowns", {
            spellIDs = { 700, 701, 702 },
            duration = 30,
        })

        assert.is_false(ok)
        assert.are.equal("exists", reason)
        assert.are.same({ 700 }, spellData.cooldowns.assignedSpells)
        assert.are.equal(15, spellData.cooldowns.customSpellDurations[700])
        assert.is_nil(spellData.cooldowns.customSpellDurations[702])
        assert.are.equal(700, spellData.cooldowns.customSpellGroups[701])
        assert.is_nil(spellData.cooldowns.customSpellGroups[702])
    end)

    it("rejects glow-based presets on custom_buff bars without mutating the bar", function()
        local ns = buildNamespace()
        local spellData = {
            aura_bar = {
                assignedSpells = { 701 },
                spellDurations = { [701] = 15 },
            },
        }

        ns.barDataByKey.aura_bar = { key = "aura_bar", barType = "custom_buff" }
        ns.GetBarSpellData = function(barKey)
            return spellData[barKey]
        end

        loadSpellPicker(ns)

        local ok, reason = ns.AddPresetToBar("aura_bar", {
            spellIDs = { 900, 901 },
            duration = 45,
            glowBased = true,
        })

        assert.is_false(ok)
        assert.is_nil(reason)
        assert.are.same({ 701 }, spellData.aura_bar.assignedSpells)
        assert.are.equal(15, spellData.aura_bar.spellDurations[701])
        assert.is_nil(spellData.aura_bar.spellDurations[900])
    end)

    it("stores every preset spellID on custom_buff aura bars so each aura variant can activate independently", function()
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
        -- custom_buff bars render each stored spellID separately and decide at
        -- runtime which aura variant is active. Keeping only the primary entry
        -- silently drops the other preset members.
        assert(
            #spellData.aura_bar.assignedSpells == 3
                and spellData.aura_bar.assignedSpells[1] == 700
                and spellData.aura_bar.assignedSpells[2] == 701
                and spellData.aura_bar.assignedSpells[3] == 702,
            "custom_buff presets should store every spellID individually so each aura variant can activate independently; got assignedSpells="
                .. formatList(spellData.aura_bar.assignedSpells)
        )
        assert.are.equal(30, spellData.aura_bar.spellDurations[700])
        assert.are.equal(30, spellData.aura_bar.spellDurations[701])
        assert.are.equal(30, spellData.aura_bar.spellDurations[702])
        assert.is_nil(spellData.aura_bar.customSpellGroups)
    end)

    it("treats any existing preset member on a custom_buff aura bar as a duplicate and rejects the add atomically", function()
        local ns = buildNamespace()
        local spellData = {
            aura_bar = {
                assignedSpells = { 701 },
                spellDurations = { [701] = 15 },
            },
        }

        ns.barDataByKey.aura_bar = { key = "aura_bar", barType = "custom_buff" }
        ns.GetBarSpellData = function(barKey)
            return spellData[barKey]
        end

        loadSpellPicker(ns)

        local preset = {
            spellIDs = { 700, 701, 702 },
            duration = 30,
        }

        local ok, reason = ns.AddPresetToBar("aura_bar", preset)

        -- The add should fail as soon as one member of the preset already
        -- exists. Accepting it would produce a partial preset with mixed old
        -- and new state on the same aura bar.
        assert(
            ok == false,
            "custom_buff preset adds should fail atomically when any preset member is already assigned; expected false with reason 'exists' but got ok="
                .. tostring(ok)
                .. ", reason="
                .. tostring(reason)
                .. ", assignedSpells="
                .. formatList(spellData.aura_bar.assignedSpells)
        )
        assert.are.equal("exists", reason)
        assert.are.same({ 701 }, spellData.aura_bar.assignedSpells)
        assert.are.equal(15, spellData.aura_bar.spellDurations[701])
        assert.is_nil(spellData.aura_bar.spellDurations[700])
        assert.is_nil(spellData.aura_bar.spellDurations[702])
    end)

    -- Custom bar lifecycle helpers are mostly persistence and refresh wiring.

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

    -- Cache tests pin the exact invalidation contract so stale CDM spell data
    -- is easy to spot when future refactors touch viewer/category lookups.

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