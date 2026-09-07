-- Display.lua
-- One movable icon showing the current recommendation.

local ADDON, ns = ...

local DEFAULTS = { point = "CENTER", relPoint = "CENTER", x = 0, y = -180, scale = 1.0 }
local ICON_SIZE = 50
local MARKER_SIZE = 12

local frame = CreateFrame("Frame", "HekiliMidnightDisplay", UIParent)
frame:SetSize(ICON_SIZE, ICON_SIZE)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:Hide()

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints(frame)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim default icon border

-- Orange corner marker, shown only when a correction rule fired.
local marker = frame:CreateTexture(nil, "OVERLAY")
marker:SetSize(MARKER_SIZE, MARKER_SIZE)
marker:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
marker:SetColorTexture(1, 0.53, 0, 0.9)
marker:Hide()

local keybindText = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
keybindText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

local function applyPosition()
    local db = HekiliMidnightDB
    frame:ClearAllPoints()
    frame:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    frame:SetScale(db.scale)
end

frame:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    local db = HekiliMidnightDB
    db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
end)

local function onRecommendation(rec)
    if not rec.spellID then
        frame:Hide()
        return
    end
    local ok, tex = pcall(function() return C_Spell.GetSpellTexture(rec.spellID) end)
    icon:SetTexture(ok and tex or 134400) -- 134400 = question mark icon
    marker:SetShown(rec.corrected)
    if ns.Keybinds then
        keybindText:SetText(ns.Keybinds.ForSpell(rec.spellID) or "")
    end
    frame:Show()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        HekiliMidnightDB = HekiliMidnightDB or {}
        for k, v in pairs(DEFAULTS) do
            if HekiliMidnightDB[k] == nil then HekiliMidnightDB[k] = v end
        end
    elseif event == "PLAYER_LOGIN" then
        applyPosition()
        ns.Engine.RegisterListener(onRecommendation)
    end
end)
