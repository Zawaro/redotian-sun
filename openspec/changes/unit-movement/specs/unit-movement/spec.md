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
When `set_target_position()` receives a valid path, MovementController SHALL enter the ROTATING state. In ROTATING, the unit rotates in place toward the first waypoint direction via `lerp_angle()` at `rotation_speed` degrees per second. Once within `rotation_angle_threshold` degrees of the target yaw, it transitions to MOVING. The same ROTATING → MOVING sequence repeats between every waypoint segment.

#### Scenario: Unit rotates toward first waypoint before translating
- **WHEN** a unit at world position (0,0,0) receives a move command targeting cell (10,0,10) — first waypoint is diagonally NE
- **THEN** the unit yaw rotates in place via `_handle_rotating(delta)` from its current facing toward NE (135° on isometric) using `lerp_angle(current_yaw, target_yaw, rotation_speed * delta / 180.0)`; no position change occurs during this rotation

#### Scenario: Rotation completes within threshold and transitions to MOVING
- **WHEN** ROTATING state is active and `abs(angle_difference(current_yaw, target_yaw)) < deg_to_rad(rotation_angle_threshold)` evaluates true
- **THEN** `_rotation_target.global_rotation.y = target_yaw` (snaps to exact yaw), state transitions to MOVING, and the unit begins translating toward the waypoint

#### Scenario: Unit already facing target — ROTATING immediately transitions to MOVING
- **WHEN** a unit is already oriented within `rotation_angle_threshold` degrees of the first waypoint when `set_target_position()` is called
- **THEN** `_handle_rotating()` runs one physics frame and immediately transitions to MOVING — no visual stutter or perceptible delay

### Requirement: MovementController follows waypoint array with rotation between segments
After reaching each waypoint in the path (distance ≤ `arrival_threshold`), MovementController SHALL increment the waypoint index and transition back to ROTATING toward the next waypoint. On the final waypoint, the unit's position snap-fits to the exact cell center and the `arrived` signal emits.

#### Scenario: Unit rotates between each waypoint on a multi-cell path
- **WHEN** a path has 4 waypoints (e.g., a 3-cell L-shape), and the unit arrives at waypoint 1 within threshold
- **THEN** `_waypoint_index` increments from 0 to 1, state transitions to ROTATING, unit rotates toward waypoint 2 direction before translating — repeating until the final waypoint is reached

#### Scenario: Final arrival snaps position to exact cell center
- **WHEN** `_waypoint_index >= _waypoints.size()` after arrival detection on the last waypoint
- **THEN** `_parent.global_position = Pathfinder.cell_to_world(Pathfinder.world_to_cell(_parent.global_position))` — the unit's position is exactly centered on the target cell before `arrived` emits

### Requirement: MovementController exports rotation parameters
MovementController SHALL expose `@export` fields `rotation_speed: float = 180.0` (degrees per second) and `rotation_angle_threshold: float = 5.0` (degrees, range 1.0–45.0) for per-unit tuning of rotation behavior.

#### Scenario: Fast rotation_speed produces near-instant spin-up
- **WHEN** a vehicle's MovementController has `rotation_speed = 720.0` and `rotation_angle_threshold = 2.0`
- **THEN** the ROTATING state completes in approximately 0.25s for a 180° turn — suitable for responsive units like scout buggies

#### Scenario: Slow rotation_speed gives heavy-tank feel
- **WHEN** a tank entity has `rotation_speed = 90.0` and `rotation_angle_threshold = 10.0`
- **THEN** the ROTATING state takes ~2s for a 180° turn with a wider acceptance angle — matching Tiberian Sun's slower vehicle handling

### Requirement: Pathfinder is a static class with no scene tree dependency
`Pathfinder` SHALL be a static GDScript class at `scripts/core/Pathfinder.gd` with no extends/class_name supertype. All methods are `static func`. It provides coordinate conversion (`world_to_cell`, `cell_to_world`) and pathfinding (`find_path`) without requiring instantiation or scene references.

#### Scenario: Pathfinder used without instantiation
- **WHEN** any script calls `Pathfinder.find_path(Vector3(0,0,0), Vector3(8,0,8))`
- **THEN** the method returns a `PackedVector3Array` without requiring `Pathfinder.new()` — the class is purely static
