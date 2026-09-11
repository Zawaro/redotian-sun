## 1. Data

- [x] 1.1 Add `@export var bales_per_cell: float = 1.0` to `scripts/data/ResourceType.gd` (Resource Type group)
- [x] 1.2 Set `bales_per_cell = 11` on `games/ts/resource_types/tiberium_green.tres`, `tiberium_blue.tres`, `tiberium_red.tres`
- [x] 1.3 Set `harvester_fill_rate = 1.667` in `games/ts/global_rules.tres`

## 2. ResourceComponent bale model

- [x] 2.1 Add bale-capacity resolution on `ResourceComponent` (look up `ResourceType.bales_per_cell` via `GlobalRules`/`EntityFactory`, default `1.0`) and bale/health conversion helpers
- [x] 2.2 `get_amount()` returns remaining bales; `get_max_amount()` returns the cell's `bales_per_cell`
- [x] 2.3 `collect(bales)` removes the requested bales, mirrors the remainder onto health via `roundi`, clamps to remaining, returns bales actually removed, and still self-frees at 0 bales
- [x] 2.4 `reset_health`/regrowth path leaves bale capacity intact (no change required; verify)

## 3. Conversion call sites

- [x] 3.1 `ResourceGrowthSystem._spawn_at_cell` seeds spawned-cell health through the bale-capacity conversion
- [x] 3.2 `ResourceGrowthSystem._grow_entry` / `_process_resource` growth stays ratio-based (no double scaling) and reports bales via the component
- [x] 3.3 `ResourcePainter._paint_resource_cell` / `_erase_resource_cell` add/remove bales through the conversion

## 4. Dock unload

- [x] 4.1 In `DockUnloadComponent._process`, call `dock.reset_stale_timer()` each frame while actively draining (after the dock/docker validity guards)
- [x] 4.2 Set `DockUnloadComponent.unload_rate` default to `2.0`
- [x] 4.3 Confirm `DockUnloadComponent.begin_unload()` keeps its one-time reset for the rotation-to-unload handoff

## 5. Tests (behavior-first)

- [x] 5.1 Regression that fails before the fix: a full 28-bale docked cargo at `stale_timeout = 5.0` deposits all 28 bales, credits == 700, and no `dock_timeout` is emitted (`test/unit/test_harvest_dock.gd`)
- [x] 5.2 Regression that fails before the fix: a ripe tiberium cell yields exactly 11 bales when harvested one bail at a time (`test/unit/test_resource_component.gd`)
- [x] 5.3 A harvester fills to `storage = 28` after draining two full cells plus 6 bales of a third
- [x] 5.4 Default (`bales_per_cell = 1.0`) bare-component behavior unchanged (existing assertions stay green)
- [x] 5.5 Growth/spread seeds at `spread_amount / bales_per_cell` health ratio (`test/unit/test_resource_growth_system.gd`)
- [x] 5.6 `global_rules.tres` `harvester_fill_rate` ~1.667 and `DockUnloadComponent` unload rate default ~2.0 (`test/unit/test_global_rules.gd`)

## 6. Verification

- [x] 6.1 `redot --headless -s test/run_tests.gd` - full suite passes
- [x] 6.2 `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; run `grep -P '\t' scripts/**/*.gd` to confirm no tabs
- [ ] 6.3 In-editor sanity: fill a harvester from a tiberium field (~2.5 cells) and watch a full load deposit 700 credits without the harvester being kicked out early
