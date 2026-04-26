-- Mythic+ Timer pure-logic helper tests.
-- Tests FormatTime, CalculateBonusTimers, NormalizeAffixKey, GetScopeKey,
-- RoundToInt, GetTimerBarFillColor, BuildSplitCompareText, FormatEnemyForcesText.

describe("Mythic Timer pure helpers", function()
    local modulePath = "EllesmereUIMythicTimer/EllesmereUIMythicTimer.lua"

    local original_EllesmereUI
    local original_issecretvalue
    local original_C_ScenarioInfo
    local original_GetWorldElapsedTime
    local original_GetTimePreciseSec
    local original_C_ChallengeMode
    local original_C_MythicPlus
    local original_C_Scenario
    local original_ITEM_QUALITY_COLORS

    local FormatTime, CalculateBonusTimers, NormalizeAffixKey, GetScopeKey
    local RoundToInt, GetTimerBarFillColor, BuildSplitCompareText
    local FormatEnemyForcesText

    local function replaceExact(source, oldText, newText, label)
        local startIndex = source:find(oldText, 1, true)
        assert.is_truthy(startIndex, "expected exact replacement for " .. label)
        local endIndex = startIndex + #oldText - 1
        return source:sub(1, startIndex - 1) .. newText .. source:sub(endIndex + 1)
    end

    local function loadModule()
        local handle = assert(io.open(modulePath, "rb"))
        local source = assert(handle:read("*a"))
        handle:close()
        source = source:gsub("^\239\187\191", "")
        source = source:gsub("\r\n", "\n")

        -- Export FormatTime
        source = replaceExact(
            source,
            "    return format(\"%02d:%02d\", m, s)\nend\n\nlocal function RoundToInt",
            "    return format(\"%02d:%02d\", m, s)\nend\nns._FormatTime = FormatTime\n\nlocal function RoundToInt",
            "FormatTime export"
        )

        -- Export RoundToInt
        source = replaceExact(
            source,
            "    return floor(value + 0.5)\nend\n\nlocal function GetColor",
            "    return floor(value + 0.5)\nend\nns._RoundToInt = RoundToInt\n\nlocal function GetColor",
            "RoundToInt export"
        )

        -- Export GetTimerBarFillColor
        source = replaceExact(
            source,
            "    return GetColor(profile and profile.timerPlusThreeColor, 0.4, 1, 0.4)\nend\n\nlocal function NormalizeAffixKey",
            "    return GetColor(profile and profile.timerPlusThreeColor, 0.4, 1, 0.4)\nend\nns._GetTimerBarFillColor = GetTimerBarFillColor\n\nlocal function NormalizeAffixKey",
            "GetTimerBarFillColor export"
        )

        -- Export NormalizeAffixKey
        source = replaceExact(
            source,
            "    return table.concat(ids, \"-\")\nend\n\nlocal function GetScopeKey",
            "    return table.concat(ids, \"-\")\nend\nns._NormalizeAffixKey = NormalizeAffixKey\n\nlocal function GetScopeKey",
            "NormalizeAffixKey export"
        )

        -- Export GetScopeKey
        source = replaceExact(
            source,
            "    return nil\nend\n\nlocal function EnsureProfileStore",
            "    return nil\nend\nns._GetScopeKey = GetScopeKey\n\nlocal function EnsureProfileStore",
            "GetScopeKey export"
        )

        -- Export BuildSplitCompareText
        source = replaceExact(
            source,
            "    return format(\"  |cff888888(%s, %s%s%s)|r\", FormatTime(referenceTime), colorHex, diffPrefix, diffText)\nend\n\nlocal function FormatEnemyForcesText",
            "    return format(\"  |cff888888(%s, %s%s%s)|r\", FormatTime(referenceTime), colorHex, diffPrefix, diffText)\nend\nns._BuildSplitCompareText = BuildSplitCompareText\n\nlocal function FormatEnemyForcesText",
            "BuildSplitCompareText export"
        )

        -- Export FormatEnemyForcesText
        source = replaceExact(
            source,
            "    return format(\"%.2f%%%s\", percent, suffix)\nend\n\n-- Objective tracking",
            "    return format(\"%.2f%%%s\", percent, suffix)\nend\nns._FormatEnemyForcesText = FormatEnemyForcesText\n\n-- Objective tracking",
            "FormatEnemyForcesText export"
        )

        -- Export CalculateBonusTimers
        source = replaceExact(
            source,
            "    return plusTwoT, plusThreeT\nend\n\n-- Database defaults",
            "    return plusTwoT, plusThreeT\nend\nns._CalculateBonusTimers = CalculateBonusTimers\n\n-- Database defaults",
            "CalculateBonusTimers export"
        )

        local ns = {}
        -- stub Lite loader
        if not _G.EllesmereUI then _G.EllesmereUI = {} end
        if not _G.EllesmereUI.Lite then
            _G.EllesmereUI.Lite = {
                NewAddon = function(_, name)
                    local addon = { OnEnable = function() end }
                    setmetatable(addon, { __index = function(_, k)
                        if k == "RegisterEvent" or k == "UnregisterEvent" then
                            return function() end
                        end
                    end })
                    return addon
                end,
                NewDB = function(_, name, defaults)
                    return { profile = defaults and defaults.profile or {} }
                end,
            }
        end
        if not _G.EllesmereUI.Lite.NewAddon then
            _G.EllesmereUI.Lite.NewAddon = function(name)
                return { OnEnable = function() end }
            end
        end

        local chunk, err = loadstring(source, "@" .. modulePath)
        assert.is_nil(err, "loadstring error: " .. tostring(err))
        -- many functions use global APIs – stub them
        local ok2, loadErr = pcall(chunk, "EllesmereUIMythicTimer", ns)
        -- may fail later, but ns should have our exports
        return ns
    end

    before_each(function()
        original_EllesmereUI = _G.EllesmereUI
        original_issecretvalue = _G.issecretvalue
        original_C_ScenarioInfo = _G.C_ScenarioInfo
        original_GetWorldElapsedTime = _G.GetWorldElapsedTime
        original_GetTimePreciseSec = _G.GetTimePreciseSec
        original_C_ChallengeMode = _G.C_ChallengeMode
        original_C_MythicPlus = _G.C_MythicPlus
        original_C_Scenario = _G.C_Scenario
        original_ITEM_QUALITY_COLORS = _G.ITEM_QUALITY_COLORS

        _G.issecretvalue = function() return false end
        _G.GetWorldElapsedTime = function() return 0, 0 end
        _G.GetTimePreciseSec = function() return 0 end
        _G.C_ScenarioInfo = { GetCriteriaInfo = function() return nil end }
        _G.C_ChallengeMode = {
            GetMapUIInfo = function() return 0, "" end,
            GetActiveKeystoneInfo = function() return 0, {} end,
            GetActiveChallengeMapID = function() return nil end,
            GetDeathCount = function() return 0, 0 end,
        }
        _G.C_MythicPlus = {
            GetCurrentAffixes = function() return {} end,
        }
        _G.C_Scenario = {
            GetStepInfo = function() return "", "", 0 end,
        }
        _G.ITEM_QUALITY_COLORS = {
            [0] = { hex = "|cff9d9d9d" },
            [1] = { hex = "|cffffffff" },
            [2] = { hex = "|cff1eff00" },
            [3] = { hex = "|cff0070dd" },
            [4] = { hex = "|cffa335ee" },
        }

        _G.EllesmereUI = {
            Lite = {
                NewAddon = function(name)
                    local a = {}
                    function a:RegisterEvent() end
                    function a:UnregisterEvent() end
                    function a:OnEnable() end
                    return a
                end,
                NewDB = function(name, defs)
                    return { profile = defs and defs.profile or {} }
                end,
            },
            GetFontPath = function() return "Fonts\\FRIZQT__.TTF" end,
            PP = {
                CreateBorder = function() end,
                SetBorderColor = function() end,
            },
            ELLESMERE_GREEN = { r = 0, g = 0.8, b = 0.5 },
        }

        local ns = loadModule()
        FormatTime = ns._FormatTime
        CalculateBonusTimers = ns._CalculateBonusTimers
        NormalizeAffixKey = ns._NormalizeAffixKey
        GetScopeKey = ns._GetScopeKey
        RoundToInt = ns._RoundToInt
        GetTimerBarFillColor = ns._GetTimerBarFillColor
        BuildSplitCompareText = ns._BuildSplitCompareText
        FormatEnemyForcesText = ns._FormatEnemyForcesText
    end)

    after_each(function()
        _G.EllesmereUI = original_EllesmereUI
        _G.issecretvalue = original_issecretvalue
        _G.C_ScenarioInfo = original_C_ScenarioInfo
        _G.GetWorldElapsedTime = original_GetWorldElapsedTime
        _G.GetTimePreciseSec = original_GetTimePreciseSec
        _G.C_ChallengeMode = original_C_ChallengeMode
        _G.C_MythicPlus = original_C_MythicPlus
        _G.C_Scenario = original_C_Scenario
        _G.ITEM_QUALITY_COLORS = original_ITEM_QUALITY_COLORS
    end)

    -- FormatTime -----------------------------------------------------------
    describe("FormatTime", function()
        it("formats whole seconds to MM:SS", function()
            assert.equals("01:30", FormatTime(90))
        end)

        it("formats zero", function()
            assert.equals("00:00", FormatTime(0))
        end)

        it("handles nil gracefully (treated as 0)", function()
            assert.equals("00:00", FormatTime(nil))
        end)

        it("handles negative (clamped to 0)", function()
            assert.equals("00:00", FormatTime(-5))
        end)

        it("formats with milliseconds", function()
            assert.equals("01:30.500", FormatTime(90.5, true))
        end)

        it("rounds milliseconds past 999 into next second", function()
            -- 90.9997 -> ms = floor((0.9997 * 1000) + 0.5) = 1000 -> should bump
            assert.equals("01:31.000", FormatTime(90.9997, true))
        end)

        it("formats large times correctly", function()
            assert.equals("60:00", FormatTime(3600))
        end)

        it("formats sub-second with milliseconds", function()
            assert.equals("00:00.250", FormatTime(0.25, true))
        end)
    end)

    -- RoundToInt ------------------------------------------------------------
    describe("RoundToInt", function()
        it("rounds 2.3 to 2", function()
            assert.equals(2, RoundToInt(2.3))
        end)

        it("rounds 2.5 to 3", function()
            assert.equals(3, RoundToInt(2.5))
        end)

        it("returns 0 for nil", function()
            assert.equals(0, RoundToInt(nil))
        end)
    end)

    -- CalculateBonusTimers --------------------------------------------------
    describe("CalculateBonusTimers", function()
        it("computes +2 and +3 thresholds from max time", function()
            local p2, p3 = CalculateBonusTimers(1800, {})
            assert.equals(1440, p2)   -- 1800 * 0.8
            assert.equals(1080, p3)   -- 1800 * 0.6
        end)

        it("returns zeros for nil maxTime", function()
            local p2, p3 = CalculateBonusTimers(nil, {})
            assert.equals(0, p2)
            assert.equals(0, p3)
        end)

        it("returns zeros for zero maxTime", function()
            local p2, p3 = CalculateBonusTimers(0, {})
            assert.equals(0, p2)
            assert.equals(0, p3)
        end)

        it("adjusts for Challenger's Peril affix (ID 152)", function()
            local p2, p3 = CalculateBonusTimers(1800, { 10, 152, 124 })
            -- oldTimer = 1800 - 90 = 1710
            -- plusTwo  = 1710 * 0.8 + 90 = 1458
            -- plusThree = 1710 * 0.6 + 90 = 1116
            assert.equals(1458, p2)
            assert.equals(1116, p3)
        end)

        it("ignores Challenger's Peril when timer too short", function()
            -- maxTime=50, oldTimer = 50-90 = -40, <= 0, so no adjustment
            local p2, p3 = CalculateBonusTimers(50, { 152 })
            assert.equals(40, p2)   -- 50 * 0.8
            assert.equals(30, p3)   -- 50 * 0.6
        end)

        it("handles nil affixes", function()
            local p2, p3 = CalculateBonusTimers(600, nil)
            assert.equals(480, p2)
            assert.equals(360, p3)
        end)
    end)

    -- NormalizeAffixKey -----------------------------------------------------
    describe("NormalizeAffixKey", function()
        it("sorts and joins affix IDs", function()
            assert.equals("10-124-152", NormalizeAffixKey({ 152, 10, 124 }))
        end)

        it("handles single affix", function()
            assert.equals("10", NormalizeAffixKey({ 10 }))
        end)

        it("handles empty table", function()
            assert.equals("", NormalizeAffixKey({}))
        end)

        it("handles nil", function()
            assert.equals("", NormalizeAffixKey(nil))
        end)
    end)

    -- GetScopeKey -----------------------------------------------------------
    describe("GetScopeKey", function()
        it("returns mapID for DUNGEON mode", function()
            local run = { mapID = 375, level = 15, affixes = { 10, 124 } }
            assert.equals("375", GetScopeKey(run, "DUNGEON"))
        end)

        it("returns mapID:level for LEVEL mode", function()
            local run = { mapID = 375, level = 15, affixes = { 10, 124 } }
            assert.equals("375:15", GetScopeKey(run, "LEVEL"))
        end)

        it("returns mapID:level:affixes for LEVEL_AFFIX mode", function()
            local run = { mapID = 375, level = 15, affixes = { 124, 10 } }
            assert.equals("375:15:10-124", GetScopeKey(run, "LEVEL_AFFIX"))
        end)

        it("returns nil for nil run", function()
            assert.is_nil(GetScopeKey(nil, "DUNGEON"))
        end)

        it("returns nil for unknown mode", function()
            local run = { mapID = 375, level = 15 }
            assert.is_nil(GetScopeKey(run, "NONE"))
        end)

        it("defaults missing level to 0", function()
            local run = { mapID = 375, affixes = {} }
            assert.equals("375:0", GetScopeKey(run, "LEVEL"))
        end)
    end)

    -- GetTimerBarFillColor --------------------------------------------------
    describe("GetTimerBarFillColor", function()
        it("returns purple when +2 lost", function()
            local r, g, b = GetTimerBarFillColor(nil, 1500, 1080, 1440, 1800)
            assert.is_near(0xB0 / 255, r, 0.001)
            assert.is_near(0x59 / 255, g, 0.001)
            assert.is_near(0xCC / 255, b, 0.001)
        end)

        it("returns +2 color when +3 lost but +2 alive", function()
            -- elapsed=1200 > plusThree=1080, but < plusTwo=1440
            local profile = { timerPlusTwoColor = { r = 0.3, g = 0.8, b = 1 } }
            local r, g, b = GetTimerBarFillColor(profile, 1200, 1080, 1440, 1800)
            assert.equals(0.3, r)
            assert.equals(0.8, g)
            assert.equals(1, b)
        end)

        it("returns +3 color when all timers alive", function()
            local profile = { timerPlusThreeColor = { r = 0.4, g = 1, b = 0.4 } }
            local r, g, b = GetTimerBarFillColor(profile, 500, 1080, 1440, 1800)
            assert.equals(0.4, r)
            assert.equals(1, g)
            assert.equals(0.4, b)
        end)

        it("uses defaults when profile is nil", function()
            local r, g, b = GetTimerBarFillColor(nil, 500, 1080, 1440, 1800)
            assert.equals(0.4, r)
            assert.equals(1, g)
            assert.equals(0.4, b)
        end)

        it("returns +3 color when maxTime is nil or 0", function()
            local r, g, b = GetTimerBarFillColor(nil, 500, 0, 0, nil)
            assert.equals(0.4, r)
        end)
    end)

    -- BuildSplitCompareText ------------------------------------------------
    describe("BuildSplitCompareText", function()
        it("returns empty string when reference is nil", function()
            assert.equals("", BuildSplitCompareText(nil, 100, false, nil, nil))
        end)

        it("returns empty string when current is nil", function()
            assert.equals("", BuildSplitCompareText(100, nil, false, nil, nil))
        end)

        it("includes delta prefix for slower split", function()
            local text = BuildSplitCompareText(60, 75, true, { r = 0.4, g = 1, b = 0.4 }, { r = 1, g = 0.45, b = 0.45 })
            assert.truthy(text:find("%+"), "should contain + for slower")
            assert.truthy(text:find("00:15"), "should show 15 second delta")
        end)

        it("includes delta prefix for faster split", function()
            local text = BuildSplitCompareText(75, 60, true, { r = 0.4, g = 1, b = 0.4 }, { r = 1, g = 0.45, b = 0.45 })
            assert.truthy(text:find("%-"), "should contain - for faster")
            assert.truthy(text:find("00:15"), "should show 15 second delta")
        end)

        it("shows reference time in non-deltaOnly mode", function()
            local text = BuildSplitCompareText(120, 130, false, { r = 0.4, g = 1, b = 0.4 }, { r = 1, g = 0.45, b = 0.45 })
            assert.truthy(text:find("02:00"), "should contain reference time")
            assert.truthy(text:find("00:10"), "should contain delta")
        end)

        it("handles exact same times", function()
            local text = BuildSplitCompareText(60, 60, true, { r = 0.4, g = 1, b = 0.4 }, { r = 1, g = 0.45, b = 0.45 })
            -- diff=0, prefix is "+", diffText should be "0:00" per the code
            assert.truthy(text:find("%+"), "should use + prefix for zero diff")
        end)
    end)

    -- FormatEnemyForcesText ------------------------------------------------
    describe("FormatEnemyForcesText", function()
        local enemy
        before_each(function()
            enemy = {
                rawQuantity = 150,
                rawTotalQuantity = 300,
                percent = 50.00,
            }
        end)

        it("formats PERCENT", function()
            local text = FormatEnemyForcesText(enemy, "PERCENT", false)
            assert.equals("50.00% Enemy Forces", text)
        end)

        it("formats PERCENT compact", function()
            local text = FormatEnemyForcesText(enemy, "PERCENT", true)
            assert.equals("50.00%", text)
        end)

        it("formats COUNT", function()
            local text = FormatEnemyForcesText(enemy, "COUNT", false)
            assert.equals("150/300 Enemy Forces", text)
        end)

        it("formats COUNT compact", function()
            local text = FormatEnemyForcesText(enemy, "COUNT", true)
            assert.equals("150/300", text)
        end)

        it("formats COUNT_PERCENT", function()
            local text = FormatEnemyForcesText(enemy, "COUNT_PERCENT", false)
            assert.equals("150/300 - 50.00% Enemy Forces", text)
        end)

        it("formats REMAINING", function()
            local text = FormatEnemyForcesText(enemy, "REMAINING", false)
            assert.equals("150 remaining Enemy Forces", text)
        end)

        it("formats REMAINING compact", function()
            local text = FormatEnemyForcesText(enemy, "REMAINING", true)
            assert.equals("150 left", text)
        end)

        it("falls back to PERCENT for unknown format", function()
            local text = FormatEnemyForcesText(enemy, "UNKNOWN_FORMAT", false)
            assert.equals("50.00% Enemy Forces", text)
        end)

        it("handles zero quantities", function()
            enemy.rawQuantity = 0
            enemy.rawTotalQuantity = 0
            enemy.percent = 0
            local text = FormatEnemyForcesText(enemy, "REMAINING", false)
            assert.equals("0 remaining Enemy Forces", text)
        end)
    end)
end)
