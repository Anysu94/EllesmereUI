-- ResourceBars cast bar progress calculation bug tests.
-- Tests that the cast bar OnUpdate handler guards against division by zero
-- when _endTime == _startTime (zero-duration casts).

describe("ResourceBars cast bar progress", function()

    -- The cast bar OnUpdate at EllesmereUIResourceBars.lua lines ~3541 and ~3575
    -- computes progress as:
    --   (now - _startTime) / (_endTime - _startTime)     [casting]
    --   (_endTime - now)   / (_endTime - _startTime)     [channeling]
    --
    -- When _endTime == _startTime (zero-duration cast/channel), the divisor
    -- is 0, producing inf/nan. Lua's min(max(nan, 0), 1) returns nan because
    -- NaN fails all comparisons. Passing NaN to SetValue() can corrupt the
    -- bar widget state.
    --
    -- Meanwhile, the tick-mark code at line ~3452 correctly guards:
    --   if channelDuration > 0 then ... else numTicks = 0 end

    -- We test the raw arithmetic to document the bug without loading the full
    -- module (which requires extensive WoW frame stubs).

    local function castProgress(now, startTime, endTime)
        -- Extracted from EllesmereUIResourceBars.lua line 3541
        local progress = (now - startTime) / (endTime - startTime)
        return math.min(math.max(progress, 0), 1)
    end

    local function channelProgress(now, startTime, endTime)
        -- Extracted from EllesmereUIResourceBars.lua line 3575
        local progress = (endTime - now) / (endTime - startTime)
        return math.min(math.max(progress, 0), 1)
    end

    describe("BUG: division by zero when endTime == startTime", function()
        it("cast progress produces NaN for zero-duration cast", function()
            local result = castProgress(100, 100, 100)
            -- 0/0 = NaN in Lua. NaN ~= NaN, so this is how we detect it:
            local isNaN = (result ~= result)
            assert.is_true(isNaN,
                "Zero-duration cast should produce NaN from 0/0 division — "
                .. "the production code at line 3541 has no guard for this case. "
                .. "This NaN propagates to bar:SetValue() which can cause visual "
                .. "corruption. The tick-mark code at line 3452 correctly guards "
                .. "against this with 'if channelDuration > 0'.")
        end)

        it("channel progress produces NaN for zero-duration channel", function()
            local result = channelProgress(100, 100, 100)
            local isNaN = (result ~= result)
            assert.is_true(isNaN,
                "Zero-duration channel should produce NaN from 0/0 division — "
                .. "the production code at line 3575 has no guard for this case.")
        end)

        it("cast progress produces inf when now differs from start with zero duration", function()
            -- When now > startTime but endTime == startTime:
            -- (101 - 100) / (100 - 100) = 1/0 = inf
            local result = castProgress(101, 100, 100)
            -- min(max(inf, 0), 1) should be 1, so this case is accidentally
            -- "safe" — but only because inf > 0 and inf > 1 resolves to 1.
            -- The inverse case (now < startTime) gives -inf -> clamped to 0.
            -- Document this for completeness.
            assert.equals(1, result,
                "1/0 = inf, clamped to 1 by min/max — accidentally safe")
        end)
    end)

    -- Normal operation sanity checks
    describe("normal cast progress", function()
        it("returns 0 at start of cast", function()
            assert.is_near(0, castProgress(0, 0, 2), 0.001)
        end)

        it("returns 0.5 at midpoint", function()
            assert.is_near(0.5, castProgress(1, 0, 2), 0.001)
        end)

        it("returns 1 at end of cast", function()
            assert.is_near(1.0, castProgress(2, 0, 2), 0.001)
        end)
    end)

    describe("normal channel progress", function()
        it("returns 1 at start of channel", function()
            assert.is_near(1.0, channelProgress(0, 0, 2), 0.001)
        end)

        it("returns 0.5 at midpoint", function()
            assert.is_near(0.5, channelProgress(1, 0, 2), 0.001)
        end)

        it("returns 0 at end of channel", function()
            assert.is_near(0.0, channelProgress(2, 0, 2), 0.001)
        end)
    end)
end)
