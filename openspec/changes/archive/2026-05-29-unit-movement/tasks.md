## Phase 1 (completed)

### 0. Create reusable ground plane scene and wire into map scenes

- [x] 0.1 Create `scenes/components/GroundPlane.tscn`
- [x] 0.2 Add GroundPlane instance in `scenes/maps/MapBase01.tscn`
- [x] 0.3 Add GroundPlane instance into `scenes/maps/TestMap01.tscn`

### 1. Create MovementController component (Phase 1)

- [x] 1.1 Create `scripts/components/MovementController.gd` as Node3D with class_name MovementController
- [x] 1.2 Add @export fields: move_speed, arrival_threshold, cell_radius, rotation_target_path
- [x] 1.3 Declare State enum { IDLE, MOVING } and private state variables
- [x] 1.4 Implement set_target_position with validation
- [x] 1.5 Implement _physics_process with radial repulsion steering
- [x] 1.6 Implement _ready() with rotation target resolution

### 2. Extend MouseHandler with left-click ground raycast for movement

- [x] 2.1 Implement `_get_ground_position_at_mouse()` using Plane math
- [x] 2.2 Modify `_handle_single_click()` with ground raycast fallback
- [x] 2.3 Preserve right-click behavior
- [x] 2.4 Preserve left-click entity selection path

### 3. Extend SelectionManager with movement API

- [x] 3.1 Add signal `move_requested(position: Vector3)`
- [x] 3.2 Implement public method `request_move(target_position: Vector3)`
- [x] 3.3 Implement private `_on_request_move()`
- [x] 3.4 Verify existing signals/methods remain functional

### 4. Wire MovementController into entity scenes

- [x] 4.1 Create `scenes/components/MovementController.tscn`
- [x] 4.2 Add MovementController instance under NodBuggy root
- [x] 4.3 Verify scene hierarchy

### 5. Test and verify Phase 1 movement

- [x] 5.1 Select NodBuggy in editor, left-click ground — unit moves
- [x] 5.2 Mesh rotates to face movement direction
- [x] 5.3 Arrival detection stops unit at threshold
- [x] 5.4 Right-click deselects all
- [x] 5.5 Ground raycast works with GroundPlane

## Phase 2 (completed)

### 6. Create Pathfinder static class

- [x] 6.1 Create `scripts/core/Pathfinder.gd` as static class with world↔cell conversion (2m cells)
- [x] 6.2 Implement A* with 8-direction adjacency and sqrt(2) diagonal cost weighting
- [x] 6.3 Implement `find_path(start_world, end_world) -> PackedVector3Array`
- [x] 6.4 Use octile heuristic for consistent grid distance

### 7. Upgrade MovementController to Phase 2

- [x] 7.1 Expand State enum to { IDLE, ROTATING, MOVING }
- [x] 7.2 Replace `_current_target` with `_waypoints` + `_waypoint_index`
- [x] 7.3 Implement `_handle_rotating(delta)` with lerp_angle toward first waypoint
- [x] 7.4 Integrate Pathfinder.find_path() in set_target_position()
- [x] 7.5 Add @export fields: rotation_speed, rotation_angle_threshold
- [x] 7.6 Replace single-target arrival with waypoint index advancement; snap final position to cell center
- [x] 7.7 Between-waypoint rotation: transition to ROTATING state for each segment

## Phase 3 — Spline Path Following & Multi-Unit Optimization (completed)

### 8. Replace waypoint chasing with Catmull-Rom spline

- [x] 8.1 Implement `_catmull_rom()` and `_catmull_rom_tangent()` static functions
- [x] 8.2 Add `_spline_t` monotonically advancing 0→num_segments
- [x] 8.3 Add `_get_spline_pos(t)` and `_get_spline_tangent(t)` with Catmull-Rom interpolation
- [x] 8.4 Use analytic tangent for direction in both ROTATING and MOVING states
- [x] 8.5 Advance _spline_t by real distance traveled (step.length() / seg_length)
- [x] 8.6 Remove corner_blend_radius — spline handles curvature intrinsically

### 9. Multi-unit repulsion & speed modulation

- [x] 9.1 Replace STEERING_RADIUS with REPULSION_STRENGTH = 0.1
- [x] 9.2 Inverse-square push-away from non-IDLE neighbors in 3×3 cell range
- [x] 9.3 Repulsion weight fades to 0 at target (clampf(dist_to_final / 4m, 0, 1))
- [x] 9.4 Deviation clamp fades with repulsion_weight (0.3 * weight)
- [x] 9.5 Ahead-only speed modulation: only neighbors with dot(spline_dir) > 0 slow the unit
- [x] 9.6 smoothstep S-curve maps 0→1.5m distance to 0.3→1.0 speed
- [x] 9.7 Per-unit speed jitter randf_range(0.95, 1.0)

### 10. Smooth arrival & WAIT state

- [x] 10.1 Spline re-projection: 20% lerp back to spline each MOVING frame
- [x] 10.2 Approach phase: direct shot to cell center after spline exhaustion
- [x] 10.3 Snap threshold at <0.001m for invisible final placement
- [x] 10.4 WAIT state only checks final target cell (not intermediate waypoints)
- [x] 10.5 WAIT timeout at 60 frames to prevent deadlocks
- [x] 10.6 WAIT backs up _spline_t to num_segments - 0.01 and retries ROTATING

### 11. SpatialHash autoload for O(N²)→O(9) optimization

- [x] 11.1 Create `scripts/core/SpatialHash.gd` with grid rebuild every _process
- [x] 11.2 Register as autoload in project.godot (SpatialHashSingleton)
- [x] 11.3 Swap repulsion loop from get_nodes_in_group to 3×3 cell queries
- [x] 11.4 Swap _is_cell_occupied_by_idle to SpatialHash.is_cell_idle()
- [x] 11.5 Swap _build_blocked_cells to SpatialHash.all_entries()

### 12. Collision avoidance enhancements

- [x] 12.1 Re-path on IDLE cell: check next waypoint cell every 10 frames
- [x] 12.2 Remove _is_cell_occupied_by_any — replaced with IDLE-only checks
- [x] 12.3 _repair_frames throttle prevents infinite A* loops

### 13. Polish & cleanup

- [x] 13.1 rotation_speed = 240.0 on NodBuggy for responsive turning
- [x] 13.2 Fix Node.name shadowing warning in DebugVisualizer
- [x] 13.3 Remove excess approach_dir — uses (final_pos - parent_pos).limit_length()
- [x] 13.4 Remove _get_spline_pos lookahead at +0.05 (caused servo oscillation)

## Phase 4 — Group Movement & A* Hardening (completed)

### 14. A* performance rewrite

- [x] 14.1 Replace O(n) linear scan with binary min-heap (`_heap_push`/`_heap_pop`)
- [x] 14.2 Add closed set to skip stale heap entries from f_score updates
- [x] 14.3 Add MAX_ITER=1500 bound on exploration
- [x] 14.4 Add STAGNANT_LIMIT=500 — exit early when no best-dist improvement
- [x] 14.5 Add best-effort routing: track nearest reachable cell, return path to it on exhaustion
- [x] 14.6 Apply heuristic ×1.2 weighting for greedy convergence

### 15. Formation preservation & staggered dispatch

- [x] 15.1 Compute group center in `request_move()`
- [x] 15.2 Derive cell offsets from group center, clamp to ±2 cells (5×5 core)
- [x] 15.3 Reserve target cells; fallback spiral to nearest free cell if occupied
- [x] 15.4 Implement `_pending_moves` queue with 8/frame dispatch in `_process()`
- [x] 15.5 Add `_fallback_target()` — expanding spiral radius 1→8
- [x] 15.6 Remove old `_compute_spread()` function

### 16. Target reservation system

- [x] 16.1 Add `_reserved` dictionary to SpatialHash
- [x] 16.2 Implement `reserve_cell(cell)` → bool (fails if reserved or blocked)
- [x] 16.3 Implement `force_reserve(cell)` — skips blocked check (for group vacating)
- [x] 16.4 Implement `release_cell(cell)` — called on IDLE arrival
- [x] 16.5 Implement `clear_reservations()` — called at start of `request_move()`
- [x] 16.6 Add `get_reserved()` — used by `_build_blocked_cells` for erasure
- [x] 16.7 `force_reserve` all selected units' cells before computing formation

### 17. IDLE cell centering

- [x] 17.1 Snap IDLE position to cell center every physics frame

### 18. WAIT state escape (staggered)

- [x] 18.1 Add per-unit `_wait_threshold = 10 + randf_range(0, 15)` at _ready()
- [x] 18.2 Add early scatter at WAIT frame 15
- [x] 18.3 On WAIT timeout: call `_scatter_blockers()` then re-path to nearest free cell
- [x] 18.4 On WAIT cell-free: lerp 0.3/frame toward cell center (no snap, no A*)

### 19. Scatter improvements

- [x] 19.1 Change scatter to spiral radius 1→3 (was radius 1 only)
- [x] 19.2 Deduplicate scatter per physics frame via static `_scattered_this_frame` dict
- [x] 19.3 Gate clear with `Engine.get_process_frames()` + `_last_physics_frame`
- [x] 19.4 Fix push distance to `push_cell = ncell + sign(dx, dz)` (1 cell, no scaling)
- [x] 19.5 Add `force_reserve` of source cell before scatter dispatch
- [x] 19.6 Self-recursion guard (`mc != self`)

### 20. `_build_blocked_cells` rewrite

- [x] 20.1 Use `SpatialHash.instance.get_blocked_cells().duplicate()` (no all_entries scan)
- [x] 20.2 Erase caller's own cell + all reserved cells
- [x] 20.3 Remove old all_entries scanning loop

### 21. 120-unit test map

- [x] 21.1 Add 114 more Nod Buggy instances to TestMap01 (total 120)
- [x] 21.2 Arrange in 12×10 grid
- [x] 21.3 Enlarge PlaneMesh to `size = Vector2(100, 100)`
- [x] 21.4 Hide debug ground plane (`visible = false`)
- [x] 21.5 Re-index BoundsSystem, MeshInstance3D, GroundPlane

### 22. OpenSpec documentation

- [x] 22.1 Update proposal.md with Phase 3-4 scope
- [x] 22.2 Update design.md with new decisions (heap, stagger, scatter dedup, reservation, formation)
- [x] 22.3 Update spec.md with Phase 4 requirements
- [x] 22.4 Update tasks.md with Phase 4 task list