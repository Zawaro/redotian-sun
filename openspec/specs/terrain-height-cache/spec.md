# terrain-height-cache Specification

## Purpose

A world-lifetime cache of per-cell corner-vertex terrain heights in `TerrainSystem`. Mass movement re-reads the same terrain heights every physics tick; the snapshot serves those reads from a lazily-populated dictionary instead of N bounds-checked `_vertex_grid` lookups, while staying coherent with the live heightfield through the existing `cell_changed` signal. Land type is deliberately excluded — it resolves through channels with no invalidation signal and remains batch-lifetime in the pathfinder cost cache.

## Requirements

### Requirement: World-lifetime per-cell height snapshot
`TerrainSystem` SHALL maintain a world-lifetime cache of per-cell corner-vertex heights: a dictionary keyed by `CellUtil.cell_key(cell)` mapping to the cell's four corner heights `[h_nw, h_ne, h_sw, h_se]` (in raw height units, matching `_vertex_grid` semantics). The snapshot SHALL be populated lazily on first query for a cell and SHALL be used as the source for the height consumers `get_height_at_world_smooth` (bilinear sample), `get_cell_max_height` (max-corner), and `Pathfinder._cell_height` (min-corner) instead of N bounds-checked `_vertex_grid` reads. Cache reads SHALL reproduce the exact same float output as direct vertex reads (integer-to-float ordering, `HEIGHT_STEP` applied at the end, per-consumer min/max corner semantics).

#### Scenario: Height query served from snapshot
- **WHEN** `get_cell_max_height` or `get_height_at_world_smooth` queries a cell already in the snapshot
- **THEN** the value is read from the cache and the `_vertex_grid` arrays are not re-indexed for that cell

#### Scenario: Snapshot matches live heightfield
- **WHEN** a cell is queried before and after no height mutation
- **THEN** both reads return identical values

#### Scenario: Float output parity
- **WHEN** a snapshot-backed query and a direct vertex read return the height for the same slope cell
- **THEN** the outputs are bit-identical (same corner min/max semantics, same `HEIGHT_STEP` scaling)

### Requirement: Snapshot invalidated on terrain mutation
The height snapshot SHALL be invalidated whenever the underlying heightfield mutates: every vertex mutation (e.g. `set_vertex`, height paint raise/lower) SHALL clear or update the affected cells via the existing `cell_changed` signal, and grid re-initialization or map load SHALL clear the entire snapshot. After invalidation, the next query for an affected cell SHALL re-read the live `_vertex_grid`. No stale height value SHALL be served after a mutation.

#### Scenario: Height edit invalidates cell
- **WHEN** a single cell's height is painted (cell_changed emitted for that cell)
- **THEN** the next query for that cell re-reads the live vertex data and returns the new height

#### Scenario: Map load clears snapshot
- **WHEN** a new map loads and the grid re-initializes
- **THEN** the snapshot is fully cleared and all queries read the fresh grid

#### Scenario: Unaffected cells keep cached values
- **WHEN** one cell is painted and a distant cell is queried
- **THEN** the distant cell's cached value is still valid and served (only affected cells invalidated)

### Requirement: Land type excluded from world-lifetime cache
The world-lifetime snapshot SHALL cache height data only. Land type (`get_land_type`) SHALL NOT be cached at world lifetime: it resolves through channels with no invalidation signal (`set_land_type` emits no `cell_changed`, and the SpatialHash resource registry mutates on harvest/growth). Land type SHALL remain batch-lifetime in the pathfinder `PathCostCache` (as today), re-probed when that cache is invalidated.

#### Scenario: Harvested crystal reflects new land type
- **WHEN** a crystal field is harvested (resource registry changes) after a path cost cache was populated
- **THEN** a subsequent path probes fresh land type for the affected cell rather than serving a stale world-lifetime value

#### Scenario: Height cached, land re-probed
- **WHEN** `_cell_cost` resolves a cell with a populated world height snapshot
- **THEN** height is read from the snapshot while land type is resolved through the batch-lifetime cost cache / live `get_land_type`
