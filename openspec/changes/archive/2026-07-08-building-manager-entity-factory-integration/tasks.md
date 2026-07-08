## 1. Data Layer

- [x] 1.1 Add `@export var buildable: bool = false` to `EntityData.gd` (after line 69, with the other special ability booleans)
- [x] 1.2 Add `get_all_by_type(entity_type: EntityData.EntityType) -> Array[EntityData]` to `EntityFactory.gd` — iterate `_entity_cache.values()`, filter by `entity_type`
- [x] 1.3 Update `EntityData.validate()` to warn when `buildable = true` with `strength <= 0` or `foundation == Vector2i(1,1)`
- [x] 1.4 Set `buildable = true` on existing buildable `.tres` files: `gacnst_construction_yard.tres`, `gapowr_power_plant.tres`, `napowr_power_plant.tres`
- [x] 1.5 Create 4 missing EntityData `.tres` files in `resources/entities/structures/`: barracks, refinery, war factory, guard tower — with `buildable = true`, correct `foundation`, placeholder `strength`/`cost`

## 2. BuildingManager Migration

- [x] 2.1 Replace `_load_building_types()`: query `EntityFactory.get_all_by_type(BUILDING)` filtered by `buildable == true`, store as `Array[EntityData]`
- [x] 2.2 Change `current_building_type: BuildingType` → `current_building_type: EntityData` (line 7)
- [x] 2.3 Change `building_types: Array[Resource]` → `building_types: Array[EntityData]` (line 11)
- [x] 2.4 Change `enter_build_mode(building_type: BuildingType)` → `enter_build_mode(building_type: EntityData)` (line 59)
- [x] 2.5 Change `can_place(building_type: BuildingType, ...)` → `can_place(building_type: EntityData, ...)`, replace `building_type.footprint` with `building_type.foundation` (lines 81-126)
- [x] 2.6 Change `place_building(building_type: BuildingType, ...)` → `place_building(building_type: EntityData, ...)`, replace `building_type.scene.instantiate()` with `EntityFactory.create_entity(building_type.id)`, replace `building_type.footprint` with `building_type.foundation` (lines 129-164)
- [x] 2.7 Update `_update_preview_position()` — replace `current_building_type.footprint` with `current_building_type.foundation` (line 287)
- [x] 2.8 Update `_update_preview_mesh()` — replace `current_building_type.scene.instantiate()` with `EntityFactory.create_entity(current_building_type.id)` for 3D ghost, replace `footprint` with `foundation` (lines 316-357)
- [x] 2.9 Update `_try_place_building()` — replace `current_building_type.footprint` with `current_building_type.foundation` (line 539)
- [x] 2.10 Change `signal building_placed(building: Node3D, building_type: BuildingType)` → `signal building_placed(building: Node3D, entity_data: EntityData)` (line 4)
- [x] 2.11 Update `_buildings` array append to store `"type": entity_data` instead of `"type": building_type` (line 156)

## 3. BuildMenu Migration

- [x] 3.1 Change `var bt: BuildingType = building_types[idx] as BuildingType` → `var bt: EntityData = building_types[idx] as EntityData` in `_populate_buttons()` (line 30)
- [x] 3.2 Change `_on_building_button_pressed(building_type: BuildingType)` → `_on_building_button_pressed(building_type: EntityData)` (line 78)
- [x] 3.3 Change `var bt := building_types[i] as BuildingType` → `var bt := building_types[i] as EntityData` in `_on_build_mode_changed()` (line 91)

## 4. Tests

- [x] 4.1 Update `test/unit/test_building_manager.gd` — replace `BuildingType.new()` with `EntityData.new()`, replace `footprint` with `foundation`
- [x] 4.2 Update `test/integration/test_building_placement.gd` — replace `BuildingType.new()` with `EntityData.new()`, replace `footprint` with `foundation`

## 5. Cleanup

- [x] 5.1 Delete `scripts/buildings/BuildingType.gd`
- [x] 5.2 Delete all 7 files in `resources/buildings/` directory, then remove the directory
