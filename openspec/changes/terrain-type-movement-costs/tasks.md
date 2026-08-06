## 1. Land type registry

- [x] 1.1 Add `resources/land_types/resource.tres` (id `resource`, display name `Resource`)
- [x] 1.2 Register `resource` in `resources/global_rules.tres` `land_types`

## 2. Per-locomotor resource speeds

- [x] 2.1 Add `"resource": 0.9` to `Foot` and `Jumpjet`
- [x] 2.2 Add `"resource": 0.7` to `Track` and `Subterranean`
- [x] 2.3 Add `"resource": 0.5` to `Wheel` and `Amphibious`
- [x] 2.4 Add `"resource": 1.0` to `Hover`; leave `Ship` and `Fly` without an entry

## 3. TerrainSystem resource resolution

- [x] 3.1 `get_land_type()` returns `RESOURCE_LAND_TYPE` when
      `SpatialHash.instance.has_resource_cell(cell)` is true, before the painted
      overlay

## 4. Remove rejected iteration

- [x] 4.1 Remove `terrain_movement_costs` + `get_terrain_cost` from `GlobalRules`
- [x] 4.2 Remove `_terrain_types` overlay, accessors, cell surfacing, and map-JSON
      serialization from `TerrainSystem`
- [x] 4.3 Remove `_get_terrain_costs`, `_terrain_type_for`, and `get_terrain_type`
      from `Pathfinder`; restore per-locomotor-only neighbour cost (keep
      once-per-path node hoisting)
- [x] 4.4 Delete the `resource`-unrelated #51 tests (`test_terrain_movement_costs.gd`,
      tiberium/water-gate integration tests) and replace with resource tests

## 5. Tests & quality gate

- [x] 5.1 Unit test: `get_land_type` resolves a registered resource cell to
      `resource` and reverts on unregister
- [x] 5.2 Unit test: each ground locomotor's `resource` speed < its `clear`
      speed, hover `1.0`, ship not passable on `resource`
- [x] 5.3 Integration test: wheeled unit detours around a cheap resource cell,
      hover crosses directly
- [x] 5.4 Integration test: foot unit blocked by water (per-locomotor)
- [x] 5.5 Run `gdformat` + `gdlint` + headless test suite; all green
