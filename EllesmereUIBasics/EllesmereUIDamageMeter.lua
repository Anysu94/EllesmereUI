-------------------------------------------------------------------------------
--  EllesmereUIDamageMeter.lua
--  Reskins Blizzard's built-in Damage Meter to match EllesmereUI style.
--  Zero combat APIs, zero data calls â€” purely visual reskin of existing frames.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local FONT_PATH = (EllesmereUI and EllesmereUI.GetFontPath and EllesmereUI.GetFontPath("extras"))
    or "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF"
local BG_R, BG_G, BG_B, BG_A = 0.055, 0.063, 0.078, 0.92
local BAR_BG_A = 0.35
local BORDER_A = 0.15

local PP
local skinApplied = {}
local reskinTimer

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
local function StripTextures(frame)
    if not frame then return end
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region:IsObjectType("Texture") then
            local drawLayer = region:GetDrawLayer()
            if drawLayer == "BACKGROUND" or drawLayer == "BORDER" or drawLayer == "ARTWORK" then
                local atlas = region.GetAtlas and region:GetAtlas()
                local tex = region.GetTexture and region:GetTexture()
                -- Keep class/spec icons, strip everything else decorative
                if atlas or (tex and not tostring(tex):find("icon", 1, true)) then
                    region:SetAlpha(0)
                end
            end
        end
    end
end

local function SkinBar(bar)
    if not bar or bar._euiSkinned then return end

    -- Find the StatusBar child
    local statusBar
    for i = 1, bar:GetNumChildren() do
        local child = select(i, bar:GetChildren())
        if child and child:IsObjectType("StatusBar") then
            statusBar = child
            break
        end
    end

    -- If bar itself is a StatusBar
    if not statusBar and bar:IsObjectType("StatusBar") then
        statusBar = bar
    end

    if statusBar then
        statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    end

    -- Dark background behind each bar
    if not bar._euiBg then
        local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, BAR_BG_A)
        bar._euiBg = bg
    end

    bar._euiSkinned = true
end

-------------------------------------------------------------------------------
--  Main reskin function â€” called on the DamageMeter frame
-------------------------------------------------------------------------------
local function ReskinDamageMeter()
    local dm = _G.DamageMeter
    if not dm then return end
    if skinApplied[dm] then return end

    PP = PP or (EllesmereUI and EllesmereUI.PP)

    -- Strip Blizzard art/borders from the main frame
    StripTextures(dm)

    -- Apply dark background
    if not dm._euiBg then
        local bg = dm:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints()
        bg:SetColorTexture(BG_R, BG_G, BG_B, BG_A)
        dm._euiBg = bg
    end

    -- Thin border
    if not dm._euiBorder then
        local function MakeEdge(parent, point1, rel1, point2, rel2, w, h)
            local t = parent:CreateTexture(nil, "BORDER", nil, 7)
            t:SetColorTexture(1, 1, 1, BORDER_A)
            if w then t:SetSize(w, h or 1) end
            t:SetPoint(point1, parent, rel1)
            if point2 then t:SetPoint(point2, parent, rel2) end
            if PP then PP.DisablePixelSnap(t)
            elseif t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end
            return t
        end
        dm._euiBorder = {
            MakeEdge(dm, "TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT"),
            MakeEdge(dm, "BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT"),
            MakeEdge(dm, "TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT"),
            MakeEdge(dm, "TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT"),
        }
        dm._euiBorder[1]:SetHeight(1)
        dm._euiBorder[2]:SetHeight(1)
        dm._euiBorder[3]:SetWidth(1)
        dm._euiBorder[4]:SetWidth(1)
    end

    skinApplied[dm] = true
end

-------------------------------------------------------------------------------
--  Reskin child panels and bars (runs periodically to catch new bars)
-------------------------------------------------------------------------------
local function ReskinChildren()
    local dm = _G.DamageMeter
    if not dm then return end

    for i = 1, dm:GetNumChildren() do
        local child = select(i, dm:GetChildren())
        if child and child:IsShown() then
            -- Strip decorative textures from panels
            if not child._euiStripped then
                StripTextures(child)
                child._euiStripped = true
            end

            -- Reskin header font strings
            for j = 1, child:GetNumRegions() do
                local region = select(j, child:GetRegions())
                if region and region:IsObjectType("FontString") and not region._euiFontSet then
                    local _, size = region:GetFont()
                    region:SetFont(FONT_PATH, size or 12, "")
                    region:SetShadowOffset(1, -1)
                    region:SetShadowColor(0, 0, 0, 0.8)
                    region._euiFontSet = true
                end
            end

            -- Recurse into grandchildren (the actual bar rows)
            for k = 1, child:GetNumChildren() do
                local bar = select(k, child:GetChildren())
                if bar then
                    SkinBar(bar)

                    -- Reskin font strings on bars
                    for m = 1, bar:GetNumRegions() do
                        local region = select(m, bar:GetRegions())
                        if region and region:IsObjectType("FontString") and not region._euiFontSet then
                            local _, size = region:GetFont()
                            region:SetFont(FONT_PATH, size or 11, "")
                            region:SetShadowOffset(1, -1)
                            region:SetShadowColor(0, 0, 0, 0.8)
                            region._euiFontSet = true
                        end
                    end

                    -- Recurse one more level for nested bar structures
                    for n = 1, bar:GetNumChildren() do
                        local inner = select(n, bar:GetChildren())
                        if inner then
                            SkinBar(inner)
                            for q = 1, inner:GetNumRegions() do
                                local region = select(q, inner:GetRegions())
                                if region and region:IsObjectType("FontString") and not region._euiFontSet then
                                    local _, size = region:GetFont()
                                    region:SetFont(FONT_PATH, size or 11, "")
                                    region:SetShadowOffset(1, -1)
                                    region:SetShadowColor(0, 0, 0, 0.8)
                                    region._euiFontSet = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Periodic reskin (catches dynamically created bars)
-------------------------------------------------------------------------------
local tickFrame = CreateFrame("Frame")
tickFrame:Hide()
local tickElapsed = 0
tickFrame:SetScript("OnUpdate", function(self, dt)
    tickElapsed = tickElapsed + dt
    if tickElapsed < 0.5 then return end
    tickElapsed = 0

    local dm = _G.DamageMeter
    if not dm or not dm:IsShown() then return end

    ReskinDamageMeter()
    ReskinChildren()
end)

-------------------------------------------------------------------------------
--  Initialization â€” wait for DamageMeter to exist
-------------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    local dm = _G.DamageMeter
    if dm then
        C_Timer.After(1, function()
            ReskinDamageMeter()
            ReskinChildren()
            tickFrame:Show()
        end)
    else
        -- DamageMeter might load later; keep checking
        C_Timer.After(3, function()
            if _G.DamageMeter then
                ReskinDamageMeter()
                ReskinChildren()
                tickFrame:Show()
            end
        end)
    end
end)
