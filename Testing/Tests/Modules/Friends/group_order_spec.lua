-- Friends list GetValidGroupOrder tests.
-- Tests stale entry removal, missing entry insertion, favorites-first / ungrouped-last invariants.

describe("Friends GetValidGroupOrder", function()
    local modulePath = "EllesmereUIFriends/EllesmereUIFriends.lua"

    local original_EllesmereUI
    local original_EllesmereUIDB
    local original_C_Timer
    local original_C_BattleNet
    local original_C_FriendList
    local original_C_ClassColor
    local original_C_Texture
    local original_FRIENDS_BNET_BACKGROUND_COLOR
    local original_FRIENDS_WOW_BACKGROUND_COLOR

    local GetValidGroupOrder

    local function replaceExact(source, oldText, newText, label)
        local startIndex = source:find(oldText, 1, true)
        assert.is_truthy(startIndex, "expected exact replacement for " .. label)
        local endIndex = startIndex + #oldText - 1
        return source:sub(1, startIndex - 1) .. newText .. source:sub(endIndex + 1)
    end

    local function loadFriends()
        local handle = assert(io.open(modulePath, "rb"))
        local source = assert(handle:read("*a"))
        handle:close()
        source = source:gsub("^\239\187\191", "")
        source = source:gsub("\r\n", "\n")

        -- Export GetValidGroupOrder by writing to global EllesmereUI table
        source = replaceExact(
            source,
            "    fg.friendGroupOrder = clean\n    return clean\nend\n\n-- Modules temporarily disabled",
            "    fg.friendGroupOrder = clean\n    return clean\nend\n_G.EllesmereUI._GetValidGroupOrder = GetValidGroupOrder\n\n-- Modules temporarily disabled",
            "GetValidGroupOrder export"
        )

        local chunk, err = loadstring(source, "@" .. modulePath)
        assert.is_nil(err, "loadstring: " .. tostring(err))
        -- pcall because later parts may fail on unrelated APIs
        pcall(chunk, "EllesmereUIFriends", {})
        GetValidGroupOrder = _G.EllesmereUI._GetValidGroupOrder
    end

    before_each(function()
        original_EllesmereUI = _G.EllesmereUI
        original_EllesmereUIDB = _G.EllesmereUIDB
        original_C_Timer = _G.C_Timer
        original_C_BattleNet = _G.C_BattleNet
        original_C_FriendList = _G.C_FriendList
        original_C_ClassColor = _G.C_ClassColor
        original_C_Texture = _G.C_Texture
        original_FRIENDS_BNET_BACKGROUND_COLOR = _G.FRIENDS_BNET_BACKGROUND_COLOR
        original_FRIENDS_WOW_BACKGROUND_COLOR = _G.FRIENDS_WOW_BACKGROUND_COLOR

        _G.C_Timer = { After = function() end, NewTicker = function() return {} end }
        _G.C_BattleNet = {
            GetFriendAccountInfo = function() return nil end,
            GetFriendNumGameAccounts = function() return 0 end,
            GetAccountInfoByID = function() return nil end,
            GetFriendGameAccountInfo = function() return nil end,
        }
        _G.C_FriendList = {
            GetNumFriends = function() return 0, 0 end,
            GetFriendInfoByIndex = function() return nil end,
        }
        _G.C_ClassColor = {
            GetClassColor = function() return { r = 1, g = 1, b = 1, GenerateHexColor = function() return "ffffffff" end } end,
        }
        _G.C_Texture = {
            GetAtlasInfo = function() return nil end,
        }
        _G.FRIENDS_BNET_BACKGROUND_COLOR = { r = 0, g = 0, b = 0 }
        _G.FRIENDS_WOW_BACKGROUND_COLOR = { r = 0, g = 0, b = 0 }
        _G.BNGetNumFriends = function() return 0, 0 end
        _G.BNet_GetClientTexture = function() return "Interface\\FriendsFrame\\Battlenet-Battleneticon" end
        _G.BNET_CLIENT_WOW = "WoW"
        _G.FRIENDS_TEXTURE_ONLINE = "Interface\\FriendsFrame\\StatusIcon-Online"
        _G.FRIENDS_TEXTURE_AFK = "Interface\\FriendsFrame\\StatusIcon-Away"
        _G.FRIENDS_TEXTURE_DND = "Interface\\FriendsFrame\\StatusIcon-DnD"
        _G.FRIENDS_TEXTURE_OFFLINE = "Interface\\FriendsFrame\\StatusIcon-Offline"
        _G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
        _G.GameFontNormal = { GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end }
        _G.GameTooltip = {
            SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end,
            ClearLines = function() end,
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
            PP = {
                CreateBorder = function() end,
                SetBorderColor = function() end,
                CreateAnchoredBG = function() return { SetColorTexture = function() end, SetAllPoints = function() end } end,
            },
            ELLESMERE_GREEN = { r = 0, g = 0.8, b = 0.5 },
            GetFontPath = function() return "Fonts\\FRIZQT__.TTF" end,
            GetFontOutlineFlag = function() return "" end,
            IsInCombat = function() return false end,
            CheckVisibilityOptions = function() return false end,
            EvalVisibility = function() return true end,
            RegisterVisibilityUpdater = function() end,
        }

        _G.EllesmereUIDB = {
            global = {
                friendGroups = {},
                friendAssignments = {},
                friendNotes = {},
                friendGroupColors = {},
                friendGroupOrder = {},
            },
        }
    end)

    after_each(function()
        _G.EllesmereUI = original_EllesmereUI
        _G.EllesmereUIDB = original_EllesmereUIDB
        _G.C_Timer = original_C_Timer
        _G.C_BattleNet = original_C_BattleNet
        _G.C_FriendList = original_C_FriendList
        _G.C_ClassColor = original_C_ClassColor
        _G.C_Texture = original_C_Texture
        _G.FRIENDS_BNET_BACKGROUND_COLOR = original_FRIENDS_BNET_BACKGROUND_COLOR
        _G.FRIENDS_WOW_BACKGROUND_COLOR = original_FRIENDS_WOW_BACKGROUND_COLOR
    end)

    local function setup(groups, order)
        local fg = _G.EllesmereUIDB.global
        fg.friendGroups = groups or {}
        fg.friendGroupOrder = order or {}
    end

    it("builds order from scratch with favorites first and ungrouped last", function()
        setup({ { name = "Guild" }, { name = "Arena" } }, {})
        loadFriends()
        local order = GetValidGroupOrder()
        assert.equals("_favorites", order[1])
        assert.equals("_ungrouped", order[#order])
        -- Custom groups in between
        local found = {}
        for _, k in ipairs(order) do found[k] = true end
        assert.is_true(found["Guild"])
        assert.is_true(found["Arena"])
    end)

    it("removes stale entries not in current groups", function()
        setup(
            { { name = "Guild" } },
            { "_favorites", "OldGroup", "Guild", "_ungrouped" }
        )
        loadFriends()
        local order = GetValidGroupOrder()
        local found = {}
        for _, k in ipairs(order) do found[k] = true end
        assert.is_nil(found["OldGroup"])
        assert.is_true(found["Guild"])
    end)

    it("appends missing groups before ungrouped", function()
        setup(
            { { name = "Guild" }, { name = "NewGroup" } },
            { "_favorites", "Guild", "_ungrouped" }
        )
        loadFriends()
        local order = GetValidGroupOrder()
        -- NewGroup should appear before _ungrouped
        local newIdx, ungroupedIdx
        for i, k in ipairs(order) do
            if k == "NewGroup" then newIdx = i end
            if k == "_ungrouped" then ungroupedIdx = i end
        end
        assert.is_truthy(newIdx)
        assert.is_truthy(ungroupedIdx)
        assert.is_true(newIdx < ungroupedIdx)
    end)

    it("preserves existing order of known groups", function()
        setup(
            { { name = "Arena" }, { name = "Guild" } },
            { "_favorites", "Arena", "Guild", "_ungrouped" }
        )
        loadFriends()
        local order = GetValidGroupOrder()
        local arenaIdx, guildIdx
        for i, k in ipairs(order) do
            if k == "Arena" then arenaIdx = i end
            if k == "Guild" then guildIdx = i end
        end
        assert.is_true(arenaIdx < guildIdx)
    end)

    it("deduplicates repeated entries", function()
        setup(
            { { name = "Guild" } },
            { "_favorites", "Guild", "Guild", "_ungrouped" }
        )
        loadFriends()
        local order = GetValidGroupOrder()
        local count = 0
        for _, k in ipairs(order) do
            if k == "Guild" then count = count + 1 end
        end
        assert.equals(1, count)
    end)

    it("re-inserts missing _favorites at position 1", function()
        setup(
            { { name = "Guild" } },
            { "Guild", "_ungrouped" }
        )
        loadFriends()
        local order = GetValidGroupOrder()
        assert.equals("_favorites", order[1])
    end)

    it("appends missing _ungrouped at end", function()
        setup(
            { { name = "Guild" } },
            { "_favorites", "Guild" }
        )
        loadFriends()
        local order = GetValidGroupOrder()
        assert.equals("_ungrouped", order[#order])
    end)

    it("handles empty groups list", function()
        setup({}, {})
        loadFriends()
        local order = GetValidGroupOrder()
        assert.equals(2, #order)
        assert.equals("_favorites", order[1])
        assert.equals("_ungrouped", order[2])
    end)
end)
