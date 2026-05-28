## Why

Units (like the Nod Buggy) can be selected via left-click/ray-cast but have no movement system to issue move commands. Right-click currently only deselects, breaking the fundamental RTS input-to-action loop required for all gameplay — combat, economy, base building depend on units reaching targets.

## What Changes

### Phase 1 (completed)
- **New `MovementController` component** (`scripts/components/MovementController.gd`) — attached to entity scenes as a child node; handles path following toward target position, Y-axis rotation facing movement direction, arrival detection at configurable threshold, and state transitions (Idle → Moving → Arrived)
- **Extend `_handle_single_click()` in `MouseHandler.gd` with left-click ground move command** — when left-click raycast finds no entity under cursor, cast a second ray against terrain/ground plane; if any units are selected, emit `move_requested(position)` via SelectionManager. RMB (`deselect_entity`) behavior is unchanged: always calls `selection_manager.deselect_all()`
- **Extend `SelectionManager.gd` with movement API** — new signal and method (`request_move`, `_on_request_move`) that broadcasts move targets to all selected entities possessing a MovementController component
- **Ground collision layer constant** — dedicated raycast mask targeting default physics layer for terrain intersection, distinct from entity detection at bit 15

### Phase 2 (current)
- **New `Pathfinder` static class** (`scripts/core/Pathfinder.gd`) — A* pathfinding on 2m × 2m grid cells with 8-direction adjacency and diagonal cost weighting
- **MovementController ROTATING state** — vehicles now rotate in place toward the first waypoint before translating, with configurable `rotation_speed` and `rotation_angle_threshold`
- **Waypoint array path following** — MovementController consumes `PackedVector3Array` from Pathfinder, iterating waypoints with rotate-transition between each
- **Cell-snapped arrival** — final position snaps to nearest cell center, all waypoints are cell-aligned

### Planned Phase 3 (terrain cells with ramps, height, obstacles)
- Terrain-aware A* with movement cost modifiers per cell type
- Downward raycast for Y-axis terrain following (height mapping)
- Cell occupancy blocking (buildings, walls block pathfinding) with dynamic recalculation

| Area | Details |
|------|---------|
| **Scripts** | New: `scripts/core/Pathfinder.gd`; Modified: `scripts/components/MovementController.gd` |
| **Scenes** | No scene changes needed — MovementController.tscn and NodBuggy.tscn wired in Phase 1 remain valid |
| **Project config** | No changes |
| **Existing behavior** | Left-click selection, right-click deselect, ground raycast all preserved unchanged |
