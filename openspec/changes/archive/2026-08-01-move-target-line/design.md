## Context

`SelectComponent` (an `Area3D` child of each entity) already draws a rally line for buildings: it finds a sibling `RallyPointComponent`, creates a runtime `MeshInstance3D` + `ImmediateMesh` with an unshaded green `ORMMaterial3D` (`no_depth_test`, `render_priority = 100`), and redraws it on demand. `MovementController` (a sibling `Node3D`) already owns the unit's waypoint list and movement state machine (`IDLE / ROTATING / MOVING / WAIT`) but exposes neither the current destination nor a "started moving" event.

The move target line mirrors the rally line, but for units instead of buildings, and is time-boxed to 1 second instead of persistent.

## Goals / Non-Goals

**Goals:**
- Show a green line from a selected, moving unit to its destination cell for 1 second, with a filled marker at the destination.
- Reuse the rally line's material/layer treatment and the same sibling-lookup pattern.
- No `.tscn` changes — everything is created at runtime.

**Non-Goals:**
- Persistent path rendering or multi-waypoint (queued order) visualization.
- Per-order color coding by ownership/relationship.
- Configurable duration or styling.

## Decisions

- **`MovementController` API additions.** Add `get_target_position()` (returns the last waypoint, or the parent's position when idle), `is_moving()` (`_state != State.IDLE`, so the line also covers the brief `ROTATING` pre-turn and `WAIT`), and a `movement_started` signal. The signal is what lets the line appear the moment a *already-selected* unit is ordered to move — `_update_visibility()` alone only fires on selection/hover changes.
- **`movement_started` fires only for genuine player orders.** `set_target_position()` is also called for internal re-paths (repair/wait) and for scatter/nudge pushed onto *other* units. Emitting on every call restarts a selected unit's line during congested movement and shows a phantom line on an idle selected unit scattered by a neighbor. So `set_target_position()` takes an `internal := false` param and emits `movement_started` only when `internal` is false; the order entry points (`SelectionManager._execute_move` and `MovementController.get_order_for_target`) use the default, internal re-paths and scatter/nudge pass `true`. The signal is emitted only after `_waypoints` is populated, so consumers reading the destination at signal time never see the stale/empty path (this also means a move that fails pathfinding emits nothing — no phantom line).
- **Timer-driven visibility.** A one-shot `Timer` (1.0s) child controls the line. Start/restart edges: (a) `movement_started` while selected, (b) becoming selected while already moving. `Timer.start()` restarts a running timer, which naturally satisfies "reselect restarts". Timeout hides the line. Deselect stops the timer and hides immediately.
- **Do not drive the line from the shared visibility loop.** `_update_visibility()` force-sets `.visible` on all non-excluded children; the move line mesh and the timer are excluded (the timer has no `visible` property, and the line's visibility is timer-owned). Selection edges call a dedicated helper instead.
- **Per-frame redraw while visible.** The line is drawn in the component's local space (`Vector3.ZERO` → `to_local(destination)`). Since the unit moves during the 1s window, `_process()` redraws each frame while the mesh is visible so the origin tracks the unit. Cheap: two vertices plus a four-vertex marker.
- **Attack target overrides the destination.** While the unit has an active attack target (`CombatComponent.get_target()` is valid), the endpoint is the enemy's current `global_position` instead of the move order's stop cell, so the marker points at (and tracks) the enemy as it approaches and fires. The per-frame redraw keeps it tracking the enemy's motion. A player move clears the attack target on the same `movement_started` emit, so the line falls back to the move destination without flashing the old enemy.
- **Selection shows the line for stationary attackers too.** `_update_move_line_on_select()` shows the line when the unit is moving *or* has an active attack target, so an in-range attacker (stationary, firing) that is deselected and re-selected still shows the line pointing at the enemy — the line would otherwise require `is_moving()` and disappear for a unit that has already reached weapon range.
- **Marker = filled quad at cell center.** The destination is snapped to its cell center (`CellUtil.cell_to_world(CellUtil.world_to_cell(target))`) so the marker sits on the grid, drawn as two triangles (`PRIMITIVE_TRIANGLES`) — a small filled green rectangle (`half := 0.125`, i.e. 0.25×0.25 units), distinct from the rally line's hollow diamond. Both feedback lines use the darker green `Color(0.0, 0.8, 0.0, 0.9)`.

## Risks / Trade-offs

- `is_moving()` includes `ROTATING`/`WAIT`, slightly broader than the issue's literal "MOVING" wording, but avoids the line flickering off during a vehicle's initial turn. Accepted.
- On arrival mid-window the state goes `IDLE` but waypoints are not cleared, so the line collapses to a near-zero-length stub at the unit for the remainder of the second. Harmless and invisible in practice.
- Per-frame redraw runs only while the line is visible (≤1s per order), so cost is negligible.
