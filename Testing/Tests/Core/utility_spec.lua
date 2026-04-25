-- Utility helper coverage for small return-value driven helpers.

describe("EllesmereUI utility helpers", function()
    it("returns a positive scroll range when the frame reports one", function()
        local scrollFrame = {
            GetVerticalScrollRange = function()
                return 42
            end,
        }

        assert.are.equal(42, EllesmereUI.SafeScrollRange(scrollFrame))
    end)

    it("returns zero when the scroll range is missing, invalid, or non-positive", function()
        assert.are.equal(0, EllesmereUI.SafeScrollRange({
            GetVerticalScrollRange = function()
                return 0
            end,
        }))

        assert.are.equal(0, EllesmereUI.SafeScrollRange({
            GetVerticalScrollRange = function()
                return "not-a-number"
            end,
        }))

        assert.are.equal(0, EllesmereUI.SafeScrollRange({
            GetVerticalScrollRange = function()
                error("boom")
            end,
        }))
    end)
end)