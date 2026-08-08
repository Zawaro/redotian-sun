## 1. GlobalRules + SpatialHash groundwork

- [x] 1.1 Add `shroud_grows: bool = false` and `shroud_growth_interval: float = 10.0` exports to `scripts/data/GlobalRules.gd` (existing `fog_of_war` stays at `:129`)
- [x] 1.2 Add `SpatialHash.is_building_cell(cell: Vector2i) -> bool` helper derived from existing building-cell tracking

## 2. ShroudSystem core grid

- [x] 2.1 Create `scripts/core/ShroudSystem.gd` with per-player state (`explored`, `visible_count`, `resolved`, `touched`) sized to `TerrainSystem.grid_cells` and re-init on terrain grid change
- [x] 2.2 Implement `register_revealer` / `unregister_revealer` with ref-counted stamp/unstamp (deterministic recompute of the stamped set)
- [x] 2.3 Implement per-cell Bresenham LOS with height-delta and building-cell blocking; air revealers (`blocks_terrain = false`) ignore blockers
- [x] 2.4 Implement dirty-cell resolution on a fixed tick with short-circuit when nothing changed; resolve shroud/fog/visible precedence
- [x] 2.5 Implement queries: `is_visible`, `is_explored`, `get_explored_percentage`, `explore_all`, and allied-union `get_effective_state`
- [x] 2.6 Clamp every reveal path and the explored-percentage denominator to `BoundsSystem.is_in_play_area`
- [x] 2.7 Implement `explore_area` (permanent) and `reveal_area` (temporary, reverts to explored after duration)
- [x] 2.8 Implement shroud growth ticker gated on `GlobalRules.shroud_grows`, one frontier ring per `shroud_growth_interval`, visible cells protected
- [x] 2.9 Register `ShroudSystem` autoload in `project.godot` and update the AGENTS.md autoload table

## 3. Fog-gated interaction filtering

- [x] 3.1 In `OrderSystem.get_cursor` / `get_orders`, treat targets in cells not visible to the local player as null (gated on `fog_of_war`); includes force-fire ground targets
- [x] 3.2 In `MouseHandler._handle_hover_preview`, skip hover preview for targets in non-visible cells
- [x] 3.3 In `SelectionManager`, exclude entities in non-visible cells from click and box selection

## 4. Tests

- [x] 4.1 `test/unit/test_shroud_system.gd`: grid init/resize, hill occlusion, high-ground sees over, building blocking, air revealer ignores blockers
- [x] 4.2 Ref-count symmetry (overlap, last-leaves-to-fog, move between cells, no-op unregister), explored persistence, shroud/fog/visible precedence
- [x] 4.3 Play-area clamp (reveal at edge, `explore_all` respects bounds, percentage denominator), diamond bounds
- [x] 4.4 Allied sharing (same team sees, enemy not, no grid mutation), per-player isolation
- [x] 4.5 `explore_area` permanence, `reveal_area` reverts to fog, clamps to play area
- [x] 4.6 Shroud growth (frontier reverts one ring, visible cells protected, disabled is inert)
- [x] 4.7 Dirty-cell no-op (no work when nothing changed), only changed cells resolved
- [x] 4.8 Interaction filter: shrouded enemy → move not attack, revealed → attack, force-fire into shroud gated, shrouded tiberium not harvestable, shrouded entity not selectable, filter disabled when `fog_of_war` off
- [x] 4.9 `SpatialHash.is_building_cell` and `GlobalRules` field defaults
- [x] 4.10 Run full suite: `redot --headless -s test/run_tests.gd`; `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check` clean (no tabs introduced)
