## Context

Post-shroud-fix profile on `perf/279-mass-infantry-move-fps-drop`: physics healthy (8.76ms/frame), but **Process time spikes to 23.42ms/frame at move-order time**, decaying over 3–5s. Two measured contributors:

1. **Move-target lines**: 60 selected infantry, each `SelectComponent._redraw_move_line()` rebuilds its own 3D `ImmediateMesh` (`clear_surfaces` + 2 `surface_begin/end` blocks = GPU vertex-buffer re-upload + new buffer alloc) **every frame** while the line is visible (currently a 1s one-shot timer). 60 meshes × 2 surfaces × 60fps ≈ 7,200 surface ops/s.
2. **Pathfinding burst**: `SelectionManager._process` drains `_pending_moves` at 8/frame; each `_execute_move` → `MovementController.set_target_position` → `Pathfinder.find_path` (A*). ~11.4ms cumulative, and re-paths during the congested scramble stretch the decay to ~3–5s.

`DebugVisualizer` already exists as a batched-line precedent (autoload owning a mesh), but its `draw_path` is debug-gated — gameplay feedback must not route through a debug gate.

## Goals / Non-Goals

**Goals:**
- Collapse 60 per-unit ImmediateMesh move-line rebuilds into ONE shared buffer rebuild per frame; keep the exact visual (green per-unit line + destination marker, attack-target tracking).
- Cut the order-time pathfinding burst from ~60 A* to a handful of reverse-frontier expansions for sharer-only squads; keep per-unit behavior for everything else.
- Shorten the line's visibility so steady state renders no lines.
- Land it with tests and keep the existing suite green.

**Non-Goals:**
- Not changing the A* core for vehicles/crushers/jumpjets/subterranean units (per-unit `find_path` stays).
- Not touching the SelectionOverlay (profile shows the drop fully recovers — it is not the driver).
- Not changing the batch size (8/frame) — only the search strategy inside the drain.
- No shader work beyond a per-vertex-color material flag.

## Decisions

### D1: `MoveLineRenderer` autoload, pull-model, one buffer per frame
A new autoload (registered in `project.godot`, precedent: `DebugVisualizer`) owns one `MeshInstance3D` + `ImmediateMesh` at the world origin + one shared unshaded material (`vertex_color_use_as_albedo`, `no_depth_test`, render priority 100). Every frame its `_process` rebuilds the buffer once: it iterates the set of registered line sources and reads each source's current endpoint (pull-model), writing world-space vertices. 60 lines = one `clear_surfaces` + one LINES surface + one TRIANGLES surface for markers.
- **Why pull over push**: no per-frame bookkeeping of "changed" segments, no stale-segment risk, and attack-target tracking is free (endpoints recomputed from the source each frame).
- **Why one shared material**: all move lines are green; per-vertex alpha handles the per-line fade in a single draw call.
- **Alternative (per-unit transform meshes)**: still leaves 60 nodes + 60 draw calls; the batch is one buffer and one draw call. Rejected on the profile evidence (the cost is per-mesh upload).
- **Alternative (reuse `DebugVisualizer.draw_path`)**: debug-gated (`OS.is_debug_build()` early return) — routing gameplay feedback through it silently breaks release builds. Rejected; the renderer is a new ungated autoload.

### D2: Lifecycle — register on show, unregister on hide; ownership in the source
`SelectComponent` keeps its one-shot timer and show/hide logic, but `_show_move_line` registers with the renderer and `_hide_move_line` / `_on_move_line_timeout` / `_update_visibility` unregister. The renderer keeps a `Dictionary` keyed by the source component and clears an entry when the source is freed (`is_instance_valid` check in the per-frame pass — mirrors the leaked-free cleanup pattern). This makes stale-geometry leaks impossible.

### D3: Line lifetime 300ms + fade
The one-shot timer becomes `0.3s` with a fade tail (~100ms). The renderer writes per-vertex alpha = min(1, remaining / fade_window). Timer semantics unchanged otherwise (reselected unit restarts it; attack-target reselect still shows it).

### D4: Reverse frontier for sharer-only groups (`Pathfinder.compute_frontier` / `reconstruct_path`)
`compute_frontier(dest_cell, blocked, locomotor_data)` runs a reverse Dijkstra (no heuristic) from the destination over the static terrain graph, mirroring `find_path`'s neighbor/cost/passability rules, storing per-cell `(g_cost, next_cell)`. `reconstruct_path(start_cell, frontier)` walks the chain and applies `find_path`'s stagnation fallback (nearest-reachable) for unreachable starts. `SelectionManager` memoizes one frontier per distinct destination cell across the `_pending_moves` drain.
- **Why sound**: for pure sharer groups, `_build_blocked_cells` erases all non-building reservations, so the blocked set is static across the drain and the frontier stays valid.
- **Gate**: the fast path requires *every* pending mover to be `shares_cell()` with the same `LocomotorData`. Any vehicle/crusher/jumpjet/subterranean or mixed selection forces per-unit `find_path`. The gate must be exact — a stale frontier over mutated blockers is a correctness bug.
- **Post-processing preserved**: reconstructed paths still get the sub-slot lane offset and LOS-collapse in `set_target_position` (unchanged), so the frontier replaces only the search, not the movement pipeline.

### D5: MovementController consumes reconstructed paths via a path provider
To avoid touching the movement hot loop, `set_target_position` keeps its signature; the frontier fast path lives in the `SelectionManager` dispatch path (which already owns the "execute move" step), reconstructing the path and handing it to `set_target_position` (or a new optional `set_target_position_with_path`). Per-unit `find_path` remains the default; the frontier is an explicit injection, so a wrong gate degrades to correctness, never to movement breakage.

## Risks / Trade-offs

- **One buffer = one AABB** → the whole buffer draws even when most lines are off-screen. Fine at 60 segments (~480 verts); noted upgrade path is quadrant-split meshes if counts grow (not needed now).
- **Stale segments from freed units** → renderer drops invalid sources in its per-frame pass; unregister on all hide paths. Airtight by construction (pull-model + validity check).
- **Frontier gate exactness** → a single non-sharer in the selection must disable the fast path, or units path through stale blockers. Guarded by a strict all-sharers-same-locomotor predicate evaluated at dispatch time; falls back per-unit otherwise.
- **Fade via per-vertex color** → requires the material flag; wrong alpha math could over- or under-fade. Kept simple: linear ramp over the fade window; covered by a unit test.
- **Behavior change (300ms line)** → players see a shorter, fading line. This matches the intended "order acknowledgement" glyph and was explicitly chosen; the visible drop is already fully transient.

## Migration Plan

Internal changes only; no scene/resource/data migration. `MoveLineRenderer` is a new autoload added to `project.godot` (removed cleanly by reverting the commit). Rollback = revert; the old per-unit ImmediateMesh path remains valid in git history.

## Open Questions

- None blocking. (Minor: whether the fade window should be a fixed 100ms tail vs half the 300ms — default fixed 100ms, tunable constant.)
