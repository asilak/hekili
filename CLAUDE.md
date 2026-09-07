# Hekili — Project Instructions

## Project Status
Retail development **ended January 20, 2026** (Midnight 12.0 prepatch broke the required API).
The `thewarwithin` branch is the final retail state. Treat changes as maintenance/archival unless told otherwise.

## What This Is
World of Warcraft addon (pure Lua + WoW API). A rotation "priority helper" that simulates the
player's future game state and evaluates SimulationCraft-style Action Priority Lists (APLs)
to recommend the next several abilities.

## Tech Stack
- Lua 5.1 (WoW flavor), Ace3 framework (AceAddon/AceConfig/AceDB via LibStub)
- No build step, no package manager for runtime code
- Libraries are **externals**: `.pkgmeta` pulls Ace3 etc. at package time (BigWigsMods/packager).
  Only `Libs/SpellFlashCore` is vendored — do not commit other libs into `Libs/`.

## Load Order & Structure
`Hekili.toc` defines the exact file load order — new files MUST be added there.
- Root: core engine — `Hekili.lua` (bootstrap), `State.lua` (simulated game state, ~8k lines),
  `Classes.lua` (spec/ability/aura registration API), `Scripts.lua` (SimC expression → Lua),
  `Core.lua` (recommendation loop), `Events.lua`, `Targets.lua` (enemy counting), `UI.lua`
- `TheWarWithin/` — one module per spec (`MageFire.lua`), plus `Items.lua`, `Classes.lua`
- `TheWarWithin/Priorities/*.simc` — human-readable APL sources synced from
  github.com/simulationcraft/simc (`thewarwithin` branch); header comments track upstream commit
- `Options/` — AceConfig options UI, chat commands, dev tools
- Legacy expansion data: `BfA/`, `Shadowlands/`, `Dragonflight/`, etc. (loaded per TOC; rarely touched)
- Other expansions live on **separate git branches** (`wrath`, `cataclysm`, `dragonflight`, ...)

## Spec Module Pattern (follow exactly)
1. Class guard first: `if UnitClassBase( "player" ) ~= "MAGE" then return end`
2. `local spec = Hekili:NewSpecialization( <specID> )`
3. Localize hot-path globals (`string.format`, `table.insert`, math fns) at top of file
4. `spec:RegisterResource / RegisterTalents / RegisterAuras / RegisterAbilities / RegisterPack`
5. `RegisterPack` contains an **encoded pack string** — never hand-edit it. It is regenerated
   in-game (import the `.simc` APL, export a pack snapshot). Edit the `.simc` file and Lua
   registrations; the blob is a build artifact.

## Conventions
- File naming: PascalCase `ClassSpec.lua` matching `ClassSpec.simc`
- Keys in registration tables: snake_case (`arcane_warding`), matching SimC tokens
- Commits: short imperative subject; APL updates as `<Spec> APL Sync`; occasional `fix:` prefix
- PRs merge with merge commits (no squash) into `thewarwithin`
- Lint: `.luacheckrc` present — run `luacheck .` if available; no test suite exists
  (do not invent one; verification is in-game)

## CI / Release
- Tag `v*` → `.github/workflows/main.yml` packages via BigWigsMods/packager and publishes
  to CurseForge / WoWInterface / Wago
- `apl-sync-status.yml` (daily cron) diffs `Priorities/*.simc` headers against SimC upstream
  and opens issues when out of sync

## Testing a Change
No automated tests. Copy/symlink the repo into `World of Warcraft/_retail_/Interface/AddOns/Hekili`,
then in-game: `/reload`, `/hekili` for options, Snapshot feature (in options) for APL debugging.

## References
- WoW API reference: https://warcraft.wiki.gg/wiki/World_of_Warcraft_API — canonical docs for the
  `C_*` namespaces used throughout (`C_Spell`, `C_UnitAuras`, `C_SpellBook`, ...), event system, and
  protected-function restrictions. Note: wiki tracks current patch (12.x); this repo targets
  Interface 110205 (11.2.5), so newer namespace changes there may not apply here.
