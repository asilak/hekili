-- Engine.lua
-- Polls C_AssistedCombat and distributes recommendations.

local _, ns = ...

local Engine = {}
ns.Engine = Engine

-- Fail-open wrapper: returns nil on any error (missing API, secret taint).
local function safeNextSpell()
    local ok, spellID = pcall(function()
        return C_AssistedCombat.GetNextCastSpell(false)
    end)
    if ok and type(spellID) == "number" then return spellID end
    return nil
end

function Engine.GetBaseSpell()
    return safeNextSpell()
end

local POLL_INTERVAL = 0.10 -- seconds; recommendation cadence, cheap call

local listeners = {}
local current = { spellID = nil, corrected = false, ruleID = nil }

function Engine.RegisterListener(fn)
    listeners[#listeners + 1] = fn
end

function Engine.GetCurrent()
    return current
end

local function compute()
    local base = safeNextSpell()
    local spellID, ruleID = base, nil
    if ns.Corrections and base then
        local ok, s, r = pcall(ns.Corrections.Apply, base)
        if ok and type(s) == "number" then spellID, ruleID = s, r end
    end
    return spellID, ruleID
end

local function tick()
    local spellID, ruleID = compute()
    if spellID == current.spellID and ruleID == current.ruleID then return end
    current.spellID = spellID
    current.ruleID = ruleID
    current.corrected = ruleID ~= nil
    for i = 1, #listeners do
        pcall(listeners[i], current)
    end
end

local driver = CreateFrame("Frame")
local elapsedAcc = 0
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self)
    self:SetScript("OnUpdate", function(_, elapsed)
        elapsedAcc = elapsedAcc + elapsed
        if elapsedAcc < POLL_INTERVAL then return end
        elapsedAcc = 0
        tick()
    end)
end)

-- Debug probe: /hkm prints the current base recommendation.
SLASH_HEKILIMIDNIGHT1 = "/hkm"
SlashCmdList.HEKILIMIDNIGHT = function()
    local spellID = Engine.GetBaseSpell()
    if not spellID then
        print("|cffff8800Hekili-M:|r no recommendation (out of combat, no target, or Assisted Combat unavailable).")
        return
    end
    local okName, name = pcall(function() return C_Spell.GetSpellName(spellID) end)
    print(("|cffff8800Hekili-M:|r next = %s (%d)"):format(okName and name or "?", spellID))
end
