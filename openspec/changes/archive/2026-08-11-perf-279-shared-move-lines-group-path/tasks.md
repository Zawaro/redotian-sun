## 1. MoveLineRenderer autoload

- [x] 1.1 Create `scripts/core/MoveLineRenderer.gd` (+ `.uid`): autoload owning one `MeshInstance3D` + `ImmediateMesh` at the world origin + one shared unshaded material (`vertex_color_use_as_albedo`, `no_depth_test`, render priority 100); register the autoload in `project.godot`
- [x] 1.2 Add `register(source)` / `unregister(source)` backed by a Dictionary; `_process` pull-model rebuild: iterate valid registered sources, read each source's current line endpoint + marker, write one LINES surface + one TRIANGLES surface with per-vertex alpha (fade) — one buffer rebuild per frame
- [x] 1.3 Drop freed sources (`is_instance_valid` check) so stale segments cannot persist; guard with `_ready`/`_exit_tree` cleanup

## 2. SelectComponent line routing + timing

- [x] 2.1 Replace per-unit `_move_line_mesh` ImmediateMesh creation with renderer registration: `_show_move_line` registers, `_hide_move_line` / `_on_move_line_timeout` / `_update_visibility` unregister; delete the per-unit mesh + marker construction
- [x] 2.2 Route the rally line through the renderer as a change-only registration (rally redraws only on `rally_point_changed`), removing `_redraw_rally_line`'s per-unit ImmediateMesh
- [x] 2.3 Change the move-line one-shot timer from 1s to 0.3s with a ~100ms fade tail; keep reselect/attack-target semantics
- [x] 2.4 Update `test/unit/test_move_target_line.gd`: line routing through the renderer, 300ms timer, fade, rally line registration

## 3. Verification

- [x] 3.1 Full suite: `redot --headless -s test/run_tests.gd`
- [ ] 3.2 Re-profile the move order: Process time drops from ~23ms/frame to low single digits; move lines render as one draw call; no pathing regressions for mixed/vehicle selections
- [x] 3.3 `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; no tabs (`grep -P '\t'`)

## 4. Superseded by perf-279-greedy-group-movement

- [x] 4.1 The reverse-frontier fast path was benchmarked as a regression and is superseded by the greedy-first + terrain-cost-cache change `perf-279-greedy-group-movement`. Do NOT implement frontier pathfinding here; its spec deltas have been removed.
