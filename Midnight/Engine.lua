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
