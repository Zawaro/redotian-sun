# TS-hardcode audit — findings and resolutions

Scope: `scripts/core/`, `scripts/components/`, `scripts/entities/`, `scripts/ui/`, `scripts/hud/`.
Discovery: codebase-memory-mcp graph + grep + full-file reads. Resolution keys:
**GF** = GlobalRules field, **FF** = GameDefinition feature flag, **ED** = EntityData flag/field,
**DATA** = already data-driven, **RENAME** = rename/doc only, **FOLLOW** = deferred follow-up issue.

## Core

| # | Location | TS assumption | Resolution |
|---|----------|---------------|------------|
| 1 | `PowerBar.gd:11,15` | fixed 2000 / 0.4 power scale | **GF** `power_bar_max_output`, `power_bar_curve_exponent` |
| 2 | `CombatComponent.gd:26,426` | ROF divided by 30 | **GF** `logic_fps` |
| 3 | `DockUnloadComponent.gd:5` | unload rate 2.0 hardcoded | **GF** `refinery_unload_rate` (sentinel default) |
| 4 | `ProjectileController.gd:21,180` | 60 deg/s per ROT unit | **GF** `homing_turn_per_sec_per_unit` |
| 5 | `HarvestComponent.gd:9,11` | `["tiberium"]` default, dead radius field | **ED** `harvestable_categories` + `configure`; dead radius removed |
| 6 | `MovementController.gd:23,207-213` | `Track`/`Wheel` id match for slope | **DATA** on `Locomotor.uphill_factor/downhill_factor` |
| 7 | `SelectComponent.gd:345,387,405`, `EconomyManager.gd:6`, `BuildingManager.gd:520` | HUD storage / economy / sell-refund category `"tiberium"` | **GF** `primary_resource_category` (last-known fallback in EconomyManager) |
| 8 | `EconomyManager.gd:6` | default category `"tiberium"` | **GF** `primary_resource_category` |
| 9 | `EntityFactory.gd:199,233,492,503`, `EntityPlacer.gd:306` | branch on `"tiberium_tree"` / `"tiberium"` | **ED** `resource_spawner`, `procedural_resource_visual` |
| 10 | `EntityFactory.gd:571` | ice detected by `legacy_id` `ICE` prefix | **ED** `breakable_surface` + **FF** `breakable_ice` |
| 11 | `IceComponent.gd`, `Pathfinder.gd:202-226`, `MovementController.gd:1103` | ice mechanic always on | **FF** `breakable_ice` |
| 12 | `ResourceGrowthSystem.gd` | tree-seeded growth always on; `tib_*` names | **FF** `resource_tree_regrowth`; **RENAME** `res_*` |
| 13 | `TerrainCatalog.gd:10-12` | fallback GLB hardcoded to `games/ts` | **DATA** `GameDefinition.fallback_terrain_scene` |
| 14 | `GlobalRules.gd:44,156-158` | inert `weed_capacity`/`visceroids`/`meteorites`/`crew_escape` | **FOLLOW** (fields removed) |
| 15 | `TerrainSystem.gd:45-48` | `SLOPE_FAMILIES` enumerates TS art ids | **FOLLOW** (needs a terrain-object slope marker) |
| 16 | `TerrainSystem.gd:6-8`, `CellUtil.gd:3` | `CELL_SIZE`, `HEIGHT_STEP`, `MAX_HEIGHT`, 50×50 | **FOLLOW** (map-format constants) |
| 17 | `GameContext.gd:15` | default game `"ts"` | **FOLLOW** (boot policy) |
| 18 | `Minimap.gd:14-15` | duplicated land-type literals | **RENAME** (dedupe) |

## Components / entities

| # | Location | TS assumption | Resolution |
|---|----------|---------------|------------|
| 19 | `ResourceComponent.gd:3`, `ResourceTreeComponent.gd:6` | default `"tiberium_green"` | **ED** neutral `""` default |
| 20 | `ResourceComponent.gd:87` | tiberium-green fallback colour | **ED** drop tinted fallback |
| 21 | `ResourceComponent.gd:46-95,185-195` | hardcoded 3-stage crystal cubes | **FOLLOW** (art-data migration) |
| 22 | `HarvestComponent.gd` | tiberium-only default + no `configure` | **ED** (see #5) |
| 23 | `SpecialAbilityComponent.gd:29-49` | every active ability a TODO | **FOLLOW** (one issue per ability) |
| 24 | `EntityData.gd` schema-first stubs | TS unit behaviors assumed universal | **FOLLOW** (data-only; not hardcodes) |
| 25 | `Glossary` terms `bale`/`crystal`/`tree` | TS vocabulary | **RENAME** declined — canonical project terms |

## UI / HUD

| # | Location | TS assumption | Resolution |
|---|----------|---------------|------------|
| 26 | `PowerBar.gd:3` + `Sidebar.tscn:102` | power bar unconditional | **DATA** — every C&C game has a power meter; scale is data (#1). Flag invented then removed. |
| 27 | `Sidebar.gd:5-11` + `Sidebar.tscn:58-88` | fixed TS tab set/mapping/rank | **DATA** `GameDefinition.sidebar_tabs` (filtering + sort ranking), hotkeys index-based |
| 28 | `MainMenu01.tscn:3` | TS background asset in shared scene | **DATA** `GameDefinition.menu_background` |
| 29 | `MainMenuItem01.gd:25-27` | TS cyan palette | **DATA** `GameDefinition.menu_accent_color` |
| 30 | `scenes/ui/MainMenu01_old.tscn` | dead TS-asset scene | **RENAME** deleted |
| 31 | `DebugMenu.gd:225` | credit grant tagged `"tiberium"` | **GF** active primary category |
| 32 | `Sidebar.gd:259,444`, `MouseHandler.gd:295,473`, `Minimap.gd:528` | TS comments | **RENAME** |

## Follow-up issues

Audit-surfaced code items and deferred mechanics, filed under #374 and linked from #381:

- #418 derive terrain slope tile families from catalog data (finding 15)
- #419 extract map-format constants from core (finding 16)
- #420 move resource crystal visuals to art data (finding 21)
- #421 neutral default game and boot policy (finding 17)
- #422 mind control
- #423 cloning
- #424 tech buildings and tech-level unlocks
- #425 prism and tesla chaining
- #426 ion storm / dynamic weather
- #427 visceroids / tiberium lifeforms
- #428 meteorite showers

Already tracked elsewhere: superweapons (#244, #265), remaining special abilities (#35),
crew escape / survivor death effects (#186), tiberium visuals (#74).
