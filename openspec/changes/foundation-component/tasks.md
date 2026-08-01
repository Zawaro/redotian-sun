## 1. FoundationComponent footprint API

- [x] 1.1 Add static `footprint_cells(foundation, origin)` and refactor `get_foundation_cells` to delegate to it
- [x] 1.2 Add static `occupied_cells(foundation, bib_cells, origin)` and instance `get_occupied_cells(origin)` delegating to it
- [x] 1.3 Add static `is_cell_buildable(cell)` (moved from `BuildingManager._is_cell_free`: building/bib/blocked/entity/resource + terrain-type check)
- [x] 1.4 Add static `footprint_buildable(foundation, origin)` (all cells buildable + height delta ≤ `HEIGHT_STEP`) and instance `is_buildable(origin)`

## 2. TerrainSystem flattening

- [x] 2.1 Add `flatten_footprint(origin_cell, size)` that computes the max vertex level over the footprint region and sets all bounding vertices to it via `set_vertex`

## 3. BuildingManager integration

- [x] 3.1 Make `_is_cell_free(cell)` a one-line delegate to `FoundationComponent.is_cell_buildable`
- [x] 3.2 Refactor `can_place` to keep bounds/play-area/debug, delegate footprint free+height to `FoundationComponent.footprint_buildable`, and call the adjacency check
- [x] 3.3 Add `_is_adjacency_satisfied(building_type, origin)` using `EntityData.adjacent` and the friendly-building registry (Chebyshev distance)
- [x] 3.4 In `place_building`, build the registered cell list via the canonical occupied-cells query and call `TerrainSystem.flatten_footprint` after registration

## 4. Tests

- [x] 4.1 Add `test/unit/test_foundation_component.gd`: occupied-cells excludes bib, `is_cell_buildable` true/false, `is_buildable` height-delta and occupancy cases
- [x] 4.2 Add adjacency cases to `test/unit/test_building_manager.gd` (adjacent>0 rejected with no neighbor, accepted near a friendly building, adjacent=0 no-op)
- [x] 4.3 Add `flatten_footprint` case to `test/unit/test_terrain_system.gd` (footprint levelled to max height)

## 5. Quality gate

- [x] 5.1 `gdformat` + `gdlint` clean, no tabs in multiline strings
- [x] 5.2 Headless test suite passes (N passed, 0 failed)
