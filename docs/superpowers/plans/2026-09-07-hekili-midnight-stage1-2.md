# Hekili Midnight (Stage 1–2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A thin `Midnight/` module that shows Blizzard's Assisted Combat recommendation in a Hekili-style icon (all specs), with a fail-open Paladin correction layer on top.

**Architecture:** `Engine` polls `C_AssistedCombat.GetNextCastSpell()`, pipes the result through `Corrections` (per-spec rules over non-secret data), and notifies `Display`. Legacy Hekili engine files are removed from the TOC and never loaded. Spec: `docs/superpowers/specs/2026-09-07-hekili-midnight-hybrid-design.md`.

**Tech Stack:** WoW Lua 5.1, plain frames (no Ace3 — local `Libs/` is empty), luacheck for static checks.

## Global Constraints

- TOC `## Interface:` = `120105` — **verify in-game first**: `/dump select(4, GetBuildInfo())`; if it prints a different number, use that.
- No external libraries in `Midnight/` — plain `CreateFrame`, shared addon namespace `local ADDON, ns = ...`.
- **Fail-open everywhere:** every call that can touch a secret value or missing API goes through `pcall`; on failure return `nil`/base recommendation. The addon must never raise a Lua error in combat.
- SavedVariables: `HekiliMidnightDB` (new; do not touch legacy `HekiliDB`).
- Commits: `<type>: <subject>` (feat/fix/docs/chore), no attribution trailers.
- Static gate for every task: `luacheck Midnight/ --no-color` → `0 errors`. Warnings must also be 0 unless a step says otherwise.
- Automated unit tests are out of scope by spec (verification = luacheck + in-game checklist). Steps marked **USER CHECKPOINT** are executed by the user in the game client; do not proceed past them until the user confirms.
- New code identifiers and comments in English (repo convention).

## File Structure

| File | Responsibility |
|---|---|
| `Hekili.toc` (modify) | 12.x interface, new SavedVariables, load only `Midnight/*` |
| `Midnight/Engine.lua` (create) | Poll Blizzard recommendation, run corrections, notify listeners; `/hkm` debug slash |
| `Midnight/Corrections.lua` (create) | Rule registry + fail-open apply pipeline + safe data accessors |
| `Midnight/Paladin.lua` (create) | Correction rules for spec IDs 65/66/70 |
| `Midnight/Keybinds.lua` (create) | Resolve action-bar keybind for a spell ID |
| `Midnight/Display.lua` (create) | Movable icon frame, texture + keybind text + correction marker, `HekiliMidnightDB` |
| `.luacheckrc` (modify) | Add 12.x API globals used by the module |

---

### Task 1: 12.x TOC + Engine skeleton with `/hkm` probe

**Files:**
- Modify: `Hekili.toc` (replace file list; keep header keys)
- Create: `Midnight/Engine.lua`
- Modify: `.luacheckrc` (append read_globals)

**Interfaces:**
- Produces: shared namespace `ns` (second vararg of every file); `ns.Engine` table with `ns.Engine.GetBaseSpell() -> number|nil`; slash command `/hkm`.

- [ ] **Step 1: Confirm luacheck is available**

Run: `luacheck --version || luarocks install --local luacheck && export PATH="$HOME/.luarocks/bin:$PATH"`
Expected: a version string like `Luacheck 1.x`.

- [ ] **Step 2: Rewrite `Hekili.toc`**

Replace the entire file with:

```
## Interface: 120105
## Version: @project-version@
## Title: Hekili (Midnight)
## Author: Hekili, asilak
## IconTexture: Interface\AddOns\Hekili\Textures\LOGO-ORANGE.blp
## Notes: Assisted Combat overlay with Paladin corrections. Hybrid successor to the retired Hekili engine.
## SavedVariables: HekiliMidnightDB

Midnight\Engine.lua
```

Note: legacy files stay in the repo but are no longer loaded. `Bindings.xml` is auto-loaded by the client; its handlers reference legacy functions only on keypress — acceptable for now.

- [ ] **Step 3: Write `Midnight/Engine.lua` (skeleton + probe)**

```lua
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
```

- [ ] **Step 4: Append 12.x globals to `.luacheckrc`**

Open `.luacheckrc`, find the `read_globals` (or `globals`) table and append (create `read_globals` if absent):

```lua
-- 12.x Midnight module APIs
"C_AssistedCombat", "C_Spell", "C_Secrets", "C_RestrictedActions",
"UnitHealthPercent", "UnitPowerPercent", "UnitPower", "UnitClassBase",
"GetSpecialization", "GetSpecializationInfo", "GetBuildInfo",
"CreateFrame", "UIParent", "GetActionInfo", "GetBindingKey",
"HasAction", "IsShiftKeyDown", "Enum", "SlashCmdList", "wipe",
```

Also add (top level of the file): `globals = { "SLASH_HEKILIMIDNIGHT1", "HekiliMidnightDB" }` — merge into an existing `globals` table if one exists.

- [ ] **Step 5: Run luacheck**

Run: `luacheck Midnight/ --no-color`
Expected: `Total: 0 warnings / 0 errors in 1 file`

- [ ] **Step 6: Commit**

```bash
git add Hekili.toc Midnight/Engine.lua .luacheckrc
git commit -m "feat: boot thin Midnight module on 12.x with /hkm probe"
```

- [ ] **Step 7: USER CHECKPOINT (in game)**

1. Symlink/copy repo as `Interface/AddOns/Hekili`, enable addon, log into the 12.x client.
2. `/dump select(4, GetBuildInfo())` — if not `120105`, fix the TOC and recommit (`fix: correct interface version`).
3. No Lua errors on load (`/console scriptErrors 1` beforehand).
4. On a target dummy with Assisted Combat available: `/hkm` prints a spell name.

---

### Task 2: Engine polling loop + listener API

**Files:**
- Modify: `Midnight/Engine.lua`

**Interfaces:**
- Consumes: `ns.Corrections.Apply(baseSpellID)` — defined in Task 5; until then Engine must call it only if present.
- Produces: `Engine.RegisterListener(fn)` where `fn(rec)` and `rec = { spellID = number|nil, corrected = boolean, ruleID = string|nil }`; Engine fires listeners only when `rec` content changes; polling starts at `PLAYER_LOGIN`.

- [ ] **Step 1: Extend `Midnight/Engine.lua`**

Insert below `Engine.GetBaseSpell()` (keep the slash handler at the end of the file):

```lua
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
```

- [ ] **Step 2: Run luacheck**

Run: `luacheck Midnight/ --no-color`
Expected: `Total: 0 warnings / 0 errors in 1 file`

- [ ] **Step 3: Commit**

```bash
git add Midnight/Engine.lua
git commit -m "feat: engine polling loop with change-detection listeners"
```

---

### Task 3: Display — movable icon fed by the Engine

**Files:**
- Create: `Midnight/Display.lua`
- Modify: `Hekili.toc` (append `Midnight\Display.lua` after Engine line)

**Interfaces:**
- Consumes: `ns.Engine.RegisterListener(fn)`, `rec` shape from Task 2.
- Consumes (optional): `ns.Keybinds.ForSpell(spellID) -> string|nil` — Task 4; guard with `if ns.Keybinds`.
- Produces: `HekiliMidnightDB = { point, relPoint, x, y, scale }`.

- [ ] **Step 1: Write `Midnight/Display.lua`**

```lua
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
```

- [ ] **Step 2: Append to `Hekili.toc`** — file list becomes:

```
Midnight\Engine.lua
Midnight\Display.lua
```

- [ ] **Step 3: Run luacheck**

Run: `luacheck Midnight/ --no-color`
Expected: `Total: 0 warnings / 0 errors in 2 files`

- [ ] **Step 4: Commit**

```bash
git add Midnight/Display.lua Hekili.toc
git commit -m "feat: movable recommendation icon display"
```

- [ ] **Step 5: USER CHECKPOINT (in game)**

1. `/reload`; no errors; no icon out of combat without a recommendation.
2. Attack a target dummy: icon appears and switches spells as you cast (matches Blizzard's own assisted highlight).
3. SHIFT-drag moves the icon; position survives `/reload`.

---

### Task 4: Keybind resolver

**Files:**
- Create: `Midnight/Keybinds.lua`
- Modify: `Hekili.toc` (insert `Midnight\Keybinds.lua` before Display line)

**Interfaces:**
- Produces: `ns.Keybinds.ForSpell(spellID) -> string|nil` (e.g. `"3"`, `"S-F"`); rescans on `ACTIONBAR_SLOT_CHANGED` and `UPDATE_BINDINGS`.

- [ ] **Step 1: Write `Midnight/Keybinds.lua`**

```lua
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
```

Known limitation (accepted): covers default Blizzard bars only; ElvUI/Bartender custom bindings come later with the UX stage.

- [ ] **Step 2: Update `Hekili.toc`** — file list becomes:

```
Midnight\Engine.lua
Midnight\Keybinds.lua
Midnight\Display.lua
```

- [ ] **Step 3: Run luacheck**

Run: `luacheck Midnight/ --no-color`
Expected: `Total: 0 warnings / 0 errors in 3 files`

- [ ] **Step 4: Commit**

```bash
git add Midnight/Keybinds.lua Hekili.toc
git commit -m "feat: action bar keybind resolver for display icons"
```

- [ ] **Step 5: USER CHECKPOINT (in game)**

`/reload`, attack dummy: recommended spell that sits on your action bar shows its keybind on the icon (e.g. `3`, `S-F`).

---

### Task 5: Corrections pipeline + safe accessors

**Files:**
- Create: `Midnight/Corrections.lua`
- Modify: `Hekili.toc` (insert `Midnight\Corrections.lua` after Engine line)

**Interfaces:**
- Consumed by Engine (Task 2 already calls it when present) and by Paladin rules (Task 6).
- Produces:
  - `ns.Safe.HealthPercent(unit) -> number|nil` (0–100)
  - `ns.Safe.Power(powerEnum) -> number|nil`
  - `ns.Safe.SpecID() -> number|nil` (e.g. 65/66/70)
  - `ns.Corrections.RegisterRule(specID, { id = string, priority = number, spell = number, when = function() -> boolean })`
  - `ns.Corrections.Apply(baseSpellID) -> spellID, ruleID|nil` — lowest `priority` number wins; rule errors disable that rule after 3 failures.

- [ ] **Step 1: Write `Midnight/Corrections.lua`**

```lua
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
        local idx = GetSpecialization()
        return idx and (GetSpecializationInfo(idx))
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
```

- [ ] **Step 2: Update `Hekili.toc`** — file list becomes:

```
Midnight\Engine.lua
Midnight\Corrections.lua
Midnight\Keybinds.lua
Midnight\Display.lua
```

- [ ] **Step 3: Run luacheck**

Run: `luacheck Midnight/ --no-color`
Expected: `Total: 0 warnings / 0 errors in 4 files`

- [ ] **Step 4: Commit**

```bash
git add Midnight/Corrections.lua Hekili.toc
git commit -m "feat: fail-open correction rule pipeline with safe accessors"
```

---

### Task 6: Paladin correction rules (specs 65 Holy / 66 Prot / 70 Ret)

**Files:**
- Create: `Midnight/Paladin.lua`
- Modify: `Hekili.toc` (insert `Midnight\Paladin.lua` after Corrections line)

**Interfaces:**
- Consumes: `ns.Corrections.RegisterRule`, `ns.Safe.*` (Task 5 signatures).

- [ ] **Step 1: Verify spell IDs against legacy data**

Run:
```bash
grep -n "word_of_glory\b" TheWarWithin/PaladinRetribution.lua | head -3
grep -n "shield_of_the_righteous\b" TheWarWithin/PaladinProtection.lua | head -3
grep -n "templars_verdict\b\|divine_storm\b" TheWarWithin/PaladinRetribution.lua | head -6
```
Expected: registration blocks containing `id = 85673` (Word of Glory), `id = 53600` (Shield of the Righteous), `id = 85256` (Templar's Verdict), `id = 53385` (Divine Storm). If the legacy files show different IDs, use the legacy values in Step 2.

- [ ] **Step 2: Write `Midnight/Paladin.lua`**

```lua
-- Paladin.lua
-- Correction rules for Holy (65), Protection (66), Retribution (70).
-- Only readable-in-combat data: Holy Power (secondary resource), health percent.

local _, ns = ...

if UnitClassBase("player") ~= "PALADIN" then return end

local Safe, Corrections = ns.Safe, ns.Corrections

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
```

Note: `DIVINE_STORM` (53385, AoE finisher) is deliberately absent — choosing it over Templar's Verdict needs enemy count, which is secret in 12.x. Revisit in the UX stage with a manual AoE toggle.

- [ ] **Step 3: Update `Hekili.toc`** — final file list:

```
Midnight\Engine.lua
Midnight\Corrections.lua
Midnight\Paladin.lua
Midnight\Keybinds.lua
Midnight\Display.lua
```

- [ ] **Step 4: Run luacheck**

Run: `luacheck Midnight/ --no-color`
Expected: `Total: 0 warnings / 0 errors in 5 files`

- [ ] **Step 5: Commit**

```bash
git add Midnight/Paladin.lua Hekili.toc
git commit -m "feat: paladin correction rules for holy/prot/ret"
```

- [ ] **Step 6: USER CHECKPOINT (in game, Paladin, target dummy)**

1. `/reload`; no errors on load or in combat.
2. Retribution: build to 5 Holy Power without spending — icon switches to Templar's Verdict and shows the orange corner marker.
3. Drop below 35% health (dummy that hits back / fall damage) with 3+ Holy Power — icon shows Word of Glory + marker.
4. Spend Holy Power — marker disappears, base Blizzard recommendation returns.
5. `/hkm` still prints the base (uncorrected) spell — confirms fail-open path intact.
6. Run one dungeon/delve pull: zero Lua errors.

---

## Post-plan

**Known deviation from spec:** the display shows only the *current* recommendation — `GetNextCastSpell()` returns a single spell, so the spec's "current + next" queue has no reliable data source yet. Deferred to the UX stage (investigate `C_AssistedCombat.GetRotationSpells()` there).

**Additional accepted deviations (recorded at final review):**
- The spec's `C_RestrictedActions` self-disable requirement is approximated by fail-open accessors (nil → rules don't fire); explicit restriction detection deferred to the UX stage.
- Display mouse interception is combat-gated (`PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED`) instead of a lock/unlock command — chosen at final review.
- `Bindings.xml` verified a non-issue: all bindings are commented out upstream (commit `3cf4d1c6`), nothing references legacy globals.

After all tasks pass: push `midnight`, then decide stage 3 (UX: toggles, display styles, options) as a separate spec/plan iteration.
