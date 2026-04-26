describe("Cooldown Manager hook resolution helpers", function()
    local modulePath = "EllesmereUICooldownManager/EllesmereUICdmHooks.lua"

    local original_CreateFrame
    local original_C_CooldownViewer
    local original_C_SpellBook
    local original_C_CurveUtil
    local original_Enum

    local cooldownInfoByID
    local liveOverrideByBaseID

    local function loadHooks(ns)
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
            MAIN_BAR_KEYS = {},
            ResolveInfoSpellID = function(info)
                if not info then return nil end
                if info.overrideSpellID and info.overrideSpellID > 0 then
                    return info.overrideSpellID
                end
                if info.linkedSpellIDs then
                    for i = 1, #info.linkedSpellIDs do
                        local spellID = info.linkedSpellIDs[i]
                        if spellID and spellID > 0 then
                            return spellID
                        end
                    end
                end
                return info.spellID
            end,
            GetCDMFont = function()
                return "Fonts\\FRIZQT__.TTF"
            end,
            _ecmeFC = setmetatable({}, { __mode = "k" }),
            FC = {},
            CDM_ITEM_PRESETS = {},
        }
    end

    before_each(function()
        original_CreateFrame = _G.CreateFrame
        original_C_CooldownViewer = _G.C_CooldownViewer
        original_C_SpellBook = _G.C_SpellBook
        original_C_CurveUtil = _G.C_CurveUtil
        original_Enum = _G.Enum

        cooldownInfoByID = {}
        liveOverrideByBaseID = {}

        _G.CreateFrame = function()
            return {
                RegisterEvent = function() end,
                RegisterUnitEvent = function() end,
                SetScript = function() end,
                Hide = function(self)
                    self.hidden = true
                end,
                Show = function(self)
                    self.hidden = false
                end,
                IsShown = function(self)
                    return not self.hidden
                end,
            }
        end
        _G.C_CooldownViewer = {
            GetCooldownViewerCooldownInfo = function(cooldownID)
                return cooldownInfoByID[cooldownID]
            end,
        }
        _G.C_SpellBook = {
            FindSpellOverrideByID = function(baseSpellID)
                return liveOverrideByBaseID[baseSpellID] or 0
            end,
        }
        _G.C_CurveUtil = nil
        _G.Enum = {
            LuaCurveType = {
                Step = 1,
            },
        }
    end)

    after_each(function()
        _G.CreateFrame = original_CreateFrame
        _G.C_CooldownViewer = original_C_CooldownViewer
        _G.C_SpellBook = original_C_SpellBook
        _G.C_CurveUtil = original_C_CurveUtil
        _G.Enum = original_Enum
    end)

    it("resolves and caches display and base spell IDs from cooldown viewer info", function()
        cooldownInfoByID[77] = {
            spellID = 100,
            overrideSpellID = 200,
            linkedSpellIDs = { 300 },
        }

        local ns = loadHooks(buildNamespace())
        local frame = { cooldownID = 77 }

        local displaySpellID, baseSpellID = ns.ResolveFrameSpellID(frame)

        assert.are.equal(200, displaySpellID)
        assert.are.equal(100, baseSpellID)
        assert.are.same({ resolvedSid = 200, baseSpellID = 100, overrideSid = 200, cachedCdID = 77, cachedAuraInstID = nil, linkedSpellIDs = { 300 } }, ns._ecmeFC[frame])
    end)

    it("refreshes a cached resolved spell when the live override changes", function()
        cooldownInfoByID[88] = {
            spellID = 100,
            overrideSpellID = 200,
        }

        local ns = loadHooks(buildNamespace())
        local frame = { cooldownInfo = { cooldownID = 88 } }

        assert.are.equal(200, select(1, ns.ResolveFrameSpellID(frame)))

        liveOverrideByBaseID[100] = 333

        local displaySpellID, baseSpellID = ns.ResolveFrameSpellID(frame)

        assert.are.equal(333, displaySpellID)
        assert.are.equal(100, baseSpellID)
        assert.are.equal(333, ns._ecmeFC[frame].resolvedSid)
        assert.are.equal(333, ns._ecmeFC[frame].overrideSid)
    end)

    it("returns nil when cooldown viewer info is missing or invalid", function()
        local ns = loadHooks(buildNamespace())

        assert.is_nil(select(1, ns.ResolveFrameSpellID({})))

        cooldownInfoByID[99] = nil
        assert.is_nil(select(1, ns.ResolveFrameSpellID({ cooldownID = 99 })))

        cooldownInfoByID[100] = { spellID = 0, overrideSpellID = 0, linkedSpellIDs = { 0 } }
        assert.is_nil(select(1, ns.ResolveFrameSpellID({ cooldownID = 100 })))
    end)
end)