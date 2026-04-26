describe("Action Bars page and visibility helpers", function()
    local modulePath = "EllesmereUIActionBars/EllesmereUIActionBars.lua"
    local litePath = "EllesmereUI_Lite.lua"
    local original_RegisterAttributeDriver
    local original_RegisterStateDriver
    local original_UnitClass
    local original_GetOverrideBarIndex
    local original_GetVehicleBarIndex
    local original_NUM_ACTIONBAR_PAGES

    local currentClass
    local currentOverrideIndex
    local currentVehicleIndex

    local function replaceExact(source, searchText, replacementText, label)
        local startIndex, endIndex = source:find(searchText, 1, true)
        assert.is_not_nil(startIndex, "failed to instrument " .. label)
        return source:sub(1, startIndex - 1) .. replacementText .. source:sub(endIndex + 1)
    end

    local function loadActionBarsNamespace(ns)
        if not EllesmereUI.Lite then
            local liteChunk, liteErr = loadfile(litePath)
            assert.is_nil(liteErr)
            liteChunk("EllesmereUI", ns)
        end

        local sourceFile = assert(io.open(modulePath, "rb"))
        local actionSource = sourceFile:read("*a")
        sourceFile:close()
        actionSource = actionSource:gsub("^\239\187\191", "")
        actionSource = actionSource:gsub("\r\n", "\n")

        actionSource = replaceExact(
            actionSource,
            "    return conditions\nend\n\n-------------------------------------------------------------------------------\n--  Action Bar 1 Paging Arrows + Page Number",
            "    return conditions\nend\nEAB._GetClassPagingConditions = GetClassPagingConditions\n\n-------------------------------------------------------------------------------\n--  Action Bar 1 Paging Arrows + Page Number",
            "GetClassPagingConditions"
        )

        actionSource = replaceExact(
            actionSource,
            "    return hidePrefix .. \"show\"\nend\n\n-------------------------------------------------------------------------------\n--  Managed Non-Secure Visibility",
            "    return hidePrefix .. \"show\"\nend\nEAB._BuildVisibilityString = BuildVisibilityString\n\n-------------------------------------------------------------------------------\n--  Managed Non-Secure Visibility",
            "BuildVisibilityString"
        )

        local chunk, err = loadstring(actionSource, "@" .. modulePath)
        assert.is_nil(err)
        chunk("EllesmereUIActionBars", ns)
        return ns
    end

    local function buildNamespace()
        return {}
    end

    before_each(function()
        original_RegisterAttributeDriver = _G.RegisterAttributeDriver
        original_RegisterStateDriver = _G.RegisterStateDriver
        original_UnitClass = _G.UnitClass
        original_GetOverrideBarIndex = _G.GetOverrideBarIndex
        original_GetVehicleBarIndex = _G.GetVehicleBarIndex
        original_NUM_ACTIONBAR_PAGES = _G.NUM_ACTIONBAR_PAGES

        currentClass = "DRUID"
        currentOverrideIndex = 14
        currentVehicleIndex = 15

        _G.RegisterAttributeDriver = function() end
        _G.RegisterStateDriver = function() end
        _G.UnitClass = function()
            return currentClass, currentClass
        end
        _G.GetOverrideBarIndex = function()
            return currentOverrideIndex
        end
        _G.GetVehicleBarIndex = function()
            return currentVehicleIndex
        end
        _G.NUM_ACTIONBAR_PAGES = 6
    end)

    after_each(function()
        _G.RegisterAttributeDriver = original_RegisterAttributeDriver
        _G.RegisterStateDriver = original_RegisterStateDriver
        _G.UnitClass = original_UnitClass
        _G.GetOverrideBarIndex = original_GetOverrideBarIndex
        _G.GetVehicleBarIndex = original_GetVehicleBarIndex
        _G.NUM_ACTIONBAR_PAGES = original_NUM_ACTIONBAR_PAGES
    end)

    it("builds druid paging conditions with override, vehicle, stance, and manual pages", function()
        local ns = loadActionBarsNamespace(buildNamespace())

        local conditions = ns.EAB._GetClassPagingConditions()

        assert.are.equal(
            "[overridebar] 14; [vehicleui][possessbar] 15; [bonusbar:1,stealth] 7; [bonusbar:1] 7; [bonusbar:3] 9; [bonusbar:4] 10; [bonusbar:5] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1",
            conditions
        )
    end)

    it("builds rogue paging conditions without druid-only stance clauses", function()
        currentClass = "ROGUE"
        local ns = loadActionBarsNamespace(buildNamespace())

        local conditions = ns.EAB._GetClassPagingConditions()

        assert.is_truthy(conditions:find("%[bonusbar:1%] 7;", 1, false))
        assert.is_nil(conditions:find("stealth", 1, true))
        assert.is_nil(conditions:find("%[bonusbar:3%] 9;", 1, false))
        assert.is_truthy(conditions:find("%[bar:6%] 6; 1$"))
    end)

    it("builds pet bar visibility strings with pet, vehicle, and mode guards", function()
        local ns = loadActionBarsNamespace(buildNamespace())

        local visibility = ns.EAB._BuildVisibilityString({ key = "PetBar", isPetBar = true }, {
            barVisibility = "in_combat",
            visHideMounted = true,
        })

        assert.are.equal(
            "[petbattle] hide; [mounted] hide; [novehicleui,pet,nooverridebar,nopossessbar] [combat] show; hide; hide",
            visibility
        )
    end)

    it("builds non-main bar visibility strings with standard hide prefixes and visibility options", function()
        local ns = loadActionBarsNamespace(buildNamespace())

        local visibility = ns.EAB._BuildVisibilityString({ key = "Bar2" }, {
            barVisibility = "solo",
            visHideNoTarget = true,
            visHideNoEnemy = true,
        })

        assert.are.equal(
            "[vehicleui][petbattle][overridebar] hide; [noexists] hide; [noharm] hide; [nogroup] show; hide",
            visibility
        )
    end)
end)