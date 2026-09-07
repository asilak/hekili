-- Keybinds.lua
-- Maps spellID -> keybind text by scanning default action bar slots.

local _, ns = ...

local Keybinds = {}
ns.Keybinds = Keybinds

-- Default bars: slot ranges and their binding command prefixes.
local SLOT_BINDINGS = {
    { first = 1,  last = 12,  cmd = "ACTIONBUTTON%d" },
    { first = 25, last = 36,  cmd = "MULTIACTIONBAR3BUTTON%d" }, -- right bar 1
    { first = 37, last = 48,  cmd = "MULTIACTIONBAR4BUTTON%d" }, -- right bar 2
    { first = 49, last = 60,  cmd = "MULTIACTIONBAR2BUTTON%d" }, -- bottom right
    { first = 61, last = 72,  cmd = "MULTIACTIONBAR1BUTTON%d" }, -- bottom left
    { first = 145, last = 156, cmd = "MULTIACTIONBAR5BUTTON%d" },
    { first = 157, last = 168, cmd = "MULTIACTIONBAR6BUTTON%d" },
    { first = 169, last = 180, cmd = "MULTIACTIONBAR7BUTTON%d" },
}

local ABBREV = {
    ["SHIFT%-"] = "S-", ["CTRL%-"] = "C-", ["ALT%-"] = "A-",
    ["BUTTON"] = "M", ["MOUSEWHEELUP"] = "MwU", ["MOUSEWHEELDOWN"] = "MwD",
    ["NUMPAD"] = "N",
}

local cache = {} -- spellID -> keybind text

local function shorten(key)
    for pat, rep in pairs(ABBREV) do key = key:gsub(pat, rep) end
    return key
end

local function rescan()
    wipe(cache)
    for _, bar in ipairs(SLOT_BINDINGS) do
        for slot = bar.first, bar.last do
            local ok, kind, id = pcall(GetActionInfo, slot)
            if ok and kind == "spell" and id and not cache[id] then
                local key = GetBindingKey(bar.cmd:format(slot - bar.first + 1))
                if key then cache[id] = shorten(key) end
            end
        end
    end
end

function Keybinds.ForSpell(spellID)
    return cache[spellID]
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
watcher:RegisterEvent("UPDATE_BINDINGS")
watcher:SetScript("OnEvent", function() pcall(rescan) end)
