## ADDED Requirements

### Requirement: Greedy step primitive
`Pathfinder` SHALL provide `try_greedy_step(from_cell, target_cell, blocked_cells, locomotor) -> Vector2i` that returns the best strictly-improving passable 8-neighbor toward the target, or an out-of-range stall sentinel when no neighbor strictly improves the move. A neighbor SHALL be considered improving when it is passable for the given `locomotor` (terrain land type, climb tolerance, `ignores_height` for fly/jumpjet), not in `blocked_cells`, and reduces the distance/cost toward the target using the same neighbor-cost model as `find_path` (octile step cost, terrain speed multiplier, height penalty, bib penalty). The sentinel SHALL be an out-of-range value that can never be a valid grid cell.

#### Scenario: Returns best improving neighbor
- **WHEN** `try_greedy_step` is called with an open, passable neighbor that reduces distance to the target
- **THEN** it returns that neighbor cell

#### Scenario: Stall returns sentinel
- **WHEN** every passable neighbor is strictly worse (distance increases) or blocked
- **THEN** it returns the stall sentinel

#### Scenario: Per-locomotor passability respected
- **WHEN** a water cell is reachable but the `locomotor` has no positive `water` speed
- **THEN** the water cell is not returned as the greedy step

#### Scenario: Cliff respected for foot units
- **WHEN** the only improving neighbor is above the foot unit's `climb_tolerance`
- **THEN** that neighbor is not returned (stall sentinel instead)

### Requirement: Greedy-first movement resolution
Movement orders issued to units SHALL attempt bounded greedy descent toward the destination cell before running a full A* search. `MovementController` SHALL repeatedly call `try_greedy_step` from the unit's current cell toward the target, up to a bounded step budget. When the greedy descent stalls (stall sentinel returned) or exhausts the budget, the unit SHALL fall back to `Pathfinder.find_path` from the stalled cell to the destination, guaranteeing a path is produced whenever the destination is reachable. Greedy descent SHALL apply to all locomotors, including fly and jumpjet (which ignore the climb-height check, matching `find_path`'s `ignores_height` behavior, and therefore stall only on blocked cells).

#### Scenario: Open-terrain move skips A*
- **WHEN** an infantry unit moves across open passable terrain to its formation cell
- **THEN** the destination is reached via greedy steps without a full `find_path` search

#### Scenario: Concave pocket falls back to A*
- **WHEN** greedy descent reaches a concave obstacle pocket where no neighbor improves distance
- **THEN** `find_path` runs from the stalled cell and the unit escapes the pocket

#### Scenario: Flyer ignores height in greedy
- **WHEN** a fly/jumpjet unit greedily descends across a multi-level height step
- **THEN** the step is allowed (matching `find_path`'s `ignores_height`) and the unit stalls only on blocked cells

### Requirement: Per-cell terrain cost cache
`Pathfinder` SHALL memoize per-cell terrain cost data — cell height (the 4-corner minimum used by `_cell_height`), land type, bib status, and blocked status — so repeated neighbor probes during a search read the cache instead of re-probing `TerrainSystem` and `SpatialHash`. The cache SHALL be invalidated when blocked/reservation state changes, tracked by a generation counter, so cached cost data is never stale across a change in blockers. Paths produced with the cache SHALL be identical to paths produced without it.

#### Scenario: Cache read not terrain probe
- **WHEN** a search expands a neighbor cell that was already probed earlier in the same search
- **THEN** the cached cost data is reused and `TerrainSystem.get_vertex`/`get_land_type` are not re-called for that cell

#### Scenario: Cache invalidated on blocker change
- **WHEN** a blocked-cell set changes (generation bumps) between searches
- **THEN** the new search reads fresh cost data for the affected cells

#### Scenario: Cache preserves path output
- **WHEN** `find_path` runs with the terrain-cost cache enabled on a fixed map and blocked set
- **THEN** the returned path matches the path produced without the cache byte-for-byte
