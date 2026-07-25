## ADDED Requirements

### Requirement: Entity type selection
The MapEditor SHALL provide an entity browser panel listing all buildable entities from `EntityFactory.get_all_by_type()`. Entities SHALL be filterable by category (Buildings, Infantry, Vehicles, Aircraft, Naval) and searchable by name or ID.

#### Scenario: Entity list populated
- **WHEN** the MapEditor opens
- **THEN** the entity browser lists all entities with `buildable == true` from EntityFactory

#### Scenario: Category filter
- **WHEN** user selects "Buildings" category tab
- **THEN** only entities with `entity_type == BUILDING` are shown

#### Scenario: Search filter
- **WHEN** user types "barr" in search bar
- **THEN** only entities matching "barr" in name or ID are shown

#### Scenario: Toggle placement mode
- **WHEN** user clicks an entity in the list
- **THEN** placement mode activates for that entity type
- **AND** clicking the same entity again deselects it

### Requirement: Player assignment
The entity browser SHALL provide a player/owner dropdown populated from PlayerManager. Each placed entity SHALL store `player_id` in its metadata.

#### Scenario: Player dropdown populated
- **WHEN** the entity browser opens
- **THEN** the player dropdown shows all players from PlayerManager

#### Scenario: Default player
- **WHEN** no player is selected
- **THEN** defaults to Player 0

#### Scenario: Place entity with player
- **WHEN** user selects Player 1 and places an entity
- **THEN** the entity's `player_id` metadata is set to 1

### Requirement: Entity placement
Clicking a map cell SHALL place the selected entity at that cell via `EntityFactory.create_entity()`. Single-cell entities are centered on the cell. Multi-cell entities (buildings) use foundation-aware positioning.

#### Scenario: Place single-cell entity
- **WHEN** user clicks cell (5, 3) with an infantry entity selected
- **THEN** entity is created at cell center (5, 3)

#### Scenario: Place multi-cell building
- **WHEN** user clicks cell (5, 3) with a 2×2 building selected
- **THEN** building is positioned via `_cell_origin_world_pos()` to account for foundation footprint

#### Scenario: Cannot place on occupied cell
- **WHEN** user clicks a cell already occupied by another entity
- **THEN** placement is rejected, no entity is created

#### Scenario: Right-click cancels
- **WHEN** user right-clicks during placement mode
- **THEN** placement mode exits, no entity is placed

### Requirement: Preview ghost
A 50% opacity preview entity SHALL follow the cursor before placement. The preview SHALL use `_set_preview_transparency()` to apply alpha to all MeshInstance3D nodes.

#### Scenario: Preview follows cursor
- **WHEN** placement mode is active
- **THEN** a semi-transparent entity follows the mouse cursor

#### Scenario: Preview hidden during height painting
- **WHEN** the MapEditor tool is not PLACE_ENTITY
- **THEN** the preview is hidden

#### Scenario: Preview removed on exit
- **WHEN** placement mode exits
- **THEN** the preview node is removed from the scene tree

### Requirement: Data persistence
Placed entities SHALL be stored in `_painted_entities` dictionary with key format `"x,y"` (cell coordinates). Value is `{"node": Node3D, "data": Dictionary}` containing `id`, `player_id`, and optional overrides.

#### Scenario: Entity stored on placement
- **WHEN** entity is placed at cell (15, 20)
- **THEN** `_painted_entities["15,20"]` contains the entity node and metadata

#### Scenario: Entity metadata includes player_id
- **WHEN** entity is placed for Player 1
- **THEN** metadata `data.player_id` is 1

### Requirement: Save includes player_id
Map save JSON SHALL include `player_id` field in each entity entry. Load SHALL restore entity with correct player assignment. Existing maps without `player_id` default to Player 0.

#### Scenario: Save with player_id
- **WHEN** map is saved with entities for Player 1
- **THEN** JSON contains `"player_id": 1` in entity entries

#### Scenario: Load with player_id
- **WHEN** map JSON has `"player_id": 1` on an entity
- **THEN** entity is created with `player_id == 1`

#### Scenario: Backward compatibility
- **WHEN** map JSON has no `player_id` field on an entity
- **THEN** entity defaults to `player_id == 0`

### Requirement: Occupied cell check
Placement SHALL be rejected if the target cell is already in `_painted_entities`. This prevents stacking entities on the same cell.

#### Scenario: Cell occupied
- **WHEN** `_painted_entities` has entry for cell (5, 3)
- **THEN** placing another entity at (5, 3) is rejected

#### Scenario: Cell free
- **WHEN** `_painted_entities` has no entry for cell (5, 3)
- **THEN** placing an entity at (5, 3) succeeds
