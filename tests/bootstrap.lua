-- Bootstrap for running EllesmereUI unit tests outside of World of Warcraft.
--
-- This file provides a minimal set of WoW globals and frame stubs so the
-- core addon file can be loaded in a plain Lua environment.
--
-- The test suite should remain focused on pure logic and helpers while
-- avoiding real UI rendering or runtime-only Blizzard APIs.

-- Required global for addon path
EUI_HOST_ADDON = "EllesmereUI"
EllesmereUI = {}

-- Minimal stub for LibStub so the addon can safely try to resolve libraries.
-- If a bundle is not available, LibStub returns nil and the addon falls back.
LibStub = function(name, quiet)
    return nil
end

-- Build a generic frame-like table with a lenient method stub.
-- Methods generally return the frame itself so chained calls do not error.
local function makeFrame()
    local frame = {}
    local methods = {
        GetObjectType = function()
            return "Frame"
        end,
        GetScale = function()
            return 1
        end,
        GetEffectiveScale = function()
            return 1
        end,
        GetWidth = function()
            return 1920
        end,
        GetHeight = function()
            return 1080
        end,
        CreateTexture = function()
            return makeFrame()
        end,
        CreateFontString = function()
            return makeFrame()
        end,
        CreateMaskTexture = function()
            return makeFrame()
        end,
    }

    setmetatable(methods, {
        __index = function()
            return function()
                return frame
            end
        end,
    })

    return setmetatable(frame, {
        __index = methods,
    })
end

-- Minimal parent frame placeholder used by CreateFrame.
UIParent = makeFrame()

-- CreateFrame stub used by the addon during load and by tests.
CreateFrame = function(...)
    return makeFrame()
end

-- Locale and player state stubs.
GetLocale = function()
    return "enUS"
end

UnitClass = function()
    return "player", "MAGE"
end

UnitFactionGroup = function()
    return "Alliance"
end

UnitName = function()
    return "TestPlayer"
end

GetNumGroupMembers = function()
    return 0
end

GetPhysicalScreenSize = function()
    return 1920, 1080
end

GetScreenWidth = function()
    return 1920
end

GetScreenHeight = function()
    return 1080
end

InCombatLockdown = function()
    return false
end

SlashCmdList = {}

C_AddOns = {
    IsAddOnLoaded = function()
        return false
    end,
    GetNumAddOns = function()
        return 0
    end,
    GetAddOnInfo = function()
        return nil
    end,
}

UpdateAddOnMemoryUsage = function()
    return nil
end

GetAddOnMemoryUsage = function()
    return 0
end

EnumerateFrames = function()
    return nil
end

issecrettable = function()
    return false
end

min = math.min
max = math.max

-- SavedVariables and addon metadata stubs.
GetAddOnMetadata = function(...)
    return nil
end

GetCVar = function(...)
    return nil
end

SetCVar = function(...)
    return nil
end

-- Time and scheduling.
GetTime = function()
    return 0
end

C_Timer = {
    After = function(_, callback)
        callback()
    end,
    NewTicker = function(_, callback)
        callback()
        return {
            Cancel = function() end,
        }
    end,
}

-- Addon loading helpers.
IsAddOnLoaded = function(...)
    return false
end

hooksecurefunc = function(...) end
LoadAddOn = function(...) return true end

-- Keep the standard print behavior in the test environment.
print = print

-- Load the main addon file once for tests. This is the only production file
-- required by the current test suite.
local chunk, err = loadfile("EllesmereUI.lua")
if not chunk then
    error("Failed to load EllesmereUI.lua: " .. tostring(err))
end
chunk("EllesmereUI")
