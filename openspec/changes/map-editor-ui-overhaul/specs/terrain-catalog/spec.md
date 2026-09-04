## ADDED Requirements

### Requirement: Cell pins override derived resolution
`TerrainCatalog.resolve_cell_art` SHALL check the cell's pin (from `TerrainSystem`) before height-derived family resolution: a pinned cell SHALL resolve to its pinned object id (via `resolve_art(object_id, theater_id)`); an unpinned cell SHALL resolve exactly as before. Unknown pinned object ids SHALL fall back to derived resolution with a warning.

#### Scenario: Pinned cell resolves its object
- **WHEN** a cell is pinned to "cliff01_e" and `resolve_cell_art` runs for it
- **THEN** the resolution is the `cliff01_e` art, not the height-derived family mesh

#### Scenario: Unpinned cells unchanged
- **WHEN** a cell has no pin
- **THEN** `resolve_cell_art` behaves identically to its pre-pin behavior

#### Scenario: Unknown pin falls back
- **WHEN** a cell is pinned to an object id the catalog does not know
- **THEN** the cell falls back to height-derived resolution and a warning is emitted
