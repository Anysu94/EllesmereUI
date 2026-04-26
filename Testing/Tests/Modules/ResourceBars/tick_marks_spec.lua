describe("Resource Bars tick mark helpers", function()
    local modulePath = "EllesmereUIResourceBars/EllesmereUIResourceBars.lua"

    local original_EllesmereUI
    local original_UnitClass
    local original_GetSpecialization
    local original_GetShapeshiftFormID
    local original_UnitPowerMax
    local original_UnitHealthMax
    local original_C_SpecializationInfo
    local original_CreateColor
    local original_issecretvalue
    local original__ERB_ParseTickValues
    local original__ERB_ApplyResourceBarTicks

    local function loadModule()
        local function replaceExact(source, searchText, replacementText, label)
            local startIndex, endIndex = source:find(searchText, 1, true)
            assert.is_not_nil(startIndex, "failed to instrument " .. label)
            return source:sub(1, startIndex - 1) .. replacementText .. source:sub(endIndex + 1)
        end

        local ns = {}
        local file = assert(io.open(modulePath, "rb"))
        local source = file:read("*a")
        file:close()
        source = source:gsub("^\239\187\191", "")
        source = source:gsub("\r\n", "\n")
        source = replaceExact(
            source,
            "    _G._ERB_Apply = function() ERB:ApplyAll() end\n    _G._ERB_GetSecondaryResource = GetSecondaryResource",
            "    _G._ERB_Apply = function() ERB:ApplyAll() end\n    _G._ERB_ParseTickValues = ParseTickValues\n    _G._ERB_ApplyResourceBarTicks = ApplyResourceBarTicks\n    _G._ERB_GetSecondaryResource = GetSecondaryResource",
            "ResourceBars helpers"
        )
        local chunk, err = loadstring(source, "@" .. modulePath)
        assert.is_nil(err)
        chunk("EllesmereUIResourceBars", ns)
        ns.ERB:OnInitialize()
        return ns.ERB
    end

    local function makeTexture(label)
        return {
            label = label,
            shown = false,
            hidden = false,
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
        original_EllesmereUI = _G.EllesmereUI
        original_UnitClass = _G.UnitClass
        original_GetSpecialization = _G.GetSpecialization
        original_GetShapeshiftFormID = _G.GetShapeshiftFormID
        original_UnitPowerMax = _G.UnitPowerMax
        original_UnitHealthMax = _G.UnitHealthMax
        original_C_SpecializationInfo = _G.C_SpecializationInfo
        original_CreateColor = _G.CreateColor
        original_issecretvalue = _G.issecretvalue
        original__ERB_ParseTickValues = _G._ERB_ParseTickValues
        original__ERB_ApplyResourceBarTicks = _G._ERB_ApplyResourceBarTicks

        _G.EllesmereUI = {
            Lite = {
                NewAddon = function()
                    return {}
                end,
                NewDB = function()
                    return {
                        profile = {},
                    }
                end,
            },
            PP = {
                perfect = 1,
                Scale = function(value)
                    return value
                end,
            },
            RESOURCE_BAR_ANCHOR_KEYS = {},
            GetClassColor = function()
                return { r = 0.2, g = 0.4, b = 0.6 }
            end,
            GetPowerColor = function()
                return nil
            end,
        }

        _G.UnitClass = function()
            return "Player", "HUNTER"
        end
        _G.GetSpecialization = function()
            return 1
        end
        _G.GetShapeshiftFormID = function()
            return nil
        end
        _G.UnitPowerMax = function()
            return 0
        end
        _G.UnitHealthMax = function()
            return 250000
        end
        _G.C_SpecializationInfo = {
            GetSpecializationInfo = function(spec)
                return spec
            end,
        }
        _G.CreateColor = function(r, g, b, a)
            return {
                r = r,
                g = g,
                b = b,
                a = a,
                GetRGBA = function(self)
                    return self.r, self.g, self.b, self.a
                end,
            }
        end
        _G.issecretvalue = function()
            return false
        end
    end)

    after_each(function()
        _G.EllesmereUI = original_EllesmereUI
        _G.UnitClass = original_UnitClass
        _G.GetSpecialization = original_GetSpecialization
        _G.GetShapeshiftFormID = original_GetShapeshiftFormID
        _G.UnitPowerMax = original_UnitPowerMax
        _G.UnitHealthMax = original_UnitHealthMax
        _G.C_SpecializationInfo = original_C_SpecializationInfo
        _G.CreateColor = original_CreateColor
        _G.issecretvalue = original_issecretvalue
        _G._ERB_ParseTickValues = original__ERB_ParseTickValues
        _G._ERB_ApplyResourceBarTicks = original__ERB_ApplyResourceBarTicks
    end)

    it("parses comma-separated tick strings into positive numeric values", function()
        loadModule()

        assert.same({ 5, 10, 25 }, _G._ERB_ParseTickValues(" 5, 0, bad, 10 , -3, 25 "))
        assert.is_nil(_G._ERB_ParseTickValues("0, bad, -1"))
        assert.is_nil(_G._ERB_ParseTickValues(""))
    end)

    it("creates and places tick textures only for valid marks within the max value", function()
        loadModule()
        local statusBar = makeStatusBar(120, 8)
        local existingTexture = makeTexture("existing")
        local tickCache = { existingTexture }

        _G._ERB_ApplyResourceBarTicks(statusBar, 20, " 5, 10, 40 ", tickCache)

        assert.are.equal(1, existingTexture.hideCalls)
        assert.are.equal(3, #tickCache)

        assert.is_true(tickCache[1].shown)
        assert.same({ 1, 8 }, tickCache[1].size)
        assert.same({ "TOPLEFT", statusBar, "TOPLEFT", 30, 0 }, tickCache[1].point)

        assert.is_true(tickCache[2].shown)
        assert.same({ "TOPLEFT", statusBar, "TOPLEFT", 60, 0 }, tickCache[2].point)

        assert.is_false(tickCache[3].shown)
        assert.is_nil(tickCache[3].point)
    end)

    it("hides cached ticks and exits when the tick string does not yield usable marks", function()
        loadModule()
        local statusBar, createdTextures = makeStatusBar(90, 6)
        local first = makeTexture("first")
        local second = makeTexture("second")
        local tickCache = { first, second }

        _G._ERB_ApplyResourceBarTicks(statusBar, 20, "0, nope, -5", tickCache)

        assert.are.equal(1, first.hideCalls)
        assert.are.equal(1, second.hideCalls)
        assert.are.equal(0, #createdTextures)
        assert.is_false(first.shown)
        assert.is_false(second.shown)
    end)
end)