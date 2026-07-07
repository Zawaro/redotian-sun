## ADDED Requirements

### Requirement: Selected units receive move command when left-clicking on ground plane
When the player left-clicks a valid terrain/ground surface and at least one entity with `MovementController` is currently selected, all such selected entities SHALL receive a move command and travel toward the clicked world position. Movement follows a straight line (no pathfinding in Phase 1).

#### Scenario: Single unit receives move command via left-click on ground
- **WHEN** one entity with `SelectComponent` and `MovementController` is selected, player left-clicks on empty terrain (not an entity)
- **THEN** the unit begins moving toward the clicked world position at its configured `move_speed`, rotating to face travel direction

#### Scenario: Multiple selected units all receive move command from single click
- **WHEN** two or more entities with `SelectComponent` and `MovementController` are in selection, player left-clicks on ground plane
- **THEN** every selected unit receives the same target position and begins moving simultaneously at its individual configured speed

#### Scenario: Left-clicking an entity still selects it (no movement)
- **WHEN** a unit is not currently selected and player left-clicks directly on that unit
- **THEN** only that single unit becomes selected; no move command is issued — this preserves existing selection behavior

### Requirement: Units rotate Y-axis to face movement direction during travel
While a unit is actively traveling toward its move target, it SHALL orient itself along its velocity vector by rotating around the UP (Y) axis only. This gives clean top-down/isometric yaw without pitch or roll.

#### Scenario: Unit rotates on first frame of movement
- **WHEN** a unit transitions from Idle to Moving state with `_current_target` set
- **THEN** `rotation.y` is updated each physics tick toward the normalized direction vector `(target - global_position).normalized()` using look_at() constrained to XZ plane

#### Scenario: Unit rotation tracks changing target during travel (future)
- **WHEN** a unit's move target changes mid-travel while in Moving state
- **THEN** the unit smoothly updates its facing toward the new direction on each physics frame without teleporting or snapping

### Requirement: Unit stops at configurable arrival threshold and emits arrived signal
A moving unit SHALL compare distance to `_current_target` each physics tick. When the remaining distance falls below `arrival_threshold`, the unit transitions back to Idle state and emits an `arrived` signal with its position. Default `arrival_threshold = 1.0` (~half of the 2m cell size).

#### Scenario: Arrival detection triggers idle state transition
- **WHEN** `(target - global_position).length() <= arrival_threshold` while in Moving state
- **THEN** `_state` changes to IDLE, movement stops via `global_position += direction * move_speed * delta`, and the unit is no longer consuming delta for translation

#### Scenario: Arrived signal is emitted with correct position data
- **WHEN** a unit arrives at its move target
- **THEN** `arrived(global_position)` is called on any connected listeners (e.g., SelectionManager or combat system)

### Requirement: MouseHandler raycasts ground plane for left-click movement destination
When the player left-clicks, after checking for entity hit at mask 1 << 15 with no result found, `MouseHandler` SHALL cast a second physics ray from the camera through the mouse cursor position targeting default collision layer (ground/terrain). If any unit is currently selected and ground intersection is found, it becomes the move target passed to SelectionManager. Right-click (`deselect_entity`) remains simple: always calls `selection_manager.deselect_all()`.

#### Scenario: Left-click on empty terrain returns ground world position for movement
- **WHEN** player left-clicks where no entity exists under cursor and at least one unit is selected, raycast hits default collision layer (mask 1)
- **THEN** `result.position` from the physics query becomes a move target; SelectionManager receives this via `request_move(position)`

#### Scenario: Left-click on empty terrain with no units selected does nothing
- **WHEN** player left-clicks where no entity exists under cursor and selection is empty, raycast hits default collision layer (mask 1)
- **THEN** no move command is issued — the click has no effect since there are no units to receive it

#### Scenario: Right-click always deselects regardless of what is under cursor
- **WHEN** player right-clicks anywhere on screen
- **THEN** `selection_manager.deselect_all()` is called immediately; no raycast or movement logic runs

#### Scenario: Left-click with terrain miss (no collision geometry) produces no error
- **WHEN** the ground plane has no StaticBody3D/collision at the clicked location, or map scene lacks a GroundPlane entirely
- **THEN** `_get_ground_position_at_mouse()` returns `Vector3.INF` sentinel and MouseHandler issues no move command; no crash, log spam, or visual glitch occurs

### Requirement: Map scenes include collision-enabled ground plane on physics layer 1
Every playtest map scene (MapBase01.tscn, TestMap01.tscn, and future maps) SHALL contain a GroundPlane component with StaticBody3D and CollisionShape3D configured as the first child node. This ensures the MouseHandler ground raycast has geometry to hit on default collision layer 1.

### Requirement: SelectionManager broadcasts movement commands to selected entities
`SelectionManager` SHALL expose `request_move(position)` method that iterates over all currently selected entities, checks for a `MovementController` child node, and calls its target-setting API. The selection data structure (existing) is reused; no new tracking structures are introduced.

#### Scenario: SelectionManager forwards move command to single unit
- **WHEN** one entity with MovementController is in the `"entities"` group selection, `request_move(target_pos)` is called
- **THEN** `_on_request_move()` finds that node and calls `movement_controller.set_target_position(target_pos)`, transitioning it from IDLE to MOVING

#### Scenario: SelectionManager forwards move command to multiple units
- **WHEN** three entities with MovementController are selected, `request_move(target_pos)` is called once
- **THEN** all three controllers receive independent set_target_position calls; each moves at its own configured speed and may arrive at different times

#### Scenario: Entities without MovementController are silently skipped
- **WHEN** a structure (e.g., GDIConyard) with SelectComponent but no MovementController is in selection, `request_move(target_pos)` is called
- **THEN** the iteration checks `has_node("MovementController")` and skips it — no error or crash

### Requirement: Units apply radial repulsion steering against nearby entities during movement to prevent stacking on a 2m grid cell system
While traveling toward its move target in MOVING state, each unit SHALL check all other nodes in the `"entities"` group within ~3 m radius. For every neighboring vehicle whose center falls within `cell_radius × 2` distance (~2.0 m), a push-away steering force is computed as `(unit_position - neighbor_center).normalized() / (distance²)` and added to the movement direction before final normalization and translation. This produces smooth flow-around behavior without requiring global A* pathfinding — units naturally form lanes or queue behind each other when paths converge, matching Tiberian Sun's traffic feel on a 2m × 2m cell grid where each vehicle occupies one cell with an occupancy circle of radius ~1.0 m.

#### Scenario: Two selected vehicles converging on the same target avoid stacking
- **WHEN** two units are moving toward approximately the same ground position and their centers come within `cell_radius × 2` (~2.0 m) distance during `_physics_process(delta)`
- **THEN** each unit's direction vector receives an opposing push-away force proportional to inverse squared distance; after normalization, both units glide past each other along diverging paths rather than occupying the same cell center

#### Scenario: Three vehicles in a narrow corridor naturally queue behind one another via repulsion
- **WHEN** three selected vehicles move through a constrained passage (narrow terrain or between static obstacles) and the rearmost unit's `cell_radius × 2` circle overlaps with the front vehicle's circle during `_physics_process(delta)`
- **THEN** the rearward units' direction vectors are pushed sideways by repulsion forces; if no lateral space exists, they decelerate implicitly because opposing push-away vectors partially cancel their forward progress — producing a natural queue without explicit grid occupancy tracking or path recalculation

#### Scenario: Radial repulsion has zero effect when only one unit is moving
- **WHEN** a single selected vehicle moves toward its target with no other `"entities"` group nodes within `cell_radius × 2` (~2.0 m) distance during `_physics_process(delta)`
- **THEN** the direction vector remains unchanged — pure straight-line movement at full configured speed; repulsion loop produces zero force additions

### Requirement: MovementController exports configurable parameters per entity for cell-based grid movement and arrival behavior
Each entity scene's MovementController component SHALL expose @export fields for `move_speed`, `arrival_threshold` (default 1.0, ~half-cell), `cell_radius` (~1.0 m — half of the 2m × 2m cell size, used by radial repulsion steering to compute overlap radius as `cell_radius * 2.0`), and an optional `rotation_target_path: NodePath`. This allows per-unit tuning without modifying the script source.

#### Scenario: NodBuggy moves at 8 units/second with 1.0 arrival threshold
- **WHEN** NodBuggy.tscn has MovementController with move_speed = 8.0 and arrival_threshold = 1.0 in its scene export properties
- **THEN** the unit traverses distance proportional to speed * delta per physics frame, stopping when within ~1.0 units (half-cell) of target

#### Scenario: Infantry moves at different speed than vehicles with tighter threshold (future extensibility)
- **WHEN** a future infantry entity has MovementController with move_speed = 3.0 and arrival_threshold = 0.2 in its scene export properties
- **THEN** the component uses these exported values independently — no hardcoded speeds exist in the script

#### Scenario: NodBuggy rotation defaults to parent when no explicit path is provided
- **WHEN** MovementController's `rotation_target_path` field is left empty (not set) on a scene where the mesh root IS the scene root (e.g., NodBuggy.tscn with `$NodBuggy` as glb root node)
- **THEN** `_ready()` falls back to using the parent node as the rotation target — zero scene edits are required for existing entity scenes

---

## Phase 2 Requirements

### Requirement: Units pathfind via A* on 2m × 2m grid cells with 8-direction adjacency
When a move command is issued, the MovementController SHALL request a path from `Pathfinder.find_path(start, end)` which computes A* on a 2D grid of 2m × 2m cells. Paths use 8-direction adjacency (cardinal + diagonal) with `sqrt(2)` diagonal cost weighting and octile heuristic. The output is a `PackedVector3Array` of cell-center world positions forming the shortest path.

#### Scenario: Long-distance move produces multi-waypoint cell-aligned path
- **WHEN** a unit at cell (0,0) receives a move target at approximate world position (16, 0, 12)
- **THEN** `Pathfinder.find_path()` returns cell-center waypoints at (2,0,0), (4,0,2), (6,0,4), ..., (16,0,12) following the 8-dir adjacency rule with diagonal shortcuts where available

#### Scenario: Same-cell click produces no path (no movement)
- **WHEN** a unit receives a move target whose snapped cell is identical to the unit's current cell
- **THEN** `Pathfinder.find_path()` returns an empty `PackedVector3Array` and the unit remains IDLE

### Requirement: MovementController transitions through ROTATING state before MOVING
When `set_target_position()` receives a valid path, MovementController SHALL enter the ROTATING state. In ROTATING, the unit rotates in place toward the first waypoint direction via `atan2()` at `rotation_speed` degrees per second. Once within `rotation_angle_threshold` degrees of the target yaw, it transitions to MOVING.

#### Scenario: Unit rotates toward first waypoint before translating
- **WHEN** a unit at world position (0,0,0) receives a move command targeting cell (10,0,10)
- **THEN** the unit yaw rotates in place via `_handle_rotating(delta)` from its current facing toward the first waypoint direction; no position change occurs during this rotation

#### Scenario: Rotation completes within threshold and transitions to MOVING
- **WHEN** ROTATING state is active and `abs(angle_difference(current_yaw, target_yaw)) < deg_to_rad(rotation_angle_threshold)` evaluates true
- **THEN** `_rotation_target.global_rotation.y = target_yaw` (snaps to exact yaw), state transitions to MOVING, and the unit begins translating toward the waypoint

### Requirement: MovementController follows waypoint array with rotation between segments
After reaching each waypoint in the path (distance ≤ `arrival_threshold`), MovementController SHALL increment the waypoint index and transition back to ROTATING toward the next waypoint. On the final waypoint, the unit's position snap-fits to the exact cell center and the `arrived` signal emits.

### Requirement: Pathfinder is a static class with no scene tree dependency
`Pathfinder` SHALL be a static utility class providing coordinate conversion (`world_to_cell`, `cell_to_world`) and pathfinding (`find_path`) without requiring instantiation or scene references.

---

## Phase 3 Requirements

### Requirement: Units follow Catmull-Rom spline path instead of cell-to-cell waypoints
When MovementController receives a path from Pathfinder, it SHALL use a Catmull-Rom spline interpolated through the waypoints rather than advancing through them one at a time. A monotonic `_spline_t` advances 0→num_segments, and position+tangent are evaluated via Catmull-Rom basis functions.

#### Scenario: Spline produces smooth curves at turn points
- **WHEN** a path has an L-shape (e.g., go right then up), and spline is active
- **THEN** the unit follows a smooth arc through the corner rather than stopping and rotating at each waypoint

#### Scenario: Analytic tangent at t=0 gives valid direction
- **WHEN** MOVING state begins or `_spline_t` resets to 0.001
- **THEN** `_get_spline_tangent(t)` returns a non-zero vector — no zero-direction stutter

### Requirement: Spline re-projection prevents position drift
Each MOVING frame, after applying repulsion-adjusted step, the unit's position SHALL be lerped 20% back toward the spline position at `_spline_t`. This keeps the unit within millimeters of the spline, preventing the offset buildup that leads to off-path arrivals.

### Requirement: Ahead-only speed modulation for lane formation
Only neighbors with `to_neighbor.dot(spline_dir) > 0` (ahead of the unit along the spline) SHALL affect speed modulation. A smoothstep S-curve maps 0→1.5m ahead-distance to 0.3→1.0 speed factor.

#### Scenario: Trailing unit slows when close to ahead leader
- **WHEN** two units follow the same spline path and the trailing unit's forward neighbor is < 1.5m ahead
- **THEN** trailing unit decelerates via smoothstep curve, preventing rear-end collision

### Requirement: Repulsion weight fades to zero at destination
The repulsion steering multiplier SHALL be `clampf(dist_to_final / (cell_radius * 4.0), 0.0, 1.0)`. As the unit approaches its final cell, repulsion fades — at arrival, deviation is zero and the path is a pure straight shot to cell center.

### Requirement: WAIT state for blocked arrival
When MOVING spline is exhausted but the final cell is occupied by an IDLE unit, MovementController SHALL enter WAIT state. WAIT checks every physics frame whether the cell has freed. When freed, the unit lerps 0.3/frame toward cell center. If the cell remains blocked for `_wait_threshold` (10-25 frames, staggered per unit), it triggers scatter and re-paths to the nearest free cell.

#### Scenario: Unit in WAIT snaps to cell when target clears
- **WHEN** a unit is in WAIT state and the IDLE occupant vacates the target cell
- **THEN** the unit lerps 0.3/frame toward the cell center and transitions to IDLE on arrival

#### Scenario: WAIT timeout triggers re-path to nearest free cell
- **WHEN** WAIT count exceeds `_wait_threshold` and target cell is still blocked
- **THEN** `_scatter_blockers()` pushes nearby IDLE units, then `set_target_position(_find_nearest_free_cell(target_cell))` re-paths

### Requirement: Re-path on IDLE block during travel
Every 10 MOVING frames, if the next waypoint's cell is occupied by an IDLE unit, MovementController SHALL call `set_target_position(final_pos)` to compute a new path around the blocking unit.

---

## Phase 4 Requirements

### Requirement: A* uses binary min-heap with closed set for O(log n) performance
`Pathfinder.find_path()` SHALL maintain the open set as a binary min-heap via `_heap_push`/`_heap_pop` functions. A `closed_set` dictionary SHALL skip stale heap entries from f_score updates.

### Requirement: A* exploration is bounded
`Pathfinder.find_path()` SHALL enforce `MAX_ITER = 1500` iterations and `STAGNANT_LIMIT = 500` iterations without best-distance improvement. On exhaustion, it returns the best-effort path to the nearest reachable cell.

#### Scenario: Unreachable target returns path to nearest reachable cell
- **WHEN** the target cell is surrounded by IDLE units and no path exists
- **THEN** `find_path` returns a path to the closest cell that A* could reach, not an empty array

### Requirement: Weighted heuristic (×1.2) for faster convergence
The A* heuristic function SHALL be multiplied by 1.2, producing greedier convergence. Path length increase of ≤20% is acceptable for the performance gain.

### Requirement: Formation preservation on multi-unit move commands
`SelectionManager.request_move()` SHALL compute the group center, derive cell offsets per unit, clamp to 5×5 (±2 cells Chebyshev), reserve target cells, and fall back to nearest free cell if the formation target is occupied.

#### Scenario: 5 units move together preserving relative positions
- **WHEN** 5 selected units receive a move command
- **THEN** each unit targets a cell offset from the group center matching its offset from the old center, clamped to ±2 cells

### Requirement: Staggered dispatch (8/frame) for move commands
`SelectionManager.request_move()` SHALL populate a pending queue. `_process()` SHALL dispatch up to 8 moves per frame from the queue.

#### Scenario: 24 units dispatched over 3 frames
- **WHEN** 24 selected units receive a move command
- **THEN** 8 units receive A* paths on frame 1, 8 on frame 2, 8 on frame 3

### Requirement: Target reservation prevents destination conflicts
`SpatialHash` SHALL maintain a `_reserved` dictionary. `request_move()` clears it at start, `force_reserve`s all selected units' current cells, then `reserve_cell` for each formation target. `release_cell` is called on IDLE arrival.

#### Scenario: Two units never target the same cell
- **WHEN** two selected units have cell offsets that would place them at the same target cell
- **THEN** the second unit's `reserve_cell` returns false and `_fallback_target` spiral finds a free cell

### Requirement: IDLE cell centering on every physics frame
Every IDLE physics frame, unit position snaps to `Pathfinder.cell_to_world(Pathfinder.world_to_cell(_parent.global_position))`. This prevents accumulated sub-cell drift that causes visual inconsistency.

### Requirement: Scatter is deduplicated per physics frame
A static `_scattered_this_frame: Dictionary` tracks which neighbor cells have been scattered this frame. It is cleared via `Engine.get_process_frames()` tracking. Only the first WAIT unit per blocked cell per frame may scatter that cell.

### Requirement: Scatter push distance is 1 cell outward
`_scatter_blockers()` SHALL compute `push_cell = ncell + Vector2i(sign(dx), sign(dz))`. This pushes the IDLE unit exactly 1 cell away from its current position, not scaled by search radius.

### Requirement: WAIT exit uses lerp, not snap
When WAIT detects the target cell has freed, it SHALL lerp at 0.3/frame toward the cell center. Only when within 0.05m does it snap to exact center and emit `arrived`.

### Requirement: `_build_blocked_cells` uses SpatialHash + reservations
`_build_blocked_cells()` SHALL duplicate `SpatialHash.get_blocked_cells()`, then erase the caller's own cell and all reserved cells. This allows A* to route through vacating formation positions.

### Requirement: 120-unit test map with Buggy grid
TestMap01.tscn SHALL contain 120 Nod Buggy instances in a 12×10 grid, positioned around the map center. The PlaneMesh size SHALL be `Vector2(100, 100)` to accommodate the full grid.