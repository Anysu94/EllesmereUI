-------------------------------------------------------------------------------
--  EllesmereUIBasics.lua
--  Minimap & Chat customization for EllesmereUI
--  Themes: Classic (untouched Blizzard) / Modern (clean border, square/circle)
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local EMC = EllesmereUI.Lite.NewAddon(ADDON_NAME)
ns.EMC = EMC

local floor, abs, format = math.floor, math.abs, string.format
local GetTime = GetTime
local C_DateAndTime = C_DateAndTime

-------------------------------------------------------------------------------
--  Media paths
-------------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\EllesmereUIBasics\\Media\\"
local SQUARE_MASK = "Interface\\Buttons\\WHITE8x8"  -- solid white = square mask

-------------------------------------------------------------------------------
--  Defaults
-------------------------------------------------------------------------------
local DEFAULTS = {
    profile = {
        minimap = {
            theme       = "modern",   -- "classic" or "modern"
            shape       = "square",   -- "square" or "circle"
            borderSize  = 2,          -- px border thickness (modern only)
            borderR     = 0, borderG = 0, borderB = 0, borderA = 1,
            scale       = 1.0,
            zoom        = 3,          -- 0-5 zoom level
            mouseZoom   = true,       -- scroll wheel zoom
            clockShow   = true,
            clockMode   = "local",    -- "local" or "server"
            clock24h    = true,
        },
        -- friends, bags, minimapSkin defaults are injected at runtime
        -- from their respective modules via _ECF_DEFAULTS, _ECB_DEFAULTS, _EMS_DEFAULTS
    },
}

-------------------------------------------------------------------------------
--  State
-------------------------------------------------------------------------------
local borderFrame       -- our custom border overlay
local clockFrame        -- custom clock frame
local origMaskTexture   -- store original mask to restore on classic
local isApplied = false -- whether modern theme is currently active

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
local function GetAccent()
    local eg = EllesmereUI and EllesmereUI.ELLESMERE_GREEN
    if eg then return eg.r, eg.g, eg.b end
    return 12/255, 210/255, 157/255
end

-------------------------------------------------------------------------------
--  Blizzard element management
--  Hides/shows default Blizzard minimap chrome for modern theme
-------------------------------------------------------------------------------
local blizzElements = {}

local function CollectBlizzElements()
    -- These are the standard Blizzard minimap decorations
    -- We collect them once and cache for show/hide toggling
    local cluster = MinimapCluster
    if not cluster then return end

    local names = {
        "MinimapBackdrop",
        "MinimapBorderTop",
    }
    for _, name in ipairs(names) do
        local f = _G[name]
        if f then blizzElements[name] = f end
    end

    -- MinimapCluster sub-regions (borders, art)
    if cluster.BorderTop then blizzElements["cluster_BorderTop"] = cluster.BorderTop end
    if cluster.Background then blizzElements["cluster_Background"] = cluster.Background end

    -- The round border texture on the minimap itself
    if MinimapCompassTexture then blizzElements["MinimapCompassTexture"] = MinimapCompassTexture end
end

local function HideBlizzChrome()
    for _, elem in pairs(blizzElements) do
        if elem.Hide then elem:Hide() end
        if elem.SetAlpha then elem:SetAlpha(0) end
    end
    -- Hide the default minimap border/backdrop
    if MinimapBackdrop then MinimapBackdrop:Hide() end
    -- Hide compass texture (the rotating N/S/E/W ring)
    if MinimapCompassTexture then MinimapCompassTexture:SetAlpha(0) end
end

local function ShowBlizzChrome()
    for _, elem in pairs(blizzElements) do
        if elem.Show then elem:Show() end
        if elem.SetAlpha then elem:SetAlpha(1) end
    end
    if MinimapBackdrop then MinimapBackdrop:Show() end
    if MinimapCompassTexture then MinimapCompassTexture:SetAlpha(1) end
end

-------------------------------------------------------------------------------
--  Border frame (modern theme)
-------------------------------------------------------------------------------
local function CreateBorder()
    if borderFrame then return borderFrame end

    borderFrame = CreateFrame("Frame", "EllesmereMinimapBorder", Minimap)
    borderFrame:SetFrameStrata(Minimap:GetFrameStrata())
    borderFrame:SetFrameLevel(Minimap:GetFrameLevel() + 5)

    -- 4 edge textures
    local PP = EllesmereUI and EllesmereUI.PP
    borderFrame._edges = {}
    for i = 1, 4 do
        local tex = borderFrame:CreateTexture(nil, "OVERLAY")
        tex:SetColorTexture(0, 0, 0, 1)
        if PP then PP.DisablePixelSnap(tex)
        elseif tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false); tex:SetTexelSnappingBias(0) end
        borderFrame._edges[i] = tex
    end

    function borderFrame:ApplyBorder(size, r, g, b, a)
        local s = size or 2
        local edges = self._edges
        -- Top
        edges[1]:ClearAllPoints()
        edges[1]:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -s, s)
        edges[1]:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", s, s)
        edges[1]:SetHeight(s)
        edges[1]:SetColorTexture(r, g, b, a)
        -- Bottom
        edges[2]:ClearAllPoints()
        edges[2]:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -s, -s)
        edges[2]:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", s, -s)
        edges[2]:SetHeight(s)
        edges[2]:SetColorTexture(r, g, b, a)
        -- Left
        edges[3]:ClearAllPoints()
        edges[3]:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -s, s)
        edges[3]:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -s, -s)
        edges[3]:SetWidth(s)
        edges[3]:SetColorTexture(r, g, b, a)
        -- Right
        edges[4]:ClearAllPoints()
        edges[4]:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", s, s)
        edges[4]:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", s, -s)
        edges[4]:SetWidth(s)
        edges[4]:SetColorTexture(r, g, b, a)

        for _, e in ipairs(edges) do e:Show() end
    end

    function borderFrame:HideBorder()
        for _, e in ipairs(self._edges) do e:Hide() end
    end

    return borderFrame
end

-------------------------------------------------------------------------------
--  Clock frame (custom clock overlay)
-------------------------------------------------------------------------------
local function CreateClock()
    if clockFrame then return clockFrame end

    clockFrame = CreateFrame("Frame", "EllesmereMinimapClock", Minimap)
    clockFrame:SetSize(60, 18)
    clockFrame:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 4)
    clockFrame:SetFrameLevel(Minimap:GetFrameLevel() + 10)

    -- Semi-transparent background pill
    local bg = clockFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    clockFrame._bg = bg

    local FONT_PATH = (EllesmereUI and EllesmereUI.GetFontPath and EllesmereUI.GetFontPath("minimapChat"))
        or (EllesmereUI and EllesmereUI.EXPRESSWAY)
        or "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF"

    local fs = clockFrame:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT_PATH, 11, "OUTLINE")
    fs:SetTextColor(1, 1, 1, 0.85)
    fs:SetPoint("CENTER")
    clockFrame._text = fs

    -- Click to toggle local/server time
    clockFrame:EnableMouse(true)
    clockFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            local p = EMC.db and EMC.db.profile.minimap
            if p then
                p.clockMode = (p.clockMode == "local") and "server" or "local"
            end
        end
    end)

    -- Tooltip
    clockFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        local p = EMC.db and EMC.db.profile.minimap
        local mode = (p and p.clockMode) or "local"
        GameTooltip:AddLine("Clock (" .. mode .. " time)", 1, 1, 1)
        GameTooltip:AddLine("Left-click to toggle local/server", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    clockFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Update every second
    local elapsed = 0
    clockFrame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < 1 then return end
        elapsed = 0

        local p = EMC.db and EMC.db.profile.minimap
        if not p or not p.clockShow then
            self:Hide()
            return
        end

        local mode = p.clockMode or "local"
        local use24 = p.clock24h
        local h, m

        if mode == "server" then
            local info = C_DateAndTime.GetCurrentCalendarTime()
            if info then
                h, m = info.hour, info.minute
            else
                h, m = GetGameTime()
            end
        else
            local d = date("*t")
            h, m = d.hour, d.min
        end

        if use24 then
            self._text:SetText(format("%02d:%02d", h, m))
        else
            local suffix = h >= 12 and "PM" or "AM"
            h = h % 12
            if h == 0 then h = 12 end
            self._text:SetText(format("%d:%02d %s", h, m, suffix))
        end

        -- Auto-size the background pill
        local tw = self._text:GetStringWidth() + 12
        self:SetWidth(tw)
    end)

    return clockFrame
end

-------------------------------------------------------------------------------
--  Mouse wheel zoom
-------------------------------------------------------------------------------
local function SetupMouseZoom()
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", function(self, delta)
        local p = EMC.db and EMC.db.profile.minimap
        if not p or not p.mouseZoom then return end

        local cur = Minimap:GetZoom()
        if delta > 0 then
            if cur < Minimap:GetZoomLevels() - 1 then
                Minimap:SetZoom(cur + 1)
            end
        else
            if cur > 0 then
                Minimap:SetZoom(cur - 1)
            end
        end

        -- Save zoom level
        if p then p.zoom = Minimap:GetZoom() end
    end)
end

-------------------------------------------------------------------------------
--  Shape management (square vs circle mask)
-------------------------------------------------------------------------------
local function ApplyShape(shape)
    if not Minimap.SetMaskTexture then return end

    if shape == "square" then
        -- WHITE8x8 is a solid white texture = no mask = square
        Minimap:SetMaskTexture(SQUARE_MASK)
    else
        -- Restore circle: use Blizzard's default circular mask
        Minimap:SetMaskTexture("Textures\\MinimapMask")
    end

    -- Notify LibDBIcon and other addons about shape change
    -- GetMinimapShape is a global function addons check
    if shape == "square" then
        function GetMinimapShape() return "SQUARE" end
    else
        function GetMinimapShape() return "ROUND" end
    end
end

-------------------------------------------------------------------------------
--  Apply / Revert theme
-------------------------------------------------------------------------------
local function ApplyModernTheme()
    local p = EMC.db and EMC.db.profile.minimap
    if not p then return end

    CollectBlizzElements()
    HideBlizzChrome()

    -- Shape â€” delegate to MinimapSkin module if available, else fallback
    if _G._EMS_ApplyMinimapSkin then
        _G._EMS_ApplyMinimapSkin()
    else
        ApplyShape(p.shape)
        -- Border (legacy)
        local bf = CreateBorder()
        bf:ApplyBorder(p.borderSize, p.borderR, p.borderG, p.borderB, p.borderA)
        bf:Show()
    end

    -- Scale
    if MinimapCluster then
        MinimapCluster:SetScale(p.scale)
    end

    -- Zoom
    if p.zoom then
        local maxZoom = Minimap:GetZoomLevels() - 1
        Minimap:SetZoom(math.min(p.zoom, maxZoom))
    end

    -- Clock
    local cf = CreateClock()
    if p.clockShow then
        cf:Show()
    else
        cf:Hide()
    end

    -- Mouse zoom
    SetupMouseZoom()

    -- Clean up the zone text area for a cleaner look
    if MinimapCluster and MinimapCluster.ZoneTextButton then
        MinimapCluster.ZoneTextButton:Hide()
    end

    isApplied = true
end

local function ApplyClassicTheme()
    -- Restore everything to Blizzard defaults
    ShowBlizzChrome()

    -- Revert minimap skin if module is loaded
    if _G._EMS_RevertMinimapSkin then
        _G._EMS_RevertMinimapSkin()
    else
        -- Restore circle mask
        ApplyShape("circle")
    end

    -- Hide our custom border
    if borderFrame then borderFrame:HideBorder() end

    -- Hide custom clock (use Blizzard's)
    if clockFrame then clockFrame:Hide() end

    -- Restore scale
    if MinimapCluster then
        MinimapCluster:SetScale(1)
    end

    -- Restore zone text
    if MinimapCluster and MinimapCluster.ZoneTextButton then
        MinimapCluster.ZoneTextButton:Show()
    end

    -- Still allow mouse zoom in classic
    local p = EMC.db and EMC.db.profile.minimap
    if p and p.mouseZoom then
        SetupMouseZoom()
    end

    isApplied = false
end

-------------------------------------------------------------------------------
--  Master Apply function (called from options and on load)
-------------------------------------------------------------------------------
function EMC:ApplyAll()
    local p = self.db and self.db.profile.minimap
    if not p then return end

    if p.theme == "modern" then
        ApplyModernTheme()
    else
        ApplyClassicTheme()
    end
end

-------------------------------------------------------------------------------
--  Initialization
-------------------------------------------------------------------------------
function EMC:OnInitialize()
    self.db = EllesmereUI.Lite.NewDB("EllesmereUIBasicsDB", DEFAULTS, true)

    -- Merge module defaults into profile if missing
    local p = self.db.profile
    if _G._ECF_DEFAULTS and not p.friends then
        p.friends = {}
        for k, v in pairs(_G._ECF_DEFAULTS) do
            if type(v) == "table" then p.friends[k] = {} else p.friends[k] = v end
        end
    end
    if _G._ECB_DEFAULTS and not p.bags then
        p.bags = {}
        for k, v in pairs(_G._ECB_DEFAULTS) do
            p.bags[k] = v
        end
    end
    if _G._EMS_DEFAULTS and not p.minimapSkin then
        p.minimapSkin = {}
        for k, v in pairs(_G._EMS_DEFAULTS) do
            p.minimapSkin[k] = v
        end
    end

    -- Expose for options lua
    _G._EMC_AceDB = self.db
    _G._EMC_Apply = function() EMC:ApplyAll() end
end

function EMC:OnEnable()
    -- Minimap button (shared across all Ellesmere addons â€” first to load wins)
    -- Minimap button (handled by parent addon)
    if not _EllesmereUI_MinimapRegistered and EllesmereUI and EllesmereUI.CreateMinimapButton then
        EllesmereUI.CreateMinimapButton()
    end

    -- Delay apply to ensure all Blizzard frames are loaded
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0.5, function()
            EMC:ApplyAll()
        end)
    end)
end

-------------------------------------------------------------------------------
--  Slash commands
-------------------------------------------------------------------------------
SLASH_EMC1 = "/emc"
SLASH_EMC2 = "/ellesminimap"
SlashCmdList.EMC = function(msg)
    if InCombatLockdown and InCombatLockdown() then return end
    if EllesmereUI and EllesmereUI.ShowModule then
        EllesmereUI:ShowModule("EllesmereUIBasics")
    end
end
