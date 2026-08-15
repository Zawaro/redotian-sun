## 1. Terrain grade helper

- [x] 1.1 Add `get_cell_grade_steps(cell: Vector2i) -> int` to `scripts/core/TerrainSystem.gd` returning the steepest adjacent-corner rise (edge-based, not span-based) from the existing height snapshot (0 for empty/out-of-bounds).
- [x] 1.2 Add unit tests in `test/unit/test_terrain_grade.gd`: flat cell → 0, `[0,0,1,1]` → 1, `[0,0,2,2]` → 2, stair `[0,1,1,2]` → 1, three-step face `[0,0,3,3]` → 3, out-of-bounds → 0.

## 2. Shroud blocking rule

- [x] 2.1 Change `ShroudSystem._cell_blocks` to exempt cells with edge rise == 1 (walkable graded slopes/stairs); all other cells fall through to the unchanged `get_cell_max_height` height-delta check.
- [x] 2.2 Confirm `_max_height_delta` and the `blocks_terrain == false` early path in `_cell_reachable` are untouched.

## 3. Live viewer height on move

- [x] 3.1 Add optional `viewer_height = -1.0` param to `ShroudSystem.move_revealer`; when supplied and differing from the stored height, re-evaluate the whole disc via `_recompute_at` (symmetric difference, no count leaks); otherwise keep the crescent fast path.
- [x] 3.2 Pass `_viewer_height()` from `VisionComponent` at the existing cell-crossing call site.

## 4. Regression tests

- [x] 4.1 Shroud test: a walkable 1-step graded ridge reveals over/behind it.
- [x] 4.2 Shroud test: a walkable 2-step stair ramp (edge rise 1) reveals over/behind it.
- [x] 4.3 Shroud test: a flat plateau (grade 0) blocks from a low viewer.
- [x] 4.4 Shroud test: climbing onto a plateau with a raised viewer height reveals behind it.
- [x] 4.5 Confirm existing `test_hill_blocks_vision` and `test_high_ground_sees_over` still pass unchanged.

## 5. Verification

- [x] 5.1 Run `redot --headless -s test/run_tests.gd` — all tests pass.
- [x] 5.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`.
- [ ] 5.3 Manual check in-editor: walk a unit up a 1–2 step slope on TestMap01/02 and confirm the shroud clears ahead while flat plateaus still block.
