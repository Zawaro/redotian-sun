## ADDED Requirements

### Requirement: SelectionManager tracks selected entities
`SelectionManager` SHALL be an autoload singleton maintaining `selected_entities: Array[SelectComponent]`. It emits `selection_changed(selected_entities)` whenever the selection set changes.

#### Scenario: Select single entity
- **WHEN** `select_entity(entity)` is called without shift
- **THEN** all previously selected entities are deselected, the new entity is selected, and `selection_changed` emits with the new selection

#### Scenario: Shift-click adds to selection
- **WHEN** `select_entity(entity, shift_pressed=true)` is called
- **THEN** the entity is added to the existing selection without deselecting others

#### Scenario: Shift-click removes from selection
- **WHEN** `select_entity(entity, shift_pressed=true)` is called on an already-selected entity
- **THEN** the entity is removed from the selection

#### Scenario: Deselect all
- **WHEN** `deselect_all()` is called
- **THEN** all entities are deselected and `selection_changed` emits with empty array

### Requirement: Hover preview
SelectionManager SHALL manage hover preview state. `set_hover_preview(enabled, entity)` toggles hover visual on the hovered entity and emits `hover_changed(entity)`.

#### Scenario: Hover entity
- **WHEN** `set_hover_preview(true, entity)` is called
- **THEN** `entity.set_is_hovering(true)` is called and `hover_changed` emits

#### Scenario: Unhover entity
- **WHEN** `set_hover_preview(false)` is called
- **THEN** the previously hovered entity's `set_is_hovering(false)` is called

### Requirement: Formation move for vehicles
When multiple vehicles are selected and a move command is issued, `request_move(target)` SHALL maintain formation offsets. Each vehicle moves to a position offset from the target by its relative offset from the selection center, clamped to ±2 cells.

#### Scenario: Two-vehicle formation
- **WHEN** two vehicles are 4 cells apart and move command is issued
- **THEN** each vehicle maintains its relative offset from the group center at the destination

#### Scenario: Formation offset clamped
- **WHEN** a vehicle is more than 2 cells from the selection center
- **THEN** its offset is clamped to ±2 cells at the destination

#### Scenario: Skip formation
- **WHEN** `request_move(target, skip_formation=true)` is called
- **THEN** all vehicles move to the exact target position (no formation offsets)

### Requirement: Infantry cell pre-assignment
When infantry units are selected and a move command is issued, `request_move()` SHALL pre-assign each infantry to a cell using spiral search from the target cell. Each cell supports up to 3 infantry. The assignment uses `CellUtil.spiral_first_free()` with max radius 4.

#### Scenario: Three infantry to same cell
- **WHEN** 3 infantry move to a cell with no existing infantry
- **THEN** all 3 are assigned to the target cell (slots 0, 1, 2)

#### Scenario: Infantry overflow to adjacent cells
- **WHEN** 4 infantry move to a cell
- **THEN** 3 are assigned to the target cell, the 4th is assigned to the nearest free adjacent cell

#### Scenario: Target cell already has infantry
- **WHEN** 2 infantry move to a cell that already has 1 infantry
- **THEN** the 2 new infantry fill slots 1 and 2, totaling 3 in the cell

### Requirement: Batched move dispatch
SelectionManager SHALL dispatch pending moves in batches of 8 per frame via `_process()`. This prevents frame spikes when moving large groups.

#### Scenario: Large group moved in batches
- **WHEN** 20 units are queued for movement
- **THEN** only 8 units receive their move command per frame, completing over 3 frames

### Requirement: Local entity filtering
In multiplayer, `request_move()` SHALL only move entities owned by the local player. Non-local entities are skipped.

#### Scenario: Local entity moves
- **WHEN** an entity has `player_id == PlayerManager.get_local_player_id()`
- **THEN** it receives the move command

#### Scenario: Remote entity skipped
- **WHEN** an entity has a different `player_id`
- **THEN** it does not receive the move command

### Requirement: Deploy transition handling
Entities with DeployComponent that are transitioning (deploying/undeploying) SHALL be skipped during move commands. Their cells are reserved for other units.

#### Scenario: Transitioning entity skipped
- **WHEN** an entity has DeployComponent and `is_transitioning() == true`
- **THEN** it is skipped in `request_move()` and does not receive a move command

### Requirement: Cell reservation during move
Before issuing move commands, SelectionManager SHALL clear all existing reservations, then reserve each selected entity's current cell. If a vehicle's target cell is already reserved, a fallback target is found via spiral search.

#### Scenario: Reserve current cells
- **WHEN** `request_move()` is called
- **THEN** all existing reservations are cleared, and each entity's current cell is reserved

#### Scenario: Fallback on reserved target
- **WHEN** a vehicle's target cell is already reserved
- **THEN** `CellUtil.spiral_first_free()` finds the nearest available cell within radius 8

### Requirement: Rally point setting
`request_set_rally_point(target_position)` SHALL set the rally point on all selected entities that have a RallyPointComponent.

#### Scenario: Set rally point
- **WHEN** `request_set_rally_point(world_pos)` is called with a building selected
- **THEN** `RallyPointComponent.set_rally_point(cell)` is called with the target cell

### Requirement: Visual selection synchronization
SelectionManager SHALL synchronize its internal selection list with the visual `is_selected` state on SelectComponents every frame via `_synchronize_visual_selection()`. This handles cases where selection state is modified externally.

#### Scenario: Visual selection out of sync
- **WHEN** a SelectComponent has `is_selected = true` but is not in `selected_entities`
- **THEN** it is added to `selected_entities`

#### Scenario: List contains visually unselected
- **WHEN** a SelectComponent is in `selected_entities` but has `is_selected = false`
- **THEN** it is removed from `selected_entities`
