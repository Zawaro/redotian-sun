## MODIFIED Requirements

### Requirement: Per-cell terrain cost cache
`Pathfinder` SHALL memoize per-cell terrain cost data so repeated neighbor probes during a search read the cache instead of re-probing `TerrainSystem` and `SpatialHash`. The height entry SHALL source from the world-lifetime `TerrainSystem` height snapshot (`terrain-height-cache`): `_cell_height` SHALL read the snapshot's per-cell corner-vertex data (4-corner minimum) rather than re-indexing `_vertex_grid`. Land type and bib status SHALL remain batch-lifetime in the `PathCostCache` (land resolves through `get_land_type`; bib through `SpatialHash.is_bib_cell`). The cache SHALL be invalidated when blocked/reservation state changes, tracked by a generation counter, so cached cost data is never stale across a change in blockers. Paths produced with the cache SHALL be identical to paths produced without it. `try_greedy_step`, `_cell_cost`, and `find_path` SHALL accept an optional terrain-node reference; when provided, it SHALL be used instead of re-resolving the `TerrainSystem` autoload via the scene tree.

#### Scenario: Cache read not terrain probe
- **WHEN** a search expands a neighbor cell that was already probed earlier in the same search
- **THEN** the cached cost data is reused and `TerrainSystem.get_vertex`/`get_land_type` are not re-called for that cell

#### Scenario: Cache invalidated on blocker change
- **WHEN** a blocked-cell set changes (generation bumps) between searches
- **THEN** the new search reads fresh cost data for the affected cells

#### Scenario: Cache preserves path output
- **WHEN** `find_path` runs with the terrain-cost cache enabled on a fixed map and blocked set
- **THEN** the returned path matches the path produced without the cache byte-for-byte

#### Scenario: Height sourced from world snapshot
- **WHEN** `_cell_height` resolves a cell whose corner heights are present in the `TerrainSystem` height snapshot
- **THEN** the 4-corner minimum is computed from the snapshot's corner data without re-indexing `_vertex_grid`

#### Scenario: Terrain reference passed instead of autoload lookup
- **WHEN** a terrain node reference is supplied to `try_greedy_step`/`find_path`
- **THEN** the scene tree is not queried for the `TerrainSystem` autoload during that call

#### Scenario: No terrain reference falls back to autoload
- **WHEN** no terrain node reference is supplied
- **THEN** the autoload is resolved as before and pathfinding still succeeds
