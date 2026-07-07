## Why

Units (like the Nod Buggy) can be selected via left-click/ray-cast but had no movement system to issue move commands. Right-click only deselected, breaking the fundamental RTS input-to-action loop required for all gameplay — combat, economy, base building depend on units reaching targets.

Later phases addressed performance collapse at 48+ units: A\* was O(n) heap, WAIT deadlocks had no escape, IDLE units created impassable walls, scatter flung units across the map, and burst A\* calls on WAIT timeout caused multi-frame stutters.

## What Changes

### Phase 1 (completed)
- **New `MovementController` component** — attached to entity scenes as a child node; handles path following, Y-axis rotation facing movement direction, arrival detection, and state transitions
- **MouseHandler left-click ground raycast** — when left-click raycast finds no entity, cast against terrain; if units selected, emit `move_requested(position)` via SelectionManager
- **SelectionManager movement API** — new signal and method that broadcasts move targets to selected entities with MovementController
- **Ground collision layer constant** — dedicated raycast mask for terrain intersection, distinct from entity detection at bit 15

### Phase 2 (completed)
- **Pathfinder static class** — A\* pathfinding on 2m × 2m grid cells with 8-direction adjacency and diagonal cost weighting
- **MovementController ROTATING state** — vehicles rotate toward first waypoint before translating
- **Waypoint array path following** — consumes `PackedVector3Array` from Pathfinder, rotating between segments
- **Cell-snapped arrival** — final position snaps to nearest cell center on arrival

### Phase 3 (completed) — Performance & Quality
- **Catmull-Rom spline path following** — replaces cell-to-cell straight-line waypoints for smooth curves
- **Multi-unit repulsion steering** — 3×3 cell neighbor queries via SpatialHash, inverse-square push-away
- **Ahead-only speed modulation** — only neighbors ahead of spline direction slow the unit; smoothstep 0.3→1.0 speed curve
- **Spline re-projection** — 20% lerp back to spline each MOVING frame prevents offset drift
- **SpatialHash autoload** — O(N²)→O(9) neighbor queries, reservation system, IDLE-only blocked dict
- **Re-path on IDLE block** — every 10 frames, checks if next waypoint is IDLE-occupied and re-paths

### Phase 4 (completed) — Group Movement & A\* Hardening
- **A\* binary min-heap + closed set** — O(log n) instead of O(n) linear scan per iteration
- **MAX_ITER=1500 + STAGNANT_LIMIT=500** — bounds exploration; best-effort fallback to nearest reachable cell
- **Weighted heuristic ×1.2** — 2-3× faster convergence, ≤20% longer path
- **Formation preservation** — group center → cell offset → 5×5 clamp (Chebyshev radius 2) → fallback spiral
- **Staggered dispatch (8/frame)** — `_process` batch loop avoids 48 simultaneous A\* calls
- **Target reservation system** — `reserve_cell`/`force_reserve`/`release_cell`/`clear_reservations` in SpatialHash
- **WAIT state escape** — staggered threshold (10-25f), early scatter at frame 15, re-path to nearest free cell, lerp 0.3 on cell free
- **Scatter spiral radius 3 + dedup** — pushes IDLE neighbors 1 cell outward; only first WAIT unit per cell per frame pays scatter cost
- **`_build_blocked_cells` from SpatialHash** — erases own cell + reserved cells before A\*; no all_entries scan
- **IDLE cell centering** — cell snap each IDLE physics frame ensures consistent cell alignment
- **120-unit test map** — TestMap01 updated with grid of Nod Buggies for stress testing

| Area | Details |
|------|---------|
| **Scripts** | New: `scripts/core/Pathfinder.gd`, `scripts/core/SpatialHash.gd`, `scripts/core/DebugVisualizer.gd`; Modified: `scripts/components/MovementController.gd`, `scripts/core/SelectionManager.gd` |
| **Scenes** | Modified: `scenes/entities/units/nod/NodBuggy.tscn`, `scenes/maps/TestMap01.tscn` |
| **Project config** | Autoload registration for `SpatialHashSingleton` |
| **Existing behavior** | All selection, camera, and HUD behavior preserved unchanged |