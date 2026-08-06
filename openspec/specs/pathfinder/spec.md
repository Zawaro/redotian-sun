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

#### Scenario: Crystal field slows per-locomotor
- **WHEN** a wheeled unit (`resource = 0.5`) pathfinds across a resource-occupied cell
- **THEN** the transition costs `base / 0.5 = 2.0×`, biasing the path around it when a cheaper detour exists

#### Scenario: Hover crosses crystal fields
- **WHEN** a hover unit (`resource = 1.0`) pathfinds across the same resource cells
- **THEN** the transition costs the same as clear ground

#### Scenario: Water with zero speed is blocked
- **WHEN** a unit's terrain speed multiplier for a cell is `0.0`
- **THEN** the cell is treated as impassable regardless of pathing cost

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
