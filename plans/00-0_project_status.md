# Project Status Report — Redotian Sun

**Last verified:** 2026-08-08
**Engine:** Redot 26.2 LTS (Forward Plus renderer)
**Language:** GDScript only
**Project state:** Core Systems complete — mission layer greenfield

## Overview

Redotian Sun has shipped the full gameplay foundation: a data-driven entity system (~408 `.tres` files, ~22 components), base building, a complete economy/harvest loop, unit production with prerequisites, custom grid A* pathfinding with 9 locomotors, hitscan combat with warhead×armor damage, a terrain system with heightfield + land types + movement costs, a working MapEditor, a live AudioManager with voice hooks, and a healthy test suite (74 files, 4364 asserts, green).

The next milestone is **GDI Mission 01** (Tiberian Sun's first GDI mission). The mission layer — triggers, objectives, briefing, scripted teams, win/lose — is entirely unbuilt, as is fog of war. Those are the critical blockers.

## System Status Breakdown

| Area | Done | Notes |
|------|------|-------|
| Foundations & harness | 95% | 22 autoloads, MainScene, CI green |
| Grid / primitives | 95% | CellUtil, BoundsSystem, SpatialHash, rectangular+diamond maps |
| Data & rules (.tres) | 90% | EntityData, 408 entities, 44 weapons, 27 warheads, GlobalRules |
| Object model & world grid | 90% | EntityFactory, 22 components, placement, occupancy, crush |
| Movement & locomotion | 85% | Grid A*, splines, 9 locomotors, repulsion, jumpjets, ice |
| Terrain & map systems | 80% | Heightfield, renderer, land types, movement costs; water/bridge render + authoring missing |
| Testing & CI | 80% | 74 files, 4364 asserts, lint+format+openspec gate (CI pins old 26.1) |
| MapEditor tooling | 60% | Height/resource/entity tools; no undo, land-type paint, theater, player starts |
| Unit & building sim | 60% | Production, deploy, prereqs, dock; power grid (#33), upgrades, batch missing |
| Economy | 55% | Full harvest→dock→credits; silo storage + income tracking missing |
| Combat (weapons/firing) | 50% | Hitscan + warhead×armor works; projectiles, turret, splash unused |
| Shell / UI | 45% | Sidebar, credits, cursor, debug menu; no minimap, selection panel, tiberium HUD, pause, menu→game flow |
| Audio | 40% | AudioManager+voices done; music + EVA 0; content gitignored (fresh clone = silent) |
| Presentation / rendering / VFX | 40% | Async models, MultiMesh, shadows; no explosions/death FX, water, cliff tiling, bridges |
| Save/load & game loop | 30% | Map loading works; no save/load, pause, or mission entry point |
| Faction & skirmish AI | 15% | Faction `.tres` only; no AI, no special-ability logic |
| Campaign / scenario (missions) | 5% | MapConfig/PlayerManager hooks only; triggers, objectives, briefing, scripted teams all greenfield |
| Fog of war / vision | 0% | `GlobalRules.fog_of_war` flag unused; entire system missing |
| Multiplayer / netcode | 0% | Zero network code |
| Modding | 10% | `register_data_set()` scaffold only |

**Overall:** ~45% toward a playable GDI Mission 01; ~38% toward a complete skirmish RTS.

## What Is Implemented (verified)

### Entity System — complete
- `scripts/data/EntityData.gd` — single resource class (identity, stats, combat, movement, foundation, dock, transport, deploy, prereqs, build menu, special abilities).
- `scripts/entities/EntityFactory.gd` — autoload, scans `resources/entities/`, attaches 22 components dynamically, wires death voice + cleanup.
- `scripts/entities/EntityPlacer.gd` — spawns with player_id; used by factory/exit/free-unit paths.
- Roster: **408 `.tres`** — 26 infantry, 38 vehicles, 168 buildings, 8 aircraft, 44 terrain, 84 overlay, 40 smudge. 73 buildable. Roughly TS-complete.

### Base Building — complete (placement layer)
- `BuildingManager.gd` — build mode, ghost preview, per-cell validation (bounds, cells, terrain height/flatness), placement via EntityFactory, sell (50% refund), repair (flat heal), destroy cleanup (unregisters cells + prereqs).
- **Missing:** power grid (Issue #33), territory restriction, upgrade states.

### Economy & Resources — complete (harvest loop)
- `EconomyManager.gd` (ledger), `PlayerManager.gd` (per-player identity/teams).
- Full loop: `HarvestComponent` → `DockClientComponent` → `DockHostComponent` → `DockUnloadComponent` → credits. `ResourceGrowthSystem` (batched tree/crystal growth + spread). `FreeUnitComponent` (free harvester on refinery).
- **Missing:** silo-based storage capacity (hardcoded 2000), income tracking, AI build-ratio, dock-based repair.

### Unit Production — complete
- `ProductionManager.gd` (per-player per-queue queues, gradual deduction, factory speed bonus), `PrerequisiteSystem.gd` (build limits, OR/AND prereqs, factory ownership), `FactoryComponent` + `ExitComponent` + `RallyPointComponent`.
- Sidebar: 4 tabs (Buildings/Infantry/Vehicles/Special), 5×3 cameo grid, angular progress shader, credits label.
- **Missing:** batch production, queue reordering, real shift-queue (flag is cosmetic), research/upgrades.

### Navigation & Movement — complete (Phase 2 quality)
- `Pathfinder.gd` — custom grid A* (8-dir binary heap, terrain cost via Locomotor, height-climb tolerance, bib penalty, ice-as-footing, LOS string-pulling, best-reached fallback). NavigationServer3D is **not** used.
- `MovementController.gd` (~1000 lines) — states, Catmull-Rom splines, radial repulsion, **9 locomotors**, crushing, ice cracking, sub-slot cell sharing, jumpjet vertical state machine, wait-state scatter.
- Order pipeline: `OrderSystem` → `OrderGenerator` hierarchy → `OrderResolver` → per-component `get_order_for_target()`.
- **Missing:** attack-move, patrol, formations menu, group hotkeys 1–0.

### Combat — hitscan MVP complete
- `CombatComponent.gd` — chase-to-range, cooldowns, hitscan damage, warhead×armor multipliers (`GlobalRules.get_warhead_armor_multiplier`), veteran bonus, fire sounds, jumpjet air approach.
- `HealthComponent.gd` — damage/heal/health_zero; death wired to cleanup + voice.
- `WarheadData` (27), `WeaponData` (44), `ArmorType` (5) all live and tested.
- **Missing:** runtime projectiles (#78, ProjectileData schema exists only), turret rotation, splash/AoE, and **all combat AI** (auto-engage, guard, threat scoring — zero).

### Terrain & Maps — foundation complete
- `TerrainSystem.gd` (heightfield, cascade smoothing, land types, JSON v4), `TerrainRenderer.gd` (MultiMesh per submesh), `TerrainCatalog.gd` + isotem tooling (130+ terrain objects), `CellUtil`, `BoundsSystem` (red/blue diamonds, 4-inset visible bounds), `MapLoader.gd`, `SpatialHash` (blocked/building/bib/resource/ice cells).
- Water (land type only, no render/paint), ice (works), cliffs (height-driven), bridges (data-only stubs, no component), tiberium growth/harvest (works).
- MapEditor: File menu, height paint, resource paint (radius brush), tree place, erase, entity placement (buildings/units), grid, minimap. **Missing:** undo/redo, land-type paint, water, theater selection, player starts, terrain/overlay categories in browser.

### Audio — system complete, content blocked
- `AudioManager.gd` — 4 buses (Master/Music/SFX/Voice), recursive `.tres` scan, spatial falloff, `play_voice` at camera.
- Hooks: select/order/weapon-fire/death voices. `VoiceData` (5 event arrays) on 15 entities.
- **Blocked:** 275 `.ogg` under gitignored `external_assets/` — fresh clone has zero audio. Music: 0 files, no system. EVA: 0.

### UI — partial
- **Done:** camera (pan/zoom/edge-scroll, no rotate), selection (single/box/shift/hover + overlay brackets/bars/pips), OrderSystem cursors, tabbed sidebar, credits label, debug menu, input routing, FPS counter.
- **Missing:** gameplay minimap, selection/info panel, tiberium/power/income HUD, pause, save/load, settings screens, faction selection, menu→game flow (MainScene has empty Gameplay node; only "Exit" works).

### Rendering
- Async/batch model loading (`BatchLoader`, `ArtComponent`, pre-warmers), `UnitMeshRenderer` (per-region MultiMesh), `ModelBaker`, shadows per spec. Open perf issues: #221 (SDFGI spike), #222 (shadow grain). Orphaned dead code: `PixelArtManager`, `EntityMaskManager`, `PixelArtOutline01.gdshader`.

### Testing & CI — strong
- 74 test files, 777 methods, **4364 asserts, 0 failures, ~7.7s**.
- CI: lint (gdtoolkit) + format + test + openspec-archive gate. **Skew:** CI pins Redot 26.1, repo on 26.2.
- OpenSpec: 63 specs, zero open changes, archive discipline clean.

## GDI Mission 01 — Readiness & Gap Analysis

**Milestone:** `GDI Mission 01: Reinforce Phoenix Base` (milestone #1) — two-tier: **MVP tier** (playable build & destroy loop) + **completionist tier** (`milestone-tier2` label). Umbrella: #260. New gap issues: #260–#268.

**MVP tier issues:** #262 (menu→map) · #261 (guard/auto-engage AI) · #236 (mission boot) · #237 (trigger engine) · #240 (objectives/win-lose) · #247 (entity placement) · #264 (attack-move) · #226–#234 (authentic map: importer, land-type paint, water, cliffs, bridges, buildout, waypoints) · #245 (Component Tower defense, guard tower passive) · #246 (radar) · #255 (music) · #258 (EVA).

**Completionist tier (`milestone-tier2`):** #235 terrain art · #238 scripted TaskForce AI · #239 reinforcements · #241 cinematic · #243 SFX · #244 meteor · #248 trigger wiring · #249/#250 FX · #251/#252/#253 assets · #254 playtest.

### Critical-path blockers (engine systems, not content)

```
#236 mission boot  ──→  #237 trigger engine  ──→  #240 objectives/win-lose
        │                       │                        │
        └──────── map build ─────┴───── #232/#233 (content)
                 (hand-built JSON works today;
                  authentic falls/river/bridge
                  geography needs #228–#231)
```

1. **Mission boot (#236)** — partial hooks (MapConfig + PlayerManager credits + MapLoader) exist; no entry point, no briefing, no start-camera placement.
2. **Trigger/event/action engine (#237)** — nothing exists. Largest new subsystem.
3. **Objectives + win/lose (#240)** — nothing exists; depends on #237.
4. **Map build-out (#232/#233)** — hand-buildable via raw JSON today (land types + pathfinding already work in-game); editor can't paint them yet (#228–#231).
5. **Entity data + placement (#247)** — mostly content (~13 missing entity types).
6. **Scripted team AI (#238)** — a first playable can ship a static Nod base (the First Blood pattern), deferring scripted teams.

**Shortest viable path:** #236 + #237 (minimal trigger set) + #240 + hand-built map + #247 content → playable "build Refinery + Barracks, destroy all Nod" loop.

**Deferrable for first playable:** radar/minimap (#246), droppods (#239), meteor (#244), FX (#249), bridge destruction (#250), defense weapons (#245), music/EVA (#255/#258), real assets (#235/#243/#251/#252/#253), playtest (#254).

## Documentation Debt

Plans significantly behind the codebase:
- **2-1, 2-2, 3-1, 6-3, 11-1** — describe unbuilt systems that are fully implemented; 3-1 actively contradicts code ("WarheadData does not exist").
- **1-4, 5-2, 6-2, 7-2** — under-report shipped systems.
- **Roadmap** — Phase 2/3.1/6.1 unchecked despite implementation; engine version stale (26.1 vs 26.2); 9.1 says "GUT framework" (rejected — custom runner used).
- **AGENTS.md** — 13 autoloads documented vs 22 actual.
- **Accurate plans:** 3-2, 4-1, 4-2 (correctly unbuilt), 8-1, 8-2, 9-2, 10-1, 1-3, 5-1.

## Related Files

- Roadmap: `plans/project_planning_roadmap.md`
- First Blood goal: `plans/10-1_first_blood_goal.md`
- Per-system plans: `plans/1-1…9-2`
- Capability specs: `openspec/specs/` (63 capabilities)
