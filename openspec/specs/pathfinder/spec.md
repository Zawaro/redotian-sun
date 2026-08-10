# pathfinder Specification

## Purpose

Pathfinder provides A* pathfinding on the 2m × 2m centered grid: occupancy-aware routing with height cost, optional per-locomotor terrain passability and climb tolerance, line-of-sight smoothing, a binary heap open set, and stagnation fallback.

## Requirements

### Requirement: Pathfinder provides A* pathfinding on 2m grid
`Pathfinder` SHALL be a static GDScript class at `scripts/core/Pathfinder.gd` implementing A* pathfinding on a 2m × 2m grid with 8-direction adjacency (cardinal + diagonal). Diagonal movement SHALL use `sqrt(2)` cost weighting. The heuristic SHALL be octile distance.

#### Scenario: Find path between two distant cells
- **WHEN** `Pathfinder.find_path(start_world, end_world)` is called with cells more than 1 apart
- **THEN** it returns a `PackedVector3Array` of cell-center world positions forming the shortest path

#### Scenario: Same cell produces empty path
- **WHEN** start and end cells are the same
- **THEN** `find_path()` returns an empty `PackedVector3Array`

### Requirement: Height cost penalty
Pathfinder SHALL apply a height cost penalty of `0.5 × abs(height_difference)` to each neighbor transition. Higher elevation changes increase path cost, preferring flatter routes.

#### Scenario: Flat path preferred over steep
- **WHEN** two paths exist to the same destination, one flat and one with a 4m height change
- **THEN** the flat path has lower total cost and is preferred

### Requirement: Stagnation fallback
Pathfinder SHALL track the best cell reached (closest to goal by heuristic). If the search stagnates for `STAGNANT_LIMIT = 500` iterations without improving, or exceeds `MAX_ITER = 1500` total iterations, it SHALL return the best-so-far path via `_path_or_fallback()`. If the best cell is the start cell, an empty path is returned.

#### Scenario: Stagnation returns best-so-far path
- **WHEN** A* exceeds 500 iterations without improving distance to goal
- **THEN** the path to the best cell reached is returned (may not reach the exact target)

#### Scenario: Max iterations returns best-so-far path
- **WHEN** A* exceeds 1500 total iterations
- **THEN** the path to the best cell reached is returned

#### Scenario: No progress returns empty path
- **WHEN** stagnation or max iterations triggers and the best cell is still the start cell
- **THEN** an empty `PackedVector3Array` is returned

### Requirement: Blocked cells
`find_path()` SHALL accept an optional `blocked_cells: Dictionary` parameter. Cells whose cell key is present in this dictionary SHALL be treated as impassable and skipped during neighbor expansion.

#### Scenario: Path avoids blocked cells
- **WHEN** cells between start and end are in `blocked_cells`
- **THEN** the path routes around them

#### Scenario: No blocked cells
- **WHEN** `blocked_cells` is empty (default)
- **THEN** all cells are traversable

### Requirement: Path smoothing via line-of-sight
`Pathfinder.smooth_path(waypoints, blocked)` SHALL remove redundant waypoints by checking line-of-sight between non-adjacent waypoints. Using Bresenham's line algorithm, it finds the farthest reachable waypoint from each position and skips intermediate ones. Paths with 2 or fewer waypoints are returned unchanged.

#### Scenario: Straight-line path simplified
- **WHEN** a 6-waypoint path has clear line-of-sight from waypoint 0 to waypoint 5
- **THEN** `smooth_path()` returns only waypoints 0 and 5

#### Scenario: Blocked line-of-sight preserves waypoints
- **WHEN** a 4-waypoint path has an obstacle between waypoints 0 and 2
- **THEN** `smooth_path()` keeps waypoint 1 and only skips if 0→2 is blocked

#### Scenario: Short path unchanged
- **WHEN** path has 2 or fewer waypoints
- **THEN** `smooth_path()` returns the input unchanged

### Requirement: Line-of-sight uses Bresenham's algorithm
`Pathfinder._has_line_of_sight(from, to, blocked)` SHALL use Bresenham's line algorithm to trace cells between two points. It returns false if any cell along the line is in the `blocked` dictionary.

#### Scenario: Clear line of sight
- **WHEN** no cells between from and to are blocked
- **THEN** `_has_line_of_sight()` returns true

#### Scenario: Blocked line of sight
- **WHEN** a cell between from and to is blocked
- **THEN** `_has_line_of_sight()` returns false

### Requirement: Binary heap for open set
Pathfinder SHALL use a binary min-heap for the open set to achieve O(log n) insert and extract-min operations. The heap stores entries with `cell` and `f` (f-score) fields.

#### Scenario: Heap ordering
- **WHEN** multiple cells are in the open heap
- **THEN** `_heap_pop()` returns the cell with the lowest f-score

### Requirement: Path reconstruction
`Pathfinder._reconstruct_path(came_from, current, start)` SHALL backtrack from the goal cell through `came_from` entries to reconstruct the full path. The start cell SHALL be excluded from the output.

#### Scenario: Multi-waypoint path reconstruction
- **WHEN** a path goes start → A → B → goal
- **THEN** the output is `[A_world, B_world, goal_world]` (start excluded)

### Requirement: Pathfinder uses centered coordinates
`Pathfinder.find_path()` SHALL convert world positions to cells with centered `CellUtil.world_to_cell()` and convert path cells back with centered `CellUtil.cell_to_world()`.

#### Scenario: Path waypoints span centered world coordinates
- **WHEN** `find_path(start_world, end_world)` crosses world origin
- **THEN** the returned waypoints can contain both negative and positive XZ coordinates

### Requirement: Per-locomotor terrain passability filtering
`Pathfinder.find_path()` SHALL accept an optional `locomotor: Locomotor` parameter. When provided, a neighbor cell SHALL be impassable if the unit's `terrain_speeds` for that cell's land type is `0.0` or the land type id is absent from `terrain_speeds`. A water cell occupied by an intact ice entity SHALL be passable to ground locomotors (see ice-drowning). When `locomotor` is null, all cells remain passable (preserving current behavior).

#### Scenario: Wheeled blocked by water
- **WHEN** a wheeled unit with `terrain_speeds = {"clear": 1.0, "water": 0.0}` pathfinds across a water cell
- **THEN** the water cell is excluded and the path routes around it

#### Scenario: Hover crosses water
- **WHEN** a hover unit with `terrain_speeds = {"clear": 1.0, "water": 1.0}` pathfinds across the same water cell
- **THEN** the water cell is included and the path crosses it

#### Scenario: Ice provides footing on water
- **WHEN** a wheeled unit pathfinds onto a water cell that holds an intact ice entity
- **THEN** the cell is treated as passable

#### Scenario: No locomotor preserves behavior
- **WHEN** `find_path()` is called without a locomotor
- **THEN** terrain type does not affect passability

### Requirement: Terrain speed pathing cost
Pathfinder SHALL weight neighbor transitions by the inverse of the unit's terrain speed multiplier for the target cell (`cost = base_cost / multiplier`). Faster surfaces (roads) yield cheaper paths than slow ones (rough).

#### Scenario: Road preferred over rough
- **WHEN** a wheeled unit (`rough = 0.5`, `road = 1.25`) has equal-length routes over rough and road
- **THEN** the road route has lower total cost and is preferred

#### Scenario: Water with zero speed is blocked
- **WHEN** a unit's terrain speed multiplier for a cell is `0.0`
- **THEN** the cell is treated as impassable regardless of pathing cost

### Requirement: Crystal fields raise path cost per-locomotor
`find_path()` SHALL weight neighbour transitions into a cell whose resolved land type is `resource` (a resource-occupied cell) by the inverse of the unit's `resource` terrain speed, exactly as for any other land type via the existing per-locomotor multiplier. A wheeled unit crossing a crystal field SHALL pay `base / 0.5 = 2.0×` per step, a foot unit `base / 0.9 ≈ 1.11×`, and a hover unit `1.0×` (no penalty). Water passability SHALL remain per-locomotor: a neighbour water cell is skipped only when the unit's `terrain_speeds` lacks a positive `water` entry.

#### Scenario: Wheeled unit routes around a crystal field
- **WHEN** a wheeled unit (`resource = 0.5`) has a cheap detour around a single resource-occupied cell
- **THEN** the path detours around the cell instead of crossing it

#### Scenario: Hover unit crosses a crystal field directly
- **WHEN** a hover unit (`resource = 1.0`) paths across the same resource cells
- **THEN** the path crosses them at the same cost as clear ground

#### Scenario: Foot blocked by water
- **WHEN** a foot unit (no `water` entry) pathfinds across a water cell
- **THEN** the water cell is skipped and the path routes around it

### Requirement: Per-locomotor climb tolerance
Pathfinder SHALL treat a neighbor transition as impassable when the absolute height difference between the current and neighbor cell exceeds `climb_tolerance × HEIGHT_STEP` for the unit's locomotor. Fly and Jumpjet locomotors SHALL ignore this check. The existing soft height cost penalty SHALL remain for passable transitions.

#### Scenario: Cliff blocks foot
- **WHEN** a foot unit (`climb_tolerance = 1`) is adjacent to a cell 3 height levels higher
- **THEN** that cell is excluded from the path

#### Scenario: Fly ignores cliffs
- **WHEN** a fly unit pathfinds across a 3-level height step
- **THEN** the transition is allowed

#### Scenario: No locomotor keeps soft penalty only
- **WHEN** `find_path()` is called without a locomotor across a 3-level height step
- **THEN** the transition is allowed with the existing height cost penalty

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
