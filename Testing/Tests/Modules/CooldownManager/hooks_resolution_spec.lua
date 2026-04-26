describe("Cooldown Manager hook resolution helpers", function()
    local modulePath = "EllesmereUICooldownManager/EllesmereUICdmHooks.lua"

    local original_CreateFrame
    local original_hooksecurefunc
    local original_C_CooldownViewer
    local original_C_SpellBook
    local original_C_Spell
    local original_C_CurveUtil
    local original_Enum
    local original_EllesmereUI
    local original_GameTooltip
    local original_issecretvalue

    local cooldownInfoByID
    local liveOverrideByBaseID
    local cooldownStateBySpellID

    local function replaceExact(source, oldText, newText, label)
        local startIndex = source:find(oldText, 1, true)
        assert.is_truthy(startIndex, "expected exact replacement for " .. label)
        local endIndex = startIndex + #oldText - 1
        return source:sub(1, startIndex - 1) .. newText .. source:sub(endIndex + 1)
    end

    local function loadHooks(ns)
        local handle = assert(io.open(modulePath, "rb"))
        local source = assert(handle:read("*a"))
        handle:close()

        source = source:gsub("^\239\187\191", "")
        source = source:gsub("\r\n", "\n")
        source = replaceExact(
            source,
            "    hookFrameData[frame] = fd\n    return fd\nend\n",
            "    hookFrameData[frame] = fd\n    return fd\nend\nns._DecorateFrame = DecorateFrame\n",
            "DecorateFrame export"
        )

        local chunk, err = loadstring(source, "@" .. modulePath)
        assert.is_nil(err)
        chunk("EllesmereUICooldownManager", ns)
        return ns
    end

    local function buildNamespace()
        local ns = {
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
            spellDataByBar = {},
            _ecmeFC = setmetatable({}, { __mode = "k" }),
            CDM_ITEM_PRESETS = {},
        }

        ns.GetBarSpellData = function(barKey)
            return ns.spellDataByBar[barKey]
        end
        ns.StartNativeGlow = function(overlay, style)
            overlay.glowStyle = style
            overlay.glowStarted = (overlay.glowStarted or 0) + 1
        end
        ns.StopNativeGlow = function(overlay)
            overlay.glowStopped = (overlay.glowStopped or 0) + 1
            overlay.glowStyle = nil
        end
        ns.FC = function(frame)
            ns._fc = ns._fc or setmetatable({}, { __mode = "k" })
            ns._fc[frame] = ns._fc[frame] or {}
            return ns._fc[frame]
        end

        return ns
    end

    local function fireSecureHooks(target, methodName, ...)
        local hooks = target.__secureHooks and target.__secureHooks[methodName]
        if not hooks then return end
        for i = 1, #hooks do
            hooks[i](target, ...)
        end
    end

    local function makeFontString()
        return {
            SetFont = function() end,
            SetShadowOffset = function() end,
            SetPoint = function() end,
            SetJustifyH = function() end,
            SetTextColor = function() end,
            Hide = function(self) self.hidden = true end,
            Show = function(self) self.hidden = false end,
            IsShown = function(self) return not self.hidden end,
            SetText = function(self, text) self.text = text end,
        }
    end

    local function makeTexture()
        return {
            GetTexture = function() return "Interface\\Icons\\Temp" end,
            SetAllPoints = function() end,
            SetColorTexture = function() end,
            SetDesaturation = function(self, value)
                self.desaturated = value
                fireSecureHooks(self, "SetDesaturation", value)
            end,
            SetDesaturated = function(self, value)
                self.desaturated = value
                fireSecureHooks(self, "SetDesaturated", value)
            end,
        }
    end

    local function makeOverlayFrame()
        return {
            SetAllPoints = function() end,
            SetFrameLevel = function() end,
            SetAlpha = function(self, alpha) self.alpha = alpha end,
            EnableMouse = function() end,
            CreateFontString = function()
                return makeFontString()
            end,
        }
    end

    local function makeCooldown()
        return {
            GetRegions = function()
                return nil
            end,
            SetDrawEdge = function() end,
            SetDrawSwipe = function(self, value)
                self.drawSwipe = value
                fireSecureHooks(self, "SetDrawSwipe", value)
            end,
            SetDrawBling = function() end,
            SetSwipeColor = function(self, r, g, b, a)
                self.swipe = { r = r, g = g, b = b, a = a }
                fireSecureHooks(self, "SetSwipeColor", r, g, b, a)
            end,
            SetSwipeTexture = function() end,
            SetReverse = function(self, value) self.reverse = value end,
        }
    end

    local function makeFrame()
        local frame = {
            Icon = makeTexture(),
            Cooldown = makeCooldown(),
            alpha = 1,
        }

        frame.CreateTexture = function()
            return makeTexture()
        end
        frame.GetRegions = function()
            return nil
        end
        frame.GetFrameLevel = function()
            return 10
        end
        frame.GetScale = function()
            return 1
        end
        frame.HookScript = function() end
        frame.SetAlpha = function(self, alpha)
            self.alpha = alpha
        end
        frame.SetPoint = function(self, ...)
            self.lastPoint = { ... }
            fireSecureHooks(self, "SetPoint", ...)
        end
        frame.ClearAllPoints = function() end

        return frame
    end

    before_each(function()
        original_CreateFrame = _G.CreateFrame
        original_hooksecurefunc = _G.hooksecurefunc
        original_C_CooldownViewer = _G.C_CooldownViewer
        original_C_SpellBook = _G.C_SpellBook
        original_C_Spell = _G.C_Spell
        original_C_CurveUtil = _G.C_CurveUtil
        original_Enum = _G.Enum
        original_EllesmereUI = _G.EllesmereUI
        original_GameTooltip = _G.GameTooltip
        original_issecretvalue = _G.issecretvalue

        cooldownInfoByID = {}
        liveOverrideByBaseID = {}
        cooldownStateBySpellID = {}

        _G.CreateFrame = function()
            local frame = makeOverlayFrame()
            frame.RegisterEvent = function() end
            frame.RegisterUnitEvent = function() end
            frame.SetScript = function() end
            frame.Hide = function(self)
                self.hidden = true
            end
            frame.Show = function(self)
                self.hidden = false
            end
            frame.IsShown = function(self)
                return not self.hidden
            end
            return frame
        end
        _G.hooksecurefunc = function(target, methodName, callback)
            target.__secureHooks = target.__secureHooks or {}
            target.__secureHooks[methodName] = target.__secureHooks[methodName] or {}
            table.insert(target.__secureHooks[methodName], callback)
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
        _G.C_Spell = {
            GetSpellCooldown = function(spellID)
                return cooldownStateBySpellID[spellID]
            end,
        }
        _G.C_CurveUtil = nil
        _G.Enum = {
            LuaCurveType = {
                Step = 1,
            },
        }
        _G.EllesmereUI = {
            PP = {
                CreateBorder = function() end,
            },
        }
        _G.GameTooltip = {
            Hide = function() end,
        }
        _G.issecretvalue = function()
            return false
        end
    end)

    after_each(function()
        _G.CreateFrame = original_CreateFrame
        _G.hooksecurefunc = original_hooksecurefunc
        _G.C_CooldownViewer = original_C_CooldownViewer
        _G.C_SpellBook = original_C_SpellBook
        _G.C_Spell = original_C_Spell
        _G.C_CurveUtil = original_C_CurveUtil
        _G.Enum = original_Enum
        _G.EllesmereUI = original_EllesmereUI
        _G.GameTooltip = original_GameTooltip
        _G.issecretvalue = original_issecretvalue
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

    it("restores icon alpha when cdStateEffect switches away from hidden modes", function()
        local ns = loadHooks(buildNamespace())
        local frame = makeFrame()

        ns.barDataByKey.MainBar = { barOpacity = 0.75 }
        ns.spellDataByBar.MainBar = {
            spellSettings = {
                [123] = { cdStateEffect = "hiddenOnCD" },
            },
            assignedSpells = { 123 },
        }
        ns._ecmeFC[frame] = { spellID = 123, barKey = "MainBar" }
        cooldownStateBySpellID[123] = { isActive = true, isOnGCD = false }

        ns._DecorateFrame(frame, ns.barDataByKey.MainBar)
        frame.Icon:SetDesaturated(true)

        assert.are.equal(0, frame.alpha)
        assert.is_true(ns._ecmeFC[frame]._cdStateHidden)

        ns.spellDataByBar.MainBar.spellSettings[123].cdStateEffect = "pixelGlowReady"
        cooldownStateBySpellID[123] = { isActive = false, isOnGCD = false }
        frame.Icon:SetDesaturated(false)

        assert.are.equal(0.75, frame.alpha)
        assert.is_false(ns._ecmeFC[frame]._cdStateHidden)
        assert.are.equal(1, ns._hookFrameData[frame].glowOverlay.glowStyle)
    end)
end)