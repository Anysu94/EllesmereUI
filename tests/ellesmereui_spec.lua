describe("EllesmereUI core helpers", function()
    before_each(function()
        EllesmereUIDB = nil
    end)

    it("resolves the auto faction theme from the WoW API", function()
        assert.are.equal("Alliance", EllesmereUI._ResolveFactionTheme("Faction (Auto)"))
    end)

    it("preserves explicit theme names", function()
        assert.are.equal("Horde", EllesmereUI._ResolveFactionTheme("Horde"))
        assert.are.equal("Dark", EllesmereUI._ResolveFactionTheme("Dark"))
    end)

    it("returns a valid path for a bundled font", function()
        local path = EllesmereUI.ResolveFontName("Expressway")

        assert.is_string(path)
        assert.is_truthy(path:find("Expressway", 1, true))
    end)

    it("falls back to Expressway for unknown fonts", function()
        local path = EllesmereUI.ResolveFontName("Nonexistent Font")

        assert.are.equal("Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF", path)
    end)

    it("returns the configured global font name", function()
        EllesmereUIDB = { fonts = { global = "Expressway", outlineMode = "shadow" } }

        assert.are.equal("Expressway", EllesmereUI.GetFontName("EllesmereUI"))
    end)

    it("lazy-initializes the font database defaults", function()
        local db = EllesmereUI.GetFontsDB()

        assert.are.same({
            global = "Expressway",
            outlineMode = "shadow",
        }, db)
        assert.are.same(db, EllesmereUIDB.fonts)
    end)
end)