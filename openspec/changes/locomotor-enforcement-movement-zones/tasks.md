## 1. Data model

- [x] 1.1 Create `scripts/data/LandType.gd` resource class (`id`, `display_name`, `color`) + `.uid`
- [x] 1.2 Create `scripts/data/Locomotor.gd` resource class (`id`, `terrain_speeds` float-multiplier dict, `climb_tolerance`, `crushes`, `shares_cell`, `is_hover`, `is_amphibious`, `is_fly`, `is_jumpjet`, `is_subterranean`, `is_ship`, `hover_height_override`, `jumpjet_fly_distance`, `subterranean_dig_distance`) + `.uid`
- [x] 1.3 Create default LandType `.tres` files (clear, rough, road, water, cliff) under `resources/land_types/`
- [x] 1.4 Create default Locomotor `.tres` files (Foot, Track, Wheel, Hover, Amphibious, Fly, Jumpjet, Subterranean, Ship) under `resources/locomotors/` with float-multiplier tables anchored to reference values
- [x] 1.5 Create ice terrain entity `.tres` + scene (terrain entity, HealthComponent) under the existing terrain-entity pattern

## 2. GlobalRules registry + validation

- [x] 2.1 Add `land_types: Dictionary` and `locomotors: Dictionary` to `scripts/data/GlobalRules.gd` with `get_land_type(id)` / `get_locomotor(id)` helpers
- [x] 2.2 Register all default LandType and Locomotor resources in `resources/global_rules.tres`
- [x] 2.3 Add registry validation to GlobalRules (dangling terrain-speed keys), mirroring `validate_warhead_armor_keys`
- [x] 2.4 Add entity↔registry checks to the entity-validation layer: unknown `locomotor` id and contradictory `movement_zone` (e.g. `Track` + `Subterannean`, `Wheel` + `Crusher`)

## 3. TerrainSystem land-type overlay

- [x] 3.1 Add sparse per-cell land-type overlay to `scripts/core/TerrainSystem.gd` (defaults to "clear" when unset) with `get_land_type(cell)`, `set_land_type(cell, id)`

## 4. Pathfinder integration

- [x] 4.1 Extend `Pathfinder.find_path()` with optional `locomotor: Locomotor` param (null default = current behavior)
- [x] 4.2 Implement terrain passability filtering (multiplier 0.0 or absent key → blocked), with intact-ice-on-water cells passable to ground
- [x] 4.3 Implement terrain speed pathing cost (`base_cost / multiplier`)
- [x] 4.4 Implement climb tolerance hard-impassability (`|Δh| > climb_tolerance × HEIGHT_STEP` → blocked; skipped for fly/jumpjet)
- [x] 4.5 Cache the TerrainSystem reference and resolve `terrain_speeds` once before the A* loop (hot path)

## 5. MovementController integration

- [x] 5.1 Resolve the unit's Locomotor in `_ready()` via `GlobalRules.get_locomotor(locomotor)`; null → current behavior, unknown non-empty id → `push_error`
- [x] 5.2 Add `_terrain_speed_factor()` from current cell land type, multiplied into the movement `step`
- [x] 5.3 Fix `_slope_coefficient()` probe to sample the next waypoint cell center instead of `direction * 1.0`
- [x] 5.4 Implement hover float: skip slope coefficient, set Y = terrain + hover height in `_snap_to_terrain` / idle path
- [x] 5.5 Implement jumpjet walk-first then fly fallback in `set_target_position` (walk path empty OR distance > `jumpjet_fly_distance` → straight-line fly waypoint)
- [x] 5.6 Implement subterranean surface-first then dig fallback (surface path empty OR distance > `subterranean_dig_distance` → direct move to target)
- [x] 5.7 Implement weight-based one-time ice damage on cell entry (anchored to `IceCrackingWeight`; below-threshold weights deal none)
- [x] 5.8 Handle drowning: on ice entity death, kill occupants of its cell

## 6. Entity data + .tres fixes

- [x] 6.1 Fix `resources/entities/vehicles/gdi_amphibious_apc.tres`: `locomotor = "Amphibious"`
- [x] 6.2 Fix `resources/entities/vehicles/nod_subterranean_apc.tres`: `locomotor = "Subterranean"`, `movement_zone = "Subterannean"`
- [x] 6.3 Confirm `gdi_hover_mlrs.tres` and `gdi_jumpjet_infantry.tres` reference registered values (Hover / Jumpjet)
- [x] 6.4 Add per-locomotor `crushes` documentation values to Locomotor `.tres` for Track/Wheel/Amphibious/Ship
- [x] 6.5 Register ice entity data with breakable strength and water-underlying placement

## 7. Tests

- [x] 7.1 Unit tests: LandType/Locomotor resource defaults and GlobalRules registry lookups (incl. unknown → null)
- [x] 7.2 Unit tests: GlobalRules + entity-layer validation (dangling terrain key, unknown entity locomotor, contradictory movement_zone)
- [x] 7.3 Unit tests: TerrainSystem land-type overlay get/set with default "clear"
- [x] 7.4 Unit tests: Pathfinder passability (wheeled vs water, hover vs water, ice-over-water), terrain cost (road vs rough), climb tolerance (cliff blocks foot, fly ignores), null-locomotor backward compat
- [x] 7.5 Unit tests: MovementController terrain speed factor, hover float, jumpjet walk/fly fallback, subterranean surface/dig fallback, slope probe cell sampling, amphibious water entry
- [x] 7.6 Unit tests: ice entity weight damage curve, once-per-entry, break → drown occupant, adjacent survives, passability reverts to water
- [x] 7.7 Run full suite (`redot --headless -s test/run_tests.gd`) + `gdlint` / `gdformat` check on new/edited files

## 8. Finalization

- [ ] 8.1 Update `openspec/specs/` with the new capabilities (land-types, locomotor, ice-drowning) and deltas (pathfinder, entity-data) by archiving the change
- [ ] 8.2 Commit on `feat/34-locomotor-enforcement-movement-zones` with Conventional Commits format referencing #34
