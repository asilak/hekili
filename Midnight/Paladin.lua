-- Paladin.lua
-- Correction rules for Holy (65), Protection (66), Retribution (70).
-- Only readable-in-combat data: Holy Power (secondary resource), health percent.

local _, ns = ...

if UnitClassBase("player") ~= "PALADIN" then return end

local Safe, Corrections = ns.Safe, ns.Corrections

-- Divine Storm (53385, AoE finisher) is deliberately absent: choosing it over
-- Templar's Verdict needs enemy count, which is a secret value in 12.x.
local WORD_OF_GLORY           = 85673
local SHIELD_OF_THE_RIGHTEOUS = 53600
local TEMPLARS_VERDICT        = 85256

local EMERGENCY_HEALTH_PCT = 35
local HOLY_POWER_CAP       = 5
local WOG_MIN_HOLY_POWER   = 3

local function holyPower() return Safe.Power(Enum.PowerType.HolyPower) end

local function emergencyWoG()
    local hp, pool = Safe.HealthPercent("player"), holyPower()
    return hp ~= nil and pool ~= nil
        and hp < EMERGENCY_HEALTH_PCT and pool >= WOG_MIN_HOLY_POWER
end

local function cappedPool()
    local pool = holyPower()
    return pool ~= nil and pool >= HOLY_POWER_CAP
end

-- Retribution (70): never waste capped Holy Power; survive first.
Corrections.RegisterRule(70, { id = "ret_emergency_wog", priority = 10, spell = WORD_OF_GLORY, when = emergencyWoG })
Corrections.RegisterRule(70, { id = "ret_capped_tv",     priority = 20, spell = TEMPLARS_VERDICT, when = cappedPool })

-- Protection (66): emergency self-heal, otherwise spend cap on SotR.
Corrections.RegisterRule(66, { id = "prot_emergency_wog", priority = 10, spell = WORD_OF_GLORY, when = emergencyWoG })
Corrections.RegisterRule(66, { id = "prot_capped_sotr",   priority = 20, spell = SHIELD_OF_THE_RIGHTEOUS, when = cappedPool })

-- Holy (65): DPS-focus profile — WoG on emergency or capped pool.
Corrections.RegisterRule(65, { id = "holy_emergency_wog", priority = 10, spell = WORD_OF_GLORY, when = emergencyWoG })
Corrections.RegisterRule(65, { id = "holy_capped_wog",    priority = 20, spell = WORD_OF_GLORY, when = cappedPool })
