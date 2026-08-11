## Why

With the shroud fix landed (physics down to 8.76ms), the remaining FPS dip on `perf/279-mass-infantry-move-fps-drop` is a **Process-time spike (23.42ms/frame) at move-order time**, decaying over 3–5s. Two causes stack: each of 60 selected infantry rebuilds its own 3D `ImmediateMesh` move-target line **every frame** (~7,200 GPU vertex-buffer re-uploads/sec) for the ~1s the lines are visible; and `SelectionManager` drains a move queue at 8 units/frame, each running a full per-unit A* (`Pathfinder.find_path`, ~11.4ms cumulative in the profile).

## What Changes

- **Shared batched line renderer (new `MoveLineRenderer` autoload):** one `ImmediateMesh` + one shared unshaded material render *all* active move-target (and rally) lines through a single buffer, rebuilt once per frame from registered components (pull-model). Replaces 60 per-unit mesh nodes / 60 buffer re-uploads with 1. Identical visuals — per-unit green lines, destination markers, attack-target tracking preserved.
- **Move line lifetime shortened to 300ms with a fade-out** (was 1s hard hide): the line becomes an order-acknowledgement glyph; steady state renders no lines. Shared material gains per-vertex color so each line fades independently.
- **Group pathfinding for sharer-only squads:** when every selected entity is an infantry cell-sharer with the same locomotor class, `SelectionManager` computes a reverse Dijkstra **frontier once per distinct destination cell** (sharers cluster to a handful of spiral cells) and each unit walks the `next_cell` chain from its own start — ~a dozen searches instead of 60 A*. Vehicles, crushers, jumpjets, subterranean units, or any mixed selection fall back to per-unit A*. Reconstructed paths keep the existing sub-slot lane offset and LOS-collapse post-processing.
- No breaking changes: line behavior, movement results, and path integrity are preserved.

## Capabilities

### New Capabilities
- `move-line-renderer`: shared batched line renderer (move-target + rally lines in one buffer, per-vertex color fade, register/unregister lifecycle).

### Modified Capabilities
- `select-component`: move-target line drawing routes through the shared renderer instead of a per-unit ImmediateMesh; timing changes from 1s hard hide to 300ms + fade.
- `pathfinder`: new reverse-frontier API (`compute_frontier` + path reconstruction) for shared-destination groups.
- `selection-manager`: sharer-only group moves use the shared frontier; mixed selections keep per-unit dispatch (batch of 8/frame unchanged).

## Impact

- **New:** `scripts/core/MoveLineRenderer.gd` (+ `.uid`), autoload registration in `project.godot`.
- `scripts/components/SelectComponent.gd` — route move/rally lines through the renderer; 300ms timer + fade.
- `scripts/core/Pathfinder.gd` — add `compute_frontier`/reconstruct + tests.
- `scripts/core/SelectionManager.gd` — sharer-branch group pathfinding via the frontier; batch drain unchanged.
- `scripts/components/MovementController.gd` — consume reconstructed paths for sharers where applicable; per-unit `find_path` remains for vehicles/mixed.
- Tests: `test_move_target_line.gd` (renderer routing + fade), `test_perf_guard.gd` (one buffer, not 60), new `pathfinder` frontier tests, `selection-manager` group-path tests.
- No scene or resource changes (renderer is code-created); no data changes.
