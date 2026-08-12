## ADDED Requirements

### Requirement: Canonical footprint cell queries
`FoundationComponent` SHALL be the canonical source for a building footprint's cell set. It SHALL expose `get_foundation_cells(origin_cell)` returning every cell in the `foundation` rectangle, and `get_occupied_cells(origin_cell)` returning the foundation cells minus `bib_cells` (the cells that are registered as solid building cells in `SpatialHash`).

#### Scenario: Foundation cells for a 2×2 footprint
- **WHEN** `get_foundation_cells(Vector2i(5, 3))` is called on a 2×2 foundation
- **THEN** it returns `(5,3), (6,3), (5,4), (6,4)`

#### Scenario: Occupied cells exclude bib cells
- **WHEN** a footprint has `bib_cells` containing offset `(0, 1)` and `get_occupied_cells(origin)` is called
- **THEN** the returned cells include every foundation cell EXCEPT `origin + (0, 1)`

#### Scenario: Occupied cells equal foundation cells when no bib
- **WHEN** `bib_cells` is empty
- **THEN** `get_occupied_cells(origin)` equals `get_foundation_cells(origin)`

### Requirement: Single-cell buildability predicate
`FoundationComponent` SHALL expose a static `is_cell_buildable(cell)` returning `false` when the cell is occupied by a building cell, a bib cell, a blocked cell, an entity with a `MovementController`, or a resource, or when its terrain type is neither `""` nor `"clear"`; otherwise `true`. This predicate SHALL be the single implementation reused by placement validation and preview rendering.

#### Scenario: Free clear cell is buildable
- **WHEN** a cell has no buildings, entities, or resources and its terrain type is `"clear"`
- **THEN** `is_cell_buildable(cell)` returns `true`

#### Scenario: Building cell is not buildable
- **WHEN** a cell is registered as a building cell in `SpatialHash`
- **THEN** `is_cell_buildable(cell)` returns `false`

### Requirement: Per-footprint buildability
`FoundationComponent` SHALL expose `is_buildable(origin_cell)` returning `true` only when every foundation cell is `is_cell_buildable` AND the terrain height variation across the footprint (max cell height − min cell height) is at most `TerrainSystem.HEIGHT_STEP`.

#### Scenario: Flat, free footprint is buildable
- **WHEN** all foundation cells are buildable and level
- **THEN** `is_buildable(origin)` returns `true`

#### Scenario: One occupied cell blocks the footprint
- **WHEN** any foundation cell is not `is_cell_buildable`
- **THEN** `is_buildable(origin)` returns `false`

#### Scenario: Excessive height variation blocks the footprint
- **WHEN** the max−min cell height across the footprint exceeds `TerrainSystem.HEIGHT_STEP`
- **THEN** `is_buildable(origin)` returns `false`
