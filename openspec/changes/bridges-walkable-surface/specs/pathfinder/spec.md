## ADDED Requirements

### Requirement: A* nodes are cell-level pairs
`Pathfinder` SHALL search over `(cell, level)` nodes rather than cells alone, so a high deck and the ground beneath it are distinct search nodes. The start and goal SHALL resolve to a level (the mover's current level, or the level of the destination surface). `find_path` SHALL accept an optional start level and goal level defaulting to 0. Path reconstruction SHALL emit the level of each waypoint so the mover follows the correct surface.

#### Scenario: Deck and ground are distinct nodes
- **WHEN** a cell is covered by a high deck and a search expands that cell
- **THEN** the ground node and the deck node are expanded independently

#### Scenario: Default levels are ground
- **WHEN** `find_path` is called without levels
- **THEN** it searches at level 0 and returns a ground path, matching pre-change behavior

#### Scenario: Waypoints carry level
- **WHEN** a path crosses onto a deck
- **THEN** the reconstructed waypoints include the level of the deck segment

### Requirement: Pathing evaluates height transitions across the level stack
`Pathfinder` SHALL accept a neighbor transition only when the step between the current and neighbor `(cell, level)` surfaces satisfies the surface-stack height rules: same level allowed; a level change allowed only when its surface height difference is within the mover's `climb_tolerance` and the destination surface is passable; a step exceeding `climb_tolerance` refused. A ground locomotor SHALL cross a bridge deck over water where it cannot cross the uncovered water, and SHALL NOT climb onto a high deck from the surrounding ground grade.

#### Scenario: Path crosses bridge not water
- **WHEN** a wheeled unit pathfinds across a bridge span over water
- **THEN** the returned path uses the deck nodes and excludes the uncovered water cells

#### Scenario: No bridge routes around water
- **WHEN** the same wheeled unit pathfinds across the same water with no bridge present
- **THEN** no path crosses the water cells

#### Scenario: High bridge climb from ground rejected
- **WHEN** a ground unit with `climb_tolerance = 1` pathfinds from the surrounding ground to a high deck four steps above
- **THEN** the deck is not reachable from that ground node

#### Scenario: High bridge entry from a matching end
- **WHEN** a ground unit paths from a bridge end at the deck grade onto the adjacent deck
- **THEN** the path includes the deck node

### Requirement: Deck cost uses the Road row
`Pathfinder` SHALL cost a transition whose step is two or more height levels from the locomotor's Road multiplier, and SHALL skip the destination land type's terrain figure entirely for a deck surface. A unit crossing onto a deck SHALL retain road-like speed even when the deck lies over water it cannot cross.

#### Scenario: Road cost for a large step
- **WHEN** a unit transitions a step of two or more levels onto a deck
- **THEN** the transition cost uses the Road multiplier, not the destination land type

#### Scenario: Deck over water stays fast
- **WHEN** a wheeled unit crosses a deck over water
- **THEN** the crossing cost is the road cost and the water terrain figure does not apply

### Requirement: Ground beneath a high deck is pathable
The ground level beneath a high deck SHALL remain a passable path for ground traffic where the ground land type allows it, because the deck is a separate level node and does not block the ground. A unit SHALL be able to path under a high deck across otherwise-open ground.

#### Scenario: Path under a high deck
- **WHEN** a ground unit pathfinds across a cell covered by a high deck on passable open ground
- **THEN** the path may use the ground node under the deck

#### Scenario: Deck does not block the ground
- **WHEN** a high deck covers a cell
- **THEN** the ground node at that cell is not blocked by the deck

## MODIFIED Requirements

### Requirement: Per-cell terrain cost cache
`Pathfinder` SHALL memoize per-cell terrain cost data so repeated neighbor probes during a search read the cache instead of re-probing `TerrainSystem` and `SpatialHash`. The cache SHALL be keyed by `(cell, level)` so a ground surface and a deck surface at the same cell never collide. The height entry SHALL source from the world-lifetime `TerrainSystem` height snapshot (`terrain-height-cache`): `_cell_height` SHALL read the snapshot's per-cell corner-vertex data (4-corner minimum) rather than re-indexing `_vertex_grid`, except that when a cell carries a surface at the requested level it SHALL read that level's walkable surface height (`TerrainSystem.get_cell_surface_height(cell, level)`). Land type and bib status SHALL remain batch-lifetime in the `PathCostCache` (land resolves through `get_land_type(cell, level)`; bib through `SpatialHash.is_bib_cell`; bib is evaluated at level 0). The cache SHALL be invalidated when blocked/reservation state changes, when a level's occupancy changes, or when bridge cells/surfaces are added or removed at any level, tracked by a generation counter, so cached cost data is never stale across a change in blockers, levels, or bridges. Paths produced with the cache SHALL be identical to paths produced without it. `try_greedy_step`, `_cell_cost`, and `find_path` SHALL accept an optional terrain-node reference; when provided, it SHALL be used instead of re-resolving the `TerrainSystem` autoload via the scene tree.

#### Scenario: Cache read not terrain probe
- **WHEN** a search expands a neighbor `(cell, level)` that was already probed earlier in the same search
- **THEN** the cached cost data is reused and `TerrainSystem.get_vertex`/`get_land_type` are not re-called for that node

#### Scenario: Cache invalidated on blocker change
- **WHEN** a blocked-cell set changes (generation bumps) between searches
- **THEN** the new search reads fresh cost data for the affected cells

#### Scenario: Cache invalidated on bridge or level change
- **WHEN** a bridge cell is added or removed, or a level surface changes, between searches
- **THEN** the new search reads fresh cost data for the affected `(cell, level)` nodes

#### Scenario: Cache preserves path output
- **WHEN** `find_path` runs with the terrain-cost cache enabled on a fixed map and blocked set
- **THEN** the returned path matches the path produced without the cache byte-for-byte

#### Scenario: Height sourced from world snapshot
- **WHEN** `_cell_height` resolves a node at level 0 whose corner heights are present in the `TerrainSystem` height snapshot and no surface covers it
- **THEN** the 4-corner minimum is computed from the snapshot's corner data without re-indexing `_vertex_grid`

#### Scenario: Height sourced from the level surface
- **WHEN** `_cell_height` resolves a `(cell, level)` node covered by a surface at that level
- **THEN** that level's walkable surface height is used instead of the terrain corner minimum

#### Scenario: No level collision in the cache
- **WHEN** a cell carries both a ground surface and a deck surface
- **THEN** their cache entries are distinct and neither overwrites the other

#### Scenario: Terrain reference passed instead of autoload lookup
- **WHEN** a terrain node reference is supplied to `try_greedy_step`/`find_path`
- **THEN** the scene tree is not queried for the `TerrainSystem` autoload during that call

#### Scenario: No terrain reference falls back to autoload
- **WHEN** no terrain node reference is supplied
- **THEN** the autoload is resolved as before and pathfinding still succeeds
