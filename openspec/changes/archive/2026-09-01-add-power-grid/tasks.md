# Tasks — Add Power Grid

## 1. Rules & Component Runtime State

- [x] 1.1 Add `worst_low_power_build_rate_coefficient: float = 0.3` and `best_low_power_build_rate_coefficient: float = 0.75` exports to GlobalRules "Production and Power Effects" group; unit test defaults and resource override (global-rules spec)
- [x] 1.2 Extend PowerComponent: runtime `is_online` (default true), `set_online(bool)` emitting `power_state_changed(is_online)` only on change; unit test emit-once-on-change, silent no-op, independence from data `powered` flag

## 2. PowerGrid Autoload

- [x] 2.1 Create `scripts/core/PowerGrid.gd` autoload: tree `node_added`/`node_removed` registration (connect in `_enter_tree`, SpatialHash ordering precedent), filter to nodes with a `PowerComponent`; commit the `.uid` file with the script
- [x] 2.2 Per-player aggregation: ownership via `StatsComponent.player_id`; neutral handling for entities with unset `player_id`; skip entities under map-editor-flagged roots; unit test per-player isolation, MapLoader-path entity, DeployComponent-path entity
- [x] 2.3 Recompute + diff on registry change: boundary crossing fans out `set_online()` to affected `powered = true` components only; rate drift emits `grid_state_changed(player_id)`; no-op changes emit nothing; unit test boundary cross, rate drift, silence, and map-load starting base shutdown
- [x] 2.4 Build-rate + totals queries: `get_build_rate(player_id)` (1.0 healthy / `lerp(worst, best, clamp(output/drain, 0, 1))` in deficit / 1.0 when drain = 0), `get_output(player_id)`, `get_drain(player_id)`; unit test the ratio edge cases from the power-grid spec
- [x] 2.5 Register `PowerGrid` in `project.godot` autoloads

## 3. Consumer Integration

- [x] 3.1 CombatComponent: local offline gate at top of `_physics_process` (sibling `PowerComponent.is_online`, missing component → unchanged); target retained across offline; tests: holds fire offline, resumes on restore, no-PowerComponent regression
- [x] 3.2 RadarComponent: `has_radar()` returns false while offline; test offline → false, online → data flag
- [x] 3.3 ArtComponent: subscribe `power_state_changed` — pause `active_anims` on false, resume on true (existing `set_process` toggles); test pause/resume transitions
- [x] 3.4 ProductionManager: multiply `_get_production_speed` by `PowerGrid.get_build_rate(player_id)` (fallback 1.0 when PowerGrid absent); connect `grid_state_changed` → `_speed_cache.clear()`; tests: deficit slowdown matches interpolation, recovery restores, cache invalidation fires

## 4. Selected-Producer Label

- [x] 4.1 SelectionOverlay: in the existing `_do_draw` loop, draw green `"{draw}/{supply}"` centered in `bracket_rect` for selected entities whose `PowerComponent.power > 0`, reading live totals from PowerGrid; test draw decision logic (producer+selected → drawn; consumer, hovered-only, power = 0 → not drawn)
- [x] 4.3 Fix: `_collect_entities` skipped `select_box_type == Structure` entirely, starving the label for buildings — structures are now collected with overlay brackets/health bars/pips suppressed (buildings render SelectComponent's 3D wireframe box); `_collect_entities` clears at entry so direct test calls are order-independent; regression tests in test_selection_overlay.gd
- [x] 4.4 Label format per issue feedback: two-line green `POWER = {output}` / `DRAIN = {drain}` via `draw_multiline_string`; update decision-logic test expectations
- [ ] 4.2 In-editor visual check: select a power plant, sell a producer, confirm label updates live

## 5. Data Pass

- [x] 5.1 Verify the TS `rules.ini` `Powered=yes` structure set; set `powered = true` on those structure `.tres` files (candidates: both radars, stealth generator, firestorm generator, missile silo, temple of nod, upgrade center, laser fence posts)
- [x] 5.2 Integration test: load a map with a starting base, destroy a power plant → deficit triggers; radar offline, turret holds fire, anims pause; build rate slows; recover by placing a plant → all resume

## 6. Wrap-up

- [x] 6.1 Run `redot --headless -s test/run_tests.gd` (full suite green), `gdlint` + `gdformat --check`, and the post-format tab grep on touched files
- [x] 6.2 `openspec validate --change add-power-grid` passes; glossary Power entries verified against implemented behavior

## 7. Sidebar Power Bar & Tooltips

- [x] 7.1 `scripts/ui/PowerBar.gd` (Control): black column backing a green output fill with a red drain fill drawn in front, bottom-aligned and clamped; static `_ratios(output, drain)` against a fixed `MAX_POWER = 2000`; per-frame pull of `PowerGrid.get_output/get_drain(PlayerManager.get_local_player_id())`; unit tests for known values, clamping, and the drain ≥ output invariant
- [x] 7.2 Host `%PowerBar` on the left edge of `scenes/ui/Sidebar.tscn` (spanning the cameo panel height) and inset the panel so icons start right of the bar; commit the generated `.uid`
- [x] 7.3 Cameo tooltips append signed `Power: %+d` when `EntityData.power != 0`; tests for producer (+100), consumer (−50), and power = 0 (no line) cases
- [x] 7.4 Fill curve `(value/2000)^0.4` per issue feedback (single plant ≈ 30% of the bar, not 5% linear) and eased fill animation — frame-rate-independent exponential lerp (rate 8/s) with snap-on-arrival; grid lookup via `get_node_or_null("/root/PowerGrid")` matching the consumer convention (global-name resolution failed in stale editor sessions); tests for curve values, NaN-safe clamping, and ease convergence
