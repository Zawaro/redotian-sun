## ADDED Requirements

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

### Requirement: Pathfinder cell-to-world-with-height
`Pathfinder.cell_to_world_with_height(cell)` SHALL return the centered
world-space cell position from `CellUtil.cell_to_world()` with the terrain
height assigned to Y.

#### Scenario: Path endpoint near world origin
- **WHEN** `cell_to_world_with_height(Vector2i(50, 50))` is called on a 50×50 grid
- **THEN** the returned position is near `Vector3(0, height, 0)`

### Requirement: Pathfinder uses centered coordinates
`Pathfinder.find_path()` SHALL convert world positions to cells with centered
`CellUtil.world_to_cell()` and convert path cells back with centered
`CellUtil.cell_to_world()`.

#### Scenario: Path waypoints span centered world coordinates
- **WHEN** `find_path(start_world, end_world)` crosses world origin
- **THEN** the returned waypoints can contain both negative and positive XZ coordinates
