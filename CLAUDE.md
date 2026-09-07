# Hekili — Project Instructions

## Project Status
This fork (`asilak/hekili`, branch `midnight`) revives the addon on WoW 12.x (Midnight) as a
hybrid: Blizzard's `C_AssistedCombat` recommendations layered with a fail-open correction system.
Upstream retail development on the original Hekili engine ended **January 20, 2026** (the Midnight
12.0 prepatch broke the API the old engine depended on); `thewarwithin` remains its final state.

## Midnight Module (current architecture)
`Hekili.toc` (`## Interface: 120105`, `## SavedVariables: HekiliMidnightDB`) loads **only**
`Midnight/*` — the legacy engine is present in the repo but never loaded:

- `Midnight/Engine.lua` — polls `C_AssistedCombat.GetNextCastSpell()`, runs the result through
  Corrections, notifies listeners; owns the `/hkm` debug slash
- `Midnight/Corrections.lua` — fail-open per-spec rule registry/pipeline + `ns.Safe` accessors
  (`Safe.HealthPercent`, `Safe.Power`, `Safe.SpecID`)
- `Midnight/Paladin.lua` — correction rules for specs 65 (Holy), 66 (Protection), 70 (Retribution)
- `Midnight/Keybinds.lua` — resolves an action-bar keybind string for a spell ID
- `Midnight/Display.lua` — movable icon frame driven by `Engine.RegisterListener`

**Conventions:**
- Fail-open: `pcall` everything that touches a secret or possibly-missing API; the addon must
  never raise a Lua error in combat.
- No external libraries — plain `CreateFrame`, no Ace3.
- Shared namespace: every file starts `local _, ns = ...` (or `local ADDON, ns = ...` where the
  addon name is needed).
- Verification gate: `luacheck Midnight/ --no-color` → `0 warnings / 0 errors in 5 files`.
- Debug in-game via `/hkm` (prints the current base, uncorrected recommendation).

**Design docs:** `docs/superpowers/specs/2026-09-07-hekili-midnight-hybrid-design.md`; plan in
`docs/superpowers/plans/2026-09-07-hekili-midnight-stage1-2.md`.

## Legacy engine (not loaded; reference only)
The rest of the repo is the original Hekili simulation engine, kept only for spell-ID and APL
reference value — none of it is in the Midnight `Hekili.toc` file list.

- Root: `State.lua` (simulated game state), `Classes.lua` (spec/ability registration API),
  `Scripts.lua` (SimC expression → Lua), `Core.lua` (recommendation loop), `Events.lua`,
  `Targets.lua`
- `TheWarWithin/` — one module per spec (e.g. `PaladinRetribution.lua`) plus `Items.lua`; still the
  best source for verified spell IDs (see how `Midnight/Paladin.lua`'s constants were sourced)
- `TheWarWithin/Priorities/*.simc` — APL sources synced from the SimC project
- `Options/` — legacy AceConfig options UI, unused by Midnight
- The old spec-module pattern (class guard → `Hekili:NewSpecialization` → register
  resources/talents/auras/abilities → `RegisterPack` with an encoded, machine-generated blob),
  `.pkgmeta`-vendored Ace3 externals, the `apl-sync-status.yml` daily SimC-sync cron, and the
  tag-triggered BigWigsMods packager release pipeline (`.github/workflows/main.yml`) all still
  exist but are dormant for this branch.

## Testing a Change
No automated test suite; `luacheck Midnight/ --no-color` is the automated gate. In-game: copy or
symlink the repo into `World of Warcraft/_retail_/Interface/AddOns/Hekili`, `/reload`, then use
`/hkm` and combat with a target dummy to confirm recommendations and corrections.

## References
- WoW API reference: https://warcraft.wiki.gg/wiki/World_of_Warcraft_API — canonical docs for the
  `C_*` namespaces (`C_AssistedCombat`, `C_Spell`, `C_SpecializationInfo`, ...), events, and
  protected/secret-value restrictions. Note: the wiki tracks the current live patch; this branch
  targets Interface 120105 (12.x, Midnight), so verify namespace behavior against that build
  rather than assuming wiki parity.
