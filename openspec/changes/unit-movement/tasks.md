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

- [x] 2.1 Implement `_get_ground_position_at_mouse()` using iterative terrain intersection
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
- [x] 13.2 Fix Node.name shadowing warning in DebugVisualizer (name→material_name)
- [x] 13.3 Remove excess approach_dir — uses (final_pos - parent_pos).limit_length()
- [x] 13.4 Remove _get_spline_pos lookahead at +0.05 (caused servo oscillation)

### 14. Test & verify Phase 3

- [ ] 14.1 Unit follows smooth spline path instead of cell-to-cell straight lines
- [ ] 14.2 Multi-unit repulsion keeps units apart mid-path without stutter
- [ ] 14.3 Units slow when ahead neighbor is close, front units maintain full speed
- [ ] 14.4 Smooth S-curve speed ramps, no hard cutoffs
- [ ] 14.5 Unit lands at cell center without visual snap or drift
- [ ] 14.6 Back unit re-paths around front IDLE unit blocking its waypoint
- [ ] 14.7 100+ units maintain stable framerate with SpatialHash