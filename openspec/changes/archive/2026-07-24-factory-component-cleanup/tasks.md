## 1. Create ExitComponent

- [x] 1.1 Create `scripts/components/ExitComponent.gd` with `exit_cell_offset: Vector2i`, `spawn_cell_offset: Vector2i`, `exit_facing: int`
- [x] 1.2 Add `on_unit_produced(unit: Node3D)` method that positions unit at spawn_cell_offset, moves to exit_cell_offset, sets exit_facing
- [x] 1.3 Add `signal unit_spawned(unit: Node3D)` emitted after positioning
- [x] 1.4 Add `configure(data: EntityData)` method to read exit fields from EntityData

## 2. Create RallyPointComponent

- [x] 2.1 Create `scripts/components/RallyPointComponent.gd` with `rally_path: Array[Vector2i]`
- [x] 2.2 Add `set_rally_point(cell: Vector2i)` method that updates rally_path
- [x] 2.3 Add `clear_rally_point()` method that resets rally_path to empty array
- [x] 2.4 Add `signal rally_point_changed(path: Array[Vector2i])` emitted on change

## 3. Refactor FactoryComponent

- [x] 3.1 Delete `free_unit` field from FactoryComponent
- [x] 3.2 Delete `can_produce()` method from FactoryComponent
- [x] 3.3 Rename `factory_type` to `produces: Array[String]`
- [x] 3.4 Add `is_primary: bool = false` field
- [x] 3.5 Add `set_primary()` method that sets is_primary = true and clears same-type siblings
- [x] 3.6 Add `on_unit_produced(entity_data: EntityData, player_id: int)` method
- [x] 3.7 Add `signal exit_in_progress` emitted when unit is exiting
- [x] 3.8 Add `func _ready()` to add self to `"factories"` group
- [x] 3.9 Update `configure(data: EntityData)` to read from `data.buildable_queue`

## 4. Update EntityData

- [x] 4.1 Add `exit_cell_offset: Vector2i = Vector2i(-1, -1)` field
- [x] 4.2 Add `spawn_cell_offset: Vector2i = Vector2i(-1, -1)` field
- [x] 4.3 Add `exit_facing: int = 0` field
- [x] 4.4 Add `has_rally_point: bool = false` field

## 5. Update EntityFactory

- [x] 5.1 Update `_add_factory_component()` to use `data.buildable_queue` instead of `data.factory`
- [x] 5.2 Add `_add_exit_component()` method that creates ExitComponent if `data.exit_cell_offset != Vector2i(-1, -1)`
- [x] 5.3 Add `_add_rally_point_component()` method that creates RallyPointComponent if `data.has_rally_point == true`
- [x] 5.4 Call `_add_exit_component()` and `_add_rally_point_component()` in `_add_components()`

## 6. Wire ProductionManager

- [x] 6.1 Update `_find_primary_factory()` to query `"factories"` group instead of BuildingManager
- [x] 6.2 Update `_count_factories()` to query `"factories"` group instead of BuildingManager
- [x] 6.3 Update `_spawn_unit()` to call `FactoryComponent.on_unit_produced()`
- [x] 6.4 Add listener for `exit_in_progress` signal to find next free factory

## 7. Wire ArtComponent for Door Animations

- [x] 7.1 Add listener for `unit_spawned` signal from ExitComponent
- [x] 7.2 Play `door_anim` sequence from ArtData when unit_spawned received
- [x] 7.3 Play `under_door_anim` sequence if defined in ArtData

## 8. Wire Rally Point Input (Alt + Left Click)

- [x] 8.1 In `MouseHandler._handle_single_click()`, detect Alt + Left Click before entity raycast
- [x] 8.2 Raycast to terrain, convert hit position to cell via `Pathfinder.world_to_cell()`
- [x] 8.3 If selected entity has RallyPointComponent, call `set_rally_point(cell)`
- [x] 8.4 Add `SelectionManager.request_set_rally_point(cell: Vector3)` method that iterates selected entities and calls `set_rally_point()` on RallyPointComponent if present

## 9. Rally Point Visual

- [x] 9.1 Add `DebugVisualizer.draw_rally_line(start, end)` method that draws a green line with diamond marker
- [x] 9.2 Add `SelectionManager._update_rally_line()` that shows/clears line based on selected building's rally point
- [x] 9.3 Clear rally line on deselect and on `clear_all()`

## 8. Update .tres Files

- [x] 8.1 Update GDI Barracks .tres: add `exit_cell_offset = (0, 1)`, `exit_facing = 90`
- [x] 8.2 Update GDI War Factory .tres: add `exit_cell_offset = (1, 2)`, `exit_facing = 90`
- [x] 8.3 Update Nod Barracks .tres: add `exit_cell_offset = (0, 1)`, `exit_facing = 90`
- [x] 8.4 Update Nod War Factory .tres: add `exit_cell_offset = (1, 2)`, `exit_facing = 90`
- [x] 8.5 Add `has_rally_point = true` to all factory buildings

## 9. Tests

- [x] 9.1 Write unit test for FactoryComponent: produces field, is_primary toggle
- [x] 9.2 Write unit test for ExitComponent: positioning, facing, signal emission
- [x] 9.3 Write unit test for RallyPointComponent: set/clear, path storage
- [x] 9.4 Write integration test: ProductionManager → FactoryComponent → ExitComponent flow
- [x] 9.5 Write integration test: multiple factories, primary building selection
