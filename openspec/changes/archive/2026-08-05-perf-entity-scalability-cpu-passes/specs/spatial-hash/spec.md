# spatial-hash Specification

## MODIFIED Requirements

### Requirement: SpatialHash rebuilt every physics frame
`SpatialHash` SHALL be an autoload singleton whose grid is maintained incrementally rather than fully rebuilt every physics frame. It SHALL cache a pooled entry per entity (root Node3D, MovementController/StatsComponent references, entity type, player ID, cell, movement state) and reconcile those entries each `_physics_process()` frame, moving an entry to a new cell or flipping its blocked/shared contribution only when the entity's cell or state actually changed. A full rebuild SHALL occur when entities or ice enter/leave the "entities"/"ice" groups or on explicit refresh. Query results SHALL match what a full rebuild would have produced within the same physics tick.

#### Scenario: Grid populated on rebuild
- **WHEN** a full rebuild runs after an entity is added to the "entities" group
- **THEN** `_grid` is populated with all entities in the "entities" group

#### Scenario: Entity without Node3D root
- **WHEN** an entity in the "entities" group is not a Node3D and has no Node3D parent
- **THEN** it is skipped (not added to grid)

#### Scenario: Idle unit does not trigger a full rebuild
- **WHEN** an idle unit remains in the same cell across physics frames
- **THEN** no full rebuild occurs and `_grid` keeps its existing entries

### Requirement: SpatialHash cell-change updates
When an entity's cell changes, `SpatialHash` SHALL move that entity's entry from its previous cell key to the new one without rebuilding the grid. When an entity's movement state changes, `SpatialHash` SHALL add or remove the entity's blocked/shared-cell contribution accordingly. Within the same physics tick, the resulting `_grid`, `_blocked_cells`, and `_shared_cell_counts` SHALL be identical to what a full rebuild would have produced.

#### Scenario: Moving unit crosses a cell boundary
- **WHEN** a unit moves from cell (5, 3) to cell (5, 4)
- **THEN** its entry is removed from `_grid[(5,3)]` and appended to `_grid[(5,4)]`

#### Scenario: Unit enters idle state
- **WHEN** a unit transitions from MOVING to IDLE
- **THEN** its cell's contribution is updated: `_blocked_cells` gains the cell if `shares_cell()` is false, or `_shared_cell_counts` increments if true

#### Scenario: Unit leaves idle state
- **WHEN** a unit transitions from IDLE to MOVING
- **THEN** its blocked/shared contribution is removed from the previous cell

#### Scenario: Entry ordering preserved
- **WHEN** an entry moves to a cell that already has entries
- **THEN** it is appended after existing entries (per-cell order preserved)

### Requirement: SpatialHash entry references are cached
`SpatialHash` SHALL cache each entity's MovementController and StatsComponent references in its pooled entry at rebuild time and SHALL NOT re-resolve child nodes during per-frame reconciliation.

#### Scenario: No per-frame node lookups
- **WHEN** the `_physics_process()` reconcile runs over N entities
- **THEN** no `get_node`/`get_node_or_null` child lookups are performed for those N entities
