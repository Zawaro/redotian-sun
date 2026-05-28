## Context

The project currently has entity selection working via `MouseHandler.gd` — left-click raycasts against collision layer 15 to find entities with `SelectComponent`. Right-click is bound only to deselection in `project.godot`. Units have HealthComponent, HitboxComponent, and SelectComponent but no movement logic. The camera system (CameraController) already handles WASD panning, border panning, and middle-mouse slide-to-pan — so input infrastructure exists for other mouse actions.

The architecture follows a component pattern: each entity scene bundles reusable node children (`HealthComponent`, `HitboxComponent`, `SelectComponent`). Movement should follow this same pattern to stay composable across future unit types (infantry, vehicles, structures).

## Phase 1 (completed)

**Goals:**
- Selected units move when player left-clicks on empty ground (not an entity), with smooth Y-axis rotation toward travel direction
- Left-click on terrain sends a single `move_requested(position)` command broadcast to all selected entities via SelectionManager — only if at least one unit is currently in selection
- Units stop at configurable arrival threshold; straight-line movement (no pathfinding)
- Right-click remains simple deselection with zero changes to existing behavior

**Non-Goals:**
- Pathfinding/A* navigation
- Attack-move, patrol routes, formations
- Terrain cost modifiers and speed variation by terrain type
- Obstacle avoidance during movement (radial repulsion steering was added instead)

## Phase 2 (current implementation)

**Goals:**
- Units pathfind via A* on 2m × 2m cell grid with 8-direction adjacency
- Units rotate in place toward the first waypoint before starting translation (ROTATING state)
- Each waypoint segment follows the same rotate-before-move pattern
- Final position snaps to nearest cell center on arrival
- All movement parameters configurable via @export (rotation_speed, rotation_angle_threshold)

**Non-Goals:**
- Terrain cost modifiers (Phase 3)
- Cell occupancy blocking by buildings/obstacles (Phase 3)
- Terrain height / Y-axis following via downward raycast (Phase 3)
- Attack-move, patrol routes, formations (deferred per plans/2-2_movement_commands.md)

## Phase 3 (planned — not in current scope)

**Goals:**
- Terrain-aware A* with movement cost modifiers (flat=1.0x, road=0.7x, tiberium=1.2x, water=blocked)
- Downward raycast for Y-axis terrain following (units follow elevation changes)
- Cell occupancy blocking — buildings, walls, cliffs block pathfinding; dynamic recalculation when blocked mid-navigation
- Movement curve smoothing (bezier/catmull-rom between waypoints)

## Decisions

### Decision: MovementController as a child component on entity scenes
**Choice:** `MovementController` is attached as a child node in each movable entity scene, following the existing pattern (`HealthComponent`, `HitboxComponent`, `SelectComponent`). It exports references to sibling nodes (e.g., `select_component`) for integration.

**Rationale:** This matches the established component architecture and keeps scenes self-contained. The SelectionManager iterates selected entities via `"entities"` group — each entity's MovementController is addressed by path (`entity.get_node("MovementController")`). Alternative approaches considered:
- *Autoload singleton controller*: Would centralize all movement logic but creates a God-object anti-pattern; doesn't scale to per-unit state (position, target, speed).
- *Extending SelectComponent*: Mixes selection visuals with movement — violates single responsibility. SelectComponent already manages outline shapes and health bars.

### Decision: Y-axis rotation via `look_at()` on XZ plane during MOVING; `atan2()` in ROTATING state
**Choice:** Two rotation mechanisms depending on state:
1. **ROTATING state**: Uses `atan2(target_dir.x, target_dir.z)` with `lerp_angle()` at `rotation_speed` deg/s for the pre-move rotation phase. The rotation is frame-interpolated and the state transitions to MOVING when within `rotation_angle_threshold` degrees of target yaw.
2. **MOVING state**: Uses `_rotation_target.look_at(parent_pos + Vector3(final_direction.x, parent_pos.y, final_direction.z))` for continuous heading updates during translation, preserving the Y-component to prevent pitch/roll artifacts per gameidea tutorial lessons.

**Rationale:** ROTATING needs smooth interpolation toward a specific yaw anchor (no overshoot). MOVING needs continuous realignment from frame to frame as direction shifts due to repulsion steering. Two approaches serve different needs — splitting them avoids the `lerp_angle()` always-lagging-behind problem during active travel.

### Decision: Cell-snapped A* pathfinding on 2m × 2m grid
**Choice:** A new static `Pathfinder` class converts world positions ↔ 2D cell coordinates (`Vector2i`), runs A* with 8-direction adjacency and `sqrt(2)` diagonal cost weighting, and outputs a `PackedVector3Array` of cell-center world positions. MovementController snap-fits its final position to the nearest cell center on arrival via `Pathfinder.cell_to_world(Pathfinder.world_to_cell(...))`.

**Rationale:** 2m × 2m cells match the grid planning in `plans/2-1_navigation.md` and the existing `cell_radius = 1.0` convention. The static class design keeps pathfinding decoupled from scene tree — unit tests and terrain systems can call `Pathfinder.find_path()` directly. Waypoint arrays align naturally with the existing `_current_target: Vector3` → `_waypoints: PackedVector3Array` migration path described in Phase 1 design.

**Grid Resolution:** 2m cells, each vehicle occupies one cell (radius = 1.0 m). Original Tiberian Sun used a finer grid (0.5m) — the 2m resolution is a simplification for Phase 2 that maintains the gameplay feel while reducing A* search space.

### Decision: ROTATING state is part of MovementController state machine
**Choice:** MovementController's `State` enum grows from `{ IDLE, MOVING }` to `{ IDLE, ROTATING, MOVING }`. `set_target_position()` always transitions to `ROTATING`, which interpolates yaw toward the first waypoint, then auto-transitions to `MOVING`. Between waypoints, the same ROTATING → MOVING sequence repeats.

**Rationale:** Vehicle units in Tiberian Sun rotate toward their destination before driving forward. Adding this as a dedicated state keeps transitions explicit and prevents the "driving sideways" visual bug that would occur if rotation was mixed into the MOVING state's `look_at()` call.

**Edge cases:**
- If the unit is already facing the target direction (±threshold), ROTATING immediately transitions to MOVING (one frame skip, no visual stutter)
- If `_rotation_target` is invalid, ROTATING falls through to MOVING without crashing
- Re-clicking mid-rotation resets the entire path and restarts ROTATING toward the first new waypoint

### Decision: Left-click moves selected units on empty ground; right-click always deselects
**Choice:** `MouseHandler._handle_single_click()` already raycasts at mask `1 << 15` for entity detection. When no entity is hit (no collider found), a second raycast against default layer (`1`) finds the terrain intersection point, which becomes the move target — but only if there are currently selected entities with MovementController. Right-click (`deselect_entity`) remains untouched: it always calls `selection_manager.deselect_all()`.

**Rationale from research:** This matches standard RTS conventions (e.g., Tiberian Sun) where left-click is the primary interaction for both selection and movement commands, while right-click serves as a universal "cancel/deselect" action. The existing `_handle_single_click()` method already does the entity raycast — we simply add an `else` branch to handle terrain clicks without duplicating any code or changing entity hit behavior.

### Decision: SelectionManager owns move broadcast, not MouseHandler
**Choice:** `MouseHandler` only detects the ground click position via raycast and calls `SelectionManager.request_move(position)`. The SelectionManager then iterates selected entities (tracked in existing selection data structures) and instructs each one's MovementController to set its target.

**Rationale from research:** Following the RTS-Entity-Controller pattern found online, a central input system (`PlayerInput` autoload) collects commands and dispatches them via signals. Since SelectionManager is already an autoload singleton with `selection_changed` signal, it's the natural owner for movement broadcasts — MouseHandler stays focused on raycasting + selection only. This keeps concerns separated: Input → Command Dispatch (SelectionManager) → Unit Execution (MovementController).

### Decision: Phase 2 uses A* from Pathfinder static class; Phase 3 adds terrain costs + occupancy
**Choice:** Phase 2 A* treats all cells as equal-cost (walkable), producing cell-aligned paths with diagonal shortcuts. The Pathfinder class exposes `static func find_path(start_world, end_world) -> PackedVector3Array` and `static func is_cell_blocked(cell) -> bool` which Phase 3 will enrich with terrain costs and occupancy data.

**Rationale:** Starting with equal-cost A* validates the pathfinding pipeline end-to-end (world↔cell conversion, path reconstruction, waypoint execution) before adding terrain complexity. The static interface allows terrain systems in Phase 3 to register cost data via a singleton or global dictionary without modifying Pathfinder's A* core.

### Decision: Kinematic movement (Node3D base, no physics bodies) 
**Choice:** `MovementController extends Node3D`, not CharacterBody3D or RigidBody3D. Units are moved purely via direct position updates (`global_position += direction * speed * delta`) in `_physics_process()`. No gravity, no collision shapes on units themselves — vehicles pass through static geometry without physics engine overhead.

**Rationale from research:** Multiple Godot RTS tutorials (gameidea's 10-part series, lampe-games/open-rts with 1k stars) use direct `global_position` updates for unit movement rather than CharacterBody3D + move_and_slide(). This is because: (a) RTS units typically should NOT collide physically — they pass through each other or flow around via steering behavior; (b) Physics engine overhead scales poorly at large unit counts, while kinematic updates are O(1) per unit regardless of scene complexity; (c) CharacterBody3D's `is_on_floor()` and gravity features are not needed when units move on flat test maps. A downward terrain-following raycast is deferred to Phase 3.

**Migration path:** If a future unit type needs physics-based interaction (e.g., explosive knockback that pushes other vehicles), MovementController can be extended without breaking existing scenes — just check `has_node("PhysicsBody")` in `_physics_process()` and conditionally apply physical forces instead of kinematic position updates. The core movement loop remains unchanged.

### Decision: Radial repulsion steering for obstacle avoidance on 2m grid cells
**Choice:** Units avoid each other via radial repulsion — during `_physics_process(delta)`, iterate all nodes in the `"entities"` group within ~3 m radius and add push-away forces proportional to inverse squared distance when `distance_to(neighbor) < cell_radius * 2.0`. This is layered on top of the base movement direction before final normalization.

**Rationale from research:** The gameidea RTS tutorial notes that steering behaviors can be "implemented as combination of ray casting and math functions to loosely calculate vicinity in different directions." Radial repulsion produces natural lane formation without any grid occupancy map or global pathfinding — when two units converge on the same target, their opposing push-away vectors cause them to pass around each other like water flowing around rocks. This matches Tiberian Sun's traffic feel at low computational cost (one distance check per entity pair within proximity).

## Risks / Trade-offs

| Risk | Impact | Mitigation |
|------|--------|------------|
| A* on 2m cells is coarse — some paths may look unnatural or clip scenery corners | Low — typical for Tiberian Sun's original grid system; Phase 3 smoothing (bezier interpolation) addresses visual quality | Acceptable for Phase 2; smoothing added when terrain height system arrives |
| ROTATING state adds one extra frame latency between click and movement start | Low — ~16ms at 60fps; matches original Tiberian Sun vehicle behavior where units spin up before driving | Configurable via `rotation_speed` export (higher value = faster spin-up) |
| Units may overlap during radial repulsion if push-away vectors cancel | Low — rare edge case with 3+ units in tight formation; produces temporary micro-pause rather than permanent stack | Phase 3 navmesh waypoints provide deterministic ordering that eliminates this class of issue |
| Left-click on empty ground with no units selected does nothing silently | Informational only — not a bug since there are no units to move | None required |
| Kinematic movement means vehicles cannot follow terrain elevation changes | Medium — Y=0 plane assumption breaks on ramped terrain; visible on maps with slopes | Phase 3 downward raycast resolves this; Phase 2 maps remain flat |
| Pathfinder treats all cells as walkable — no obstacle awareness | Medium — units path through buildings/blocked cells; only visible when buildings are placed on test maps | Phase 3 adds `is_cell_blocked()` with dynamic obstacle data |

## Migration Plan

Phase 2 is purely additive:
1. New script file `scripts/core/Pathfinder.gd` (static class, no scene tree dependency)
2. `scripts/components/MovementController.gd` rewritten from Phase 1 → Phase 2 (state enum grows, waypoints, A* integration, rotation handling)

Rollback: restore Phase 1 version of MovementController.gd, delete Pathfinder.gd. No scene files or project config changed.
