# 12-0 — Unified Multi-Title Expansion (TS + FS + RA2 + YR)

**Goal:** one data-driven, isometric-3D Redot engine that runs Tiberian Sun, Firestorm,
Red Alert 2, and Yuri's Revenge as per-title content packages.

**Status:** research + planning complete (2026-09-14). No implementation yet.
**Master references:** `docs/capability-matrix.md`, `docs/gap-analysis.md`,
`docs/architecture/unified-engine.md`.

---

## 1. Definition of done

A title is "supported" when:
1. It has a `GameDefinition` at `games/<id>/game.tres` + data sets that load and validate.
2. All rows in `docs/capability-matrix.md` for that title marked `✓` are backed by data,
   and all `SYS` rows they depend on are implemented.
3. A skirmish match against the title's AI is playable; at least one campaign mission boots
   and reaches a win/lose state.
4. Specs exist in `openspec/specs/` for every new generic subsystem used.

## 2. Architecture decision (proposed)

- One **generic engine**; per-title **data packages**.
- Expansion titles are **deltas**, not merges:
  - `games/fs` = delta over `games/ts` (list `ts` root, override/add).
  - `games/yr` = delta over `games/ra2`.
  - `games/ra2` = independent base (the stress test that no TS assumption is baked in).
- Layering is last-wins; same-id collisions across non-borrowing games are validator errors
  (`GameContext.validate_id_collisions` already enforces).
- See `docs/architecture/unified-engine.md` for the layering diagram and data schema targets.

## 2.5 Verified constraints from the deep research pass (must honor)

Source: `docs/research/deep/` (12 exhaustive catalogs + 2 adversarial verification ledgers);
errata in `docs/research/deep/README.md`.

1. **Armor is per-game.** TS = 5 classes (`none,wood,light,heavy,concrete`); RA2/YR = 11
   (`none,flak,plate,light,medium,heavy,wood,steel,concrete,special_1,special_2`). Warhead
   `Verses` is editable in every title (not hardcoded) and its length follows the armor table.
   Build the per-game armor table + variable-length `Verses` **before** RA2 content.
2. **AI actions and animation indices are per-game.** RA2/YR shift TS AI action IDs ≥11 by +1 and
   add 26–32; YR's `[Animations]` array is ~607 entries with a +4 shift bug at #209 (TS = 277).
3. **Patch level is data.** Target YR **1.001**, not the 1.000 mirror (Slave Miner $1750,
   Chaos Drone $1000, Siege Chopper $1100 differ).
4. **Firestorm gating** is `expand01.mix` + `firestrm.ini` detection in the original; a
   `Firestorm=yes` map flag is our design choice, not original behavior.
5. **Cross-engine nuances:** original TS shroud is local-player-only (our per-player system is a
   superset); `CellSpread` is a 3D lepton sphere (3×3 building → 9× per-cell hits); 5 sub-cells
   per cell with a separate bridge mask.
6. **New generic subsystems surfaced by FS** beyond the earlier Tier 2 list: deployable mobile
   structures, limpet attach/slow, mobile EMP charge, web immobilisation, cluster-split rockets,
   levitation locomotion, conditional invulnerability/activation.

## 3. Generic subsystems to build (engine, not content)

Ordered by dependency. Full list with rationale: `docs/gap-analysis.md` §B.

**Tier 1 — unblocks current milestone + basic RTS**
1. Auto-engage / guard / threat targeting
2. Attack-move / patrol / stances
3. Mission runtime: trigger/event/action, objectives, win/lose, waypoints, teams
4. Projectile splash/AoE; veterancy XP; combat VFX

**Tier 2 — the multi-title core (needed by RA2/YR)**
5. Status-effect / aura framework (timed, serializable, DoT, immunity)
6. Superweapon / support-power framework (charge, target modes, effect registry)
7. Entity conversion / transform primitive (generalize deploy → mutate)
8. Garrison / occupancy subsystem (bunkers, civ, fire-from-transport, power hook)
9. Control-link (mind control) manager
10. Weapon state machine (staged/gattling, passenger modes, prism/tesla chains)
11. Armor list generalization (variable-length, data-driven)
12. Side → country → bonus registry
13. Naval movement + water rendering
14. Aerospace: landing/rearm + ammo/reload
15. Economy hooks: refund/recycle, siphon, cost/income modifiers
16. Cloak/stealth + sensors + gap generator + spy satellite
17. Skirmish AI (base build, attack teams, difficulty)
18. Save/load of live game state

**Tier 3 — shell/meta/polish**
19. Control groups, selection panel, stance UI, superweapon charge UI
20. Settings UI, map browser, skirmish setup UI
21. Bridge destruction/repair, wall drag-build & gates, crates, repair bay
22. EVA announcer, music system, ambient/weather particles, score screen
23. Mod manager/load-order, localization
24. Multiplayer/netcode/lobby/replays (deferred, largest)

## 4. Content packages

| Package | Type | Scale | Notes |
|---|---|---|---|
| `games/ts` | base | exists (~408 entities) | fill ability/superweapon/naval/visceroid stubs |
| `games/fs` | delta over ts | +GDI 5, +Nod 3+, +CABAL faction | `Firestorm=yes` scenario gate |
| `games/ra2` | base | 2 sides / 9 countries, full naval+air | ore+gems, 11 armor, no silos |
| `games/yr` | delta over ra2 | +ThirdSide/YuriCountry, full Yuri roster | mind control, bunkers, gattling, Lunar |

## 5. Sequencing

1. Reconcile stale docs (this change) — done.
2. Ship Tier 1 to complete the existing GDI Mission 01 milestone.
3. Lock generic contracts as OpenSpec specs (armor, projectile, status, superweapon, house,
   mission, theater) before authoring new titles.
4. Build Tier 2 in dependency order.
5. Author `games/fs` → validate the delta model.
6. Author `games/ra2` → the TS-assumption stress test.
7. Author `games/yr` → forces Tier 2 to completion.
8. Tier 3 + multiplayer.

## 6. Risks

- **Scope:** four titles is multi-year content volume; keep engine/data separation strict so
  content can proceed in parallel with engine work.
- **Reconciliation cost:** the engine currently bakes TS assumptions (5 armor classes, silo
  storage, no countries). Generalizing late is expensive — do it before RA2 content.
- **Accuracy:** original INIs are the only balance truth; research `[uncertain]` flags must be
  resolved against `rules(md).ini` per title before shipping numbers.
- **Sprawl:** OpenSpec discipline (spec first, archive before merge) must hold for every new
  subsystem or the docs rot again.

## 7. Open decisions (see GLOSSARY Undecided)

- Isometric camera: current 45° ortho vs true 2:1 dimetric.
- Expansion packaging: delta vs merged rule sets.
- Scope of cinematics: camera scripting only vs video playback.
