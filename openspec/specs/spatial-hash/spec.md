# spatial-hash Specification

## Purpose

`SpatialHash` is the autoload spatial grid rebuilt each physics frame, providing occupancy, blocked cells, cell reservation, building/bib/resource cell tracking, and crush queries.
## Requirements
### Requirement: SpatialHash rebuilt every physics frame
`SpatialHash` SHALL be an autoload singleton rebuilt every `_physics_process()` frame. It iterates all entities in the "entities" group, resolves each entity's root Node3D, and populates the grid with position, MovementController state, entity type, and player ID.

#### Scenario: Grid populated on rebuild
- **WHEN** `_physics_process()` runs
- **THEN** `_grid` is cleared and repopulated with all entities in the "entities" group

#### Scenario: Entity without Node3D root
- **WHEN** an entity in the "entities" group is not a Node3D and has no Node3D parent
- **THEN** it is skipped (not added to grid)

### Requirement: Blocked cells from idle units
During rebuild, SpatialHash SHALL populate `_blocked_cells` with cells containing IDLE units whose MovementController `shares_cell()` returns false. Sharing cells are tracked separately in `_shared_cell_counts`.

#### Scenario: Idle vehicle blocks cell
- **WHEN** a vehicle with `shares_cell() == false` is IDLE at cell (5, 3)
- **THEN** `_blocked_cells` contains key for (5, 3)

#### Scenario: Idle sharer counted, not blocked
- **WHEN** a unit with `shares_cell() == true` is IDLE at cell (5, 3)
- **THEN** `_shared_cell_counts[(5,3)]` increments, `_blocked_cells` does NOT contain (5, 3)

#### Scenario: Moving units not counted
- **WHEN** a unit is in MOVING or ROTATING state
- **THEN** it is neither blocked nor counted in shared cells

### Requirement: Blocked cell merging
`get_blocked_cells()` SHALL return a merged dictionary of idle-unit blocked cells AND building footprint cells.

#### Scenario: Building cells included
- **WHEN** building cells are registered via `register_building_cells()`
- **THEN** `get_blocked_cells()` includes both idle-unit cells and building cells

### Requirement: Crusher-aware blocking
`get_crusher_blocking_cells(player_id)` SHALL return cells that a crusher vehicle cannot crush through: cells containing friendly infantry, non-crushable infantry, or zero infantry.

#### Scenario: Enemy crushable infantry not blocking
- **WHEN** a cell contains only enemy infantry with `crushable = true`
- **THEN** the cell is NOT in crusher-blocking cells (vehicle can crush through)

#### Scenario: Friendly infantry blocking
- **WHEN** a cell contains infantry owned by the same player
- **THEN** the cell IS in crusher-blocking cells

#### Scenario: Non-crushable infantry blocking
- **WHEN** a cell contains enemy infantry with `crushable = false`
- **THEN** the cell IS in crusher-blocking cells

### Requirement: Crushable enemy queries
`get_crushable_enemies_on_cell(cell, player_id)` SHALL return an array of enemy infantry nodes on the given cell that are crushable.

#### Scenario: Find crushable enemies
- **WHEN** cell (5, 3) contains 2 enemy infantry with `crushable = true`
- **THEN** `get_crushable_enemies_on_cell((5, 3), player_id)` returns both nodes

#### Scenario: No crushable enemies
- **WHEN** cell (5, 3) contains only friendly infantry
- **THEN** `get_crushable_enemies_on_cell((5, 3), player_id)` returns empty array

### Requirement: Cell reservation system
SpatialHash SHALL provide a reservation system for cells. `reserve_cell(cell)` returns true if the cell is free (not blocked, not building, not already reserved). `release_cell(cell)` removes the reservation. `force_reserve(cell)` reserves regardless of occupancy.

#### Scenario: Reserve free cell
- **WHEN** `reserve_cell(cell)` is called on an unoccupied cell
- **THEN** returns true and cell is reserved

#### Scenario: Reserve occupied cell fails
- **WHEN** `reserve_cell(cell)` is called on a cell that is blocked, a building cell, or already reserved
- **THEN** returns false

#### Scenario: Force reserve bypasses checks
- **WHEN** `force_reserve(cell)` is called
- **THEN** cell is reserved regardless of current occupancy

#### Scenario: Release cell
- **WHEN** `release_cell(cell)` is called on a reserved cell
- **THEN** the reservation is removed

### Requirement: Building cell registration
Buildings SHALL register their footprint cells via `register_building_cells(cells)` and unregister via `unregister_building_cells(cells)`. These cells appear in `get_blocked_cells()`.

#### Scenario: Register building cells
- **WHEN** a building is placed at cells [(2,3), (3,3), (2,4), (3,4)]
- **THEN** `register_building_cells()` adds all 4 cells to `_building_cells`

#### Scenario: Unregister building cells
- **WHEN** a building is destroyed
- **THEN** `unregister_building_cells()` removes its cells from `_building_cells`

### Requirement: Bib cell tracking
`register_bib_cells(cells)` SHALL track foundation extension cells (bibs). `is_bib_cell(cell)` returns true for bib cells.

#### Scenario: Bib cell registered
- **WHEN** `register_bib_cells([(5, 5)])` is called
- **THEN** `is_bib_cell((5, 5))` returns true

### Requirement: Resource cell tracking
`register_resource_cell(cell)` and `unregister_resource_cell(cell)` SHALL track cells containing resource entities. `has_resource_cell(cell)` queries this tracking.

#### Scenario: Resource cell registered
- **WHEN** a tiberium crystal is placed at cell (3, 7)
- **THEN** `register_resource_cell((3, 7))` and `has_resource_cell((3, 7))` returns true

#### Scenario: Resource cell unregistered
- **WHEN** tiberium at cell (3, 7) is depleted
- **THEN** `unregister_resource_cell((3, 7))` and `has_resource_cell((3, 7))` returns false

### Requirement: Entity queries
`get_entries(cell)` SHALL return the array of entity entries at a cell. `all_entries()` SHALL return all entries across all cells. `is_any_entity_on_cell(cell)` SHALL return true if any entity with a MovementController exists on the cell.

#### Scenario: Get entries at cell
- **WHEN** 2 units are at cell (5, 3)
- **THEN** `get_entries((5, 3))` returns an array of 2 entries

#### Scenario: Empty cell
- **WHEN** no entities are at cell (0, 0)
- **THEN** `get_entries((0, 0))` returns empty array

#### Scenario: Any entity check
- **WHEN** a vehicle is on cell (5, 3)
- **THEN** `is_any_entity_on_cell((5, 3))` returns true

### Requirement: Shared cell capacity
Each cell SHALL support up to `CellSubPositions.get_slot_count()` idle sharers. `is_cell_full_for_shared(cell)` SHALL return true when count >= the capacity.

#### Scenario: Cell below capacity not full
- **WHEN** `_shared_cell_counts[cell]` is one less than `CellSubPositions.get_slot_count()`
- **THEN** `is_cell_full_for_shared(cell)` returns false

#### Scenario: Cell at capacity is full
- **WHEN** `_shared_cell_counts[cell]` equals `CellSubPositions.get_slot_count()`
- **THEN** `is_cell_full_for_shared(cell)` returns true

