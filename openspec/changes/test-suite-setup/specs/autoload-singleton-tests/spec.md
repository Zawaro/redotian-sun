## ADDED Requirements

### Requirement: TerrainSystem shall be tested

A test file `test/unit/test_terrain_system.gd` SHALL contain tests for TerrainSystem autoload singleton state management.

#### Scenario: Test file created

- **WHEN** `test/unit/test_terrain_system.gd` is opened
- **THEN** it contains test methods prefixed with `test_`

### Requirement: init_grid shall be tested

Tests SHALL verify `TerrainSystem.init_grid()` resizes the vertex grid.

#### Scenario: init_grid sets grid_cells

- **WHEN** `init_grid(16)` is called
- **THEN** `grid_cells` equals `16`

#### Scenario: init_grid resets vertex data

- **WHEN** a vertex is set to height 5, then `init_grid(32)` is called
- **THEN** the vertex at the same position returns `0`

### Requirement: get_cell and set_cell shall be tested

Tests SHALL verify `TerrainSystem.get_cell()` and `TerrainSystem.set_cell()` read and write cell data.

#### Scenario: set_cell stores data

- **WHEN** `set_cell(Vector2i(2, 3), {"height": 5, "type": "clear"})` is called
- **THEN** `get_cell(Vector2i(2, 3))` returns a dictionary with `"height": 5`

#### Scenario: get_cell returns empty for unset cell

- **WHEN** `get_cell(Vector2i(99, 99))` is called on a fresh grid
- **THEN** the result is an empty dictionary

### Requirement: clear shall reset state

Tests SHALL verify `TerrainSystem.clear()` resets all grid data.

#### Scenario: clear empties cells

- **WHEN** cells are set, then `clear()` is called
- **THEN** `get_cell()` returns empty for all previously set cells

### Requirement: SpatialHash shall be tested

A test file `test/unit/test_spatial_hash.gd` SHALL contain tests for SpatialHash cell reservation logic.

#### Scenario: reserve_cell succeeds on empty cell

- **WHEN** `reserve_cell(Vector2i(5, 5))` is called on an unoccupied cell
- **THEN** the result is `true`

#### Scenario: reserve_cell fails on already reserved cell

- **WHEN** `reserve_cell(Vector2i(5, 5))` is called twice
- **THEN** the second call returns `false`

#### Scenario: release_cell frees the cell

- **WHEN** a cell is reserved, then `release_cell()` is called
- **THEN** `reserve_cell()` succeeds on that cell again

#### Scenario: is_cell_idle reflects blocked state

- **WHEN** a cell is marked as idle (blocked)
- **THEN** `is_cell_idle()` returns `true`
- **THEN** `reserve_cell()` returns `false`

### Requirement: SelectionManager shall be tested

A test file `test/unit/test_selection_manager.gd` SHALL contain tests for SelectionManager selection state.

#### Scenario: select_entity adds to selection

- **WHEN** `select_entity(entity)` is called
- **THEN** `get_selected_entities()` contains the entity

#### Scenario: deselect_all clears selection

- **WHEN** entities are selected, then `deselect_all()` is called
- **THEN** `get_selected_entities()` is empty

#### Scenario: toggle_entity adds if not selected

- **WHEN** `toggle_entity(entity)` is called on an unselected entity
- **THEN** the entity is added to selection

#### Scenario: toggle_entity removes if selected

- **WHEN** `toggle_entity(entity)` is called on a selected entity
- **THEN** the entity is removed from selection
