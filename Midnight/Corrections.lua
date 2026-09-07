-- Corrections.lua
-- Per-spec correction rules over non-secret data. Fail-open by design:
-- any error anywhere returns the untouched Blizzard recommendation.

local _, ns = ...

local Safe = {}
ns.Safe = Safe

function Safe.HealthPercent(unit)
    local ok, v = pcall(UnitHealthPercent, unit or "player")
    if ok and type(v) == "number" then return v end
    return nil
end

function Safe.Power(powerEnum)
    local ok, v = pcall(UnitPower, "player", powerEnum)
    if ok and type(v) == "number" then return v end
    return nil
end

function Safe.SpecID()
    local ok, specID = pcall(function()
        local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
        local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
        local idx = getSpec()
        return idx and (getInfo(idx))
    end)
    if ok and type(specID) == "number" then return specID end
    return nil
end

local MAX_RULE_ERRORS = 3
local rulesBySpec = {} -- specID -> array of rules

local Corrections = {}
ns.Corrections = Corrections

function Corrections.RegisterRule(specID, rule)
    local list = rulesBySpec[specID]
    if not list then list = {}; rulesBySpec[specID] = list end
    rule.errors = 0
    list[#list + 1] = rule
    table.sort(list, function(a, b) return a.priority < b.priority end)
end

function Corrections.Apply(baseSpellID)
    local specID = Safe.SpecID()
    local list = specID and rulesBySpec[specID]
    if not list then return baseSpellID, nil end
    for i = 1, #list do
        local rule = list[i]
        if rule.errors < MAX_RULE_ERRORS then
            local ok, fired = pcall(rule.when)
            if not ok then
                rule.errors = rule.errors + 1
            elseif fired then
                return rule.spell, rule.id
            end
        end
    end
    return baseSpellID, nil
end
