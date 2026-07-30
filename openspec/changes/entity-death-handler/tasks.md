## 1. EntityFactory — Universal Free on Death

- [x] 1.1 In `create_entity()`, after `_configure_components`, connect `HealthComponent.health_zero` to a lambda that calls `entity.queue_free()` if HealthComponent exists

## 2. BuildingManager — Building Death Handler

- [x] 2.1 Add `building_destroyed` signal: `signal building_destroyed(building: Node3D, entity_data: EntityData)`
- [x] 2.2 Add `_on_building_destroyed(building_node: Node3D)` function: find entry via `_find_building_index`, unregister cells/bib cells from SpatialHash, unregister from PrerequisiteSystem, remove entry from `_buildings`, deselect from SelectionManager, emit `building_destroyed`, call `queue_free()`
- [x] 2.3 In `place_building()`, after appending to `_buildings`, connect `HealthComponent.health_zero` to `_on_building_destroyed.bind(building)`

## 3. Tests

- [x] 3.1 Unit test: building death removes entry from BuildingManager._buildings
- [x] 3.2 Unit test: building death unregisters cells from SpatialHash
- [x] 3.3 Unit test: building death unregisters from PrerequisiteSystem
- [x] 3.4 Unit test: building death deselects from SelectionManager
- [x] 3.5 Unit test: building_destroyed signal emitted with correct args
- [x] 3.6 Unit test: unit freed on death (queue_free called via EntityFactory lambda)
- [x] 3.7 Unit test: map-loaded entity not in BuildingManager still freed
- [x] 3.8 Unit test: double queue_free safe (both paths call it)

## 4. Lint & Format

- [x] 4.1 Run gdlint on modified files
- [x] 4.2 Run gdformat --check on modified files
