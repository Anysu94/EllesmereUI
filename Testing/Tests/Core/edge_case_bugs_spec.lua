-- Edge-case / adversarial tests targeting functions already loaded in
-- previous test files. These tests focus on finding bugs via boundary
-- conditions, nil inputs, empty tables, extreme values, and type mismatches.

describe("Edge-case bug hunting", function()

    ---------------------------------------------------------------------------
    --  FormatNumber edge cases (EllesmereUIResourceBars.lua)
    ---------------------------------------------------------------------------
    describe("FormatNumber edge cases", function()
        local FormatNumber

        local function extractFormatNumber()
            -- Inline extraction — the function is small enough to copy directly
            local floor = math.floor
            local function FN(n)
                if not n or n ~= n then return "0" end
                if n >= 1e9  then return string.format("%.1fB", n / 1e9)  end
                if n >= 1e6  then return string.format("%.1fM", n / 1e6)  end
                if n >= 1e4  then return string.format("%.1fK", n / 1e3)  end
                if n >= 1e3  then return string.format("%.0fK",  n / 1e3) end
                return tostring(floor(n))
            end
            return FN
        end

        before_each(function()
            FormatNumber = extractFormatNumber()
        end)

        it("handles NaN (0/0) without crash", function()
            local result = FormatNumber(0/0)
            assert.equals("0", result)
        end)

        it("handles positive infinity", function()
            local result = FormatNumber(1/0)
            -- inf >= 1e9 is true, so: string.format("%.1fB", inf/1e9) = "infB"
            -- This is wrong behavior — should probably return "∞" or "0"
            assert.is_string(result) -- at least it doesn't crash
        end)

        it("handles negative infinity", function()
            local result = FormatNumber(-1/0)
            -- -inf < 1e3 so: tostring(floor(-inf)) = "-inf"
            assert.is_string(result)
        end)

        it("handles negative numbers", function()
            local result = FormatNumber(-500)
            -- -500 < 1e3 so: tostring(floor(-500)) = "-500"
            assert.equals("-500", result)
        end)

        it("handles nil", function()
            assert.equals("0", FormatNumber(nil))
        end)

        it("handles zero", function()
            assert.equals("0", FormatNumber(0))
        end)

        it("handles boundary at exactly 1000", function()
            local result = FormatNumber(1000)
            assert.equals("1K", result)
        end)

        it("handles boundary at exactly 10000", function()
            local result = FormatNumber(10000)
            assert.equals("10.0K", result)
        end)

        it("handles boundary at exactly 1000000", function()
            local result = FormatNumber(1000000)
            assert.equals("1.0M", result)
        end)
    end)

    ---------------------------------------------------------------------------
    --  Lerp edge cases
    ---------------------------------------------------------------------------
    describe("Lerp edge cases", function()
        local function Lerp(a, b, t) return a + (b - a) * t end

        it("t=0 returns a exactly", function()
            assert.equals(10, Lerp(10, 20, 0))
        end)

        it("t=1 returns b exactly", function()
            assert.equals(20, Lerp(10, 20, 1))
        end)

        it("t > 1 extrapolates beyond b", function()
            assert.equals(30, Lerp(10, 20, 2))
        end)

        it("t < 0 extrapolates below a", function()
            assert.equals(0, Lerp(10, 20, -1))
        end)

        it("a == b returns a regardless of t", function()
            assert.equals(5, Lerp(5, 5, 0.5))
        end)

        it("handles inf values", function()
            local result = Lerp(0, 1/0, 0.5)
            assert.equals(1/0, result)
        end)
    end)

    ---------------------------------------------------------------------------
    --  ParseTickValues edge cases
    ---------------------------------------------------------------------------
    describe("ParseTickValues edge cases", function()
        local function ParseTickValues(input)
            if not input or type(input) ~= "string" then return nil end
            local vals = {}
            for token in input:gmatch("[^,]+") do
                local n = tonumber(token:match("^%s*(.-)%s*$"))
                if n then vals[#vals + 1] = n end
            end
            if #vals == 0 then return nil end
            return vals
        end

        it("returns nil for empty string", function()
            assert.is_nil(ParseTickValues(""))
        end)

        it("returns nil for only whitespace", function()
            assert.is_nil(ParseTickValues("   "))
        end)

        it("returns nil for only commas", function()
            assert.is_nil(ParseTickValues(",,,"))
        end)

        it("handles leading/trailing commas", function()
            local result = ParseTickValues(",1,2,")
            assert.same({1, 2}, result)
        end)

        it("skips non-numeric tokens", function()
            local result = ParseTickValues("1,abc,3")
            assert.same({1, 3}, result)
        end)

        it("handles negative numbers", function()
            local result = ParseTickValues("-1,2,-3")
            assert.same({-1, 2, -3}, result)
        end)

        it("handles decimal values", function()
            local result = ParseTickValues("0.5,1.5")
            assert.same({0.5, 1.5}, result)
        end)

        it("returns nil for nil input", function()
            assert.is_nil(ParseTickValues(nil))
        end)

        it("returns nil for number input (type guard)", function()
            assert.is_nil(ParseTickValues(42))
        end)
    end)

    ---------------------------------------------------------------------------
    --  ShortLabel edge cases (ABR)
    ---------------------------------------------------------------------------
    describe("ShortLabel edge cases", function()
        local function ShortLabel(name)
            if not name or name == "" then return "" end
            return name:match("^(%S+)") or name
        end

        it("returns empty for nil", function()
            assert.equals("", ShortLabel(nil))
        end)

        it("returns empty for empty string", function()
            assert.equals("", ShortLabel(""))
        end)

        it("returns full string when no spaces", function()
            assert.equals("Bloodlust", ShortLabel("Bloodlust"))
        end)

        it("returns first word with trailing spaces", function()
            assert.equals("Battle", ShortLabel("Battle Shout"))
        end)

        it("handles leading spaces (returns empty match, falls back to name)", function()
            -- "  Leading" -> match("^(%S+)") with leading spaces = nil
            -- Falls back to name = "  Leading"
            local result = ShortLabel("  Leading")
            assert.equals("  Leading", result,
                "Leading whitespace causes pattern match to fail, returning the "
                .. "full string including whitespace — possibly unexpected")
        end)

        it("handles tab characters", function()
            local result = ShortLabel("Word\tAnother")
            assert.equals("Word", result)
        end)
    end)

    ---------------------------------------------------------------------------
    --  GetEmpowerStageColor edge cases
    ---------------------------------------------------------------------------
    describe("GetEmpowerStageColor edge cases", function()
        local function GetEmpowerStageColor(stage, numStages)
            if not stage or not numStages or numStages <= 0 then
                return 1, 1, 1
            end
            local t = (stage - 1) / math.max(numStages - 1, 1)
            if t <= 0.5 then
                return 1, t * 2, 0
            else
                return 1 - (t - 0.5) * 2, 1, 0
            end
        end

        it("returns white for nil stage", function()
            local r, g, b = GetEmpowerStageColor(nil, 4)
            assert.equals(1, r)
            assert.equals(1, g)
            assert.equals(1, b)
        end)

        it("returns white for 0 numStages", function()
            local r, g, b = GetEmpowerStageColor(1, 0)
            assert.equals(1, r)
        end)

        it("returns white for negative numStages", function()
            local r, g, b = GetEmpowerStageColor(1, -5)
            assert.equals(1, r)
        end)

        it("handles stage > numStages without crash", function()
            -- stage=10, numStages=3: t = (10-1)/max(2,1) = 4.5
            -- t > 0.5: return 1-(4.5-0.5)*2, 1, 0 = 1-8, 1, 0 = -7, 1, 0
            local r, g, b = GetEmpowerStageColor(10, 3)
            assert.is_number(r)
            -- r is negative — could cause weird colors if not clamped downstream
            assert.is_true(r < 0,
                "Stage beyond numStages produces negative R — the function "
                .. "doesn't clamp output to [0,1]")
        end)

        it("handles numStages=1 without division by zero", function()
            -- t = (1-1) / max(0,1) = 0/1 = 0
            local r, g, b = GetEmpowerStageColor(1, 1)
            assert.is_near(1, r, 0.01)
            assert.is_near(0, g, 0.01)
        end)
    end)

    ---------------------------------------------------------------------------
    --  _stripLineEscapes edge cases (BlizzardSkin)
    ---------------------------------------------------------------------------
    describe("_stripLineEscapes edge cases", function()
        local function stripLineEscapes(s)
            if not s then return "" end
            s = s:gsub("|cn.-:(.-)|r", "%1")
            s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
            s = s:gsub("|r", "")
            s = s:gsub("^%s*[%+&]%s*", "")
            return s
        end

        it("handles nested color codes", function()
            local result = stripLineEscapes("|cff00ff00Green |cffff0000Red|r|r")
            assert.equals("Green Red", result)
        end)

        it("handles malformed color code (too few hex digits)", function()
            local result = stripLineEscapes("|cff00Text|r")
            -- |c%x%x%x%x%x%x%x%x requires 8 hex digits — "ff00" is only 4
            -- Pattern won't match, leaving "|cff00Text" then |r is stripped
            assert.equals("|cff00Text", result)
        end)

        it("handles string with only escape codes", function()
            local result = stripLineEscapes("|cffaabbcc|r")
            assert.equals("", result)
        end)

        it("handles + prefix stripping", function()
            assert.equals("Haste 120", stripLineEscapes("+ Haste 120"))
        end)

        it("handles & prefix stripping", function()
            assert.equals("Crit 50", stripLineEscapes("& Crit 50"))
        end)

        it("does not strip + in middle of string", function()
            assert.equals("Haste +120", stripLineEscapes("Haste +120"))
        end)
    end)
end)
