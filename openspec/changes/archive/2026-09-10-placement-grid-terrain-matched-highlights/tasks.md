## 1. Verification spike: derive_crease rule vs baked catalog + GLB

- [x] 1.1 Write a throwaway script (or test) that, for every slope-family object variant under `games/ts/terrain_objects/` (slope01/05/09/13/17 × n/e/s/w, slope_saddle2 × n/e/s/w), applies the design's split-diagonal rule to the object's baked corners (with the catalog NW/NE/SE/SW → world NW/NE/SW/SE reordering) and prints the predicted internal diagonal next to the GLB submesh's actual triangle pairing (submesh + rotation resolved via the art entry)
- [x] 1.2 Record the outcome in this change's design.md Open Questions: confirm zero overrides needed, or write the exact per-family override table into design.md D2; if `slope_saddle2` deviates, note it as the documented data-exact exception

## 2. Patch builder (pure, testable)

- [x] 2.1 Add `PlacementGridOverlay._build_patch_mesh(corner_heights: Array[float], corner_world: Array[Vector3]) -> ArrayMesh`: four corner vertices (corner heights × `TerrainSystem.HEIGHT_STEP` + `PLANE_Y_OFFSET`), planar case → quad, non-flat → the single diagonal per D2; unindexed or indexed 2-triangle ArrayMesh
- [x] 2.2 Add `PlacementGridOverlay._is_flat_cell(cell: Vector2i) -> bool` (empty data or `type == "clear"` → flat; `"slope"` → non-flat)
- [x] 2.3 Add pure static helpers the tests can call without a scene: a diagonal-pick function `(corners: Array[float]) -> int` (0 = {NW,SE} diagonal, 1 = {NE,SW}, -1 = planar/any) mirroring `derive_crease`, and a corner reordering helper (catalog order → world order)
- [x] 2.4 Unit tests (`test/unit/test_placement_grid.gd` or a new `test_placement_grid_patch.gd`): known corner examples with hand-computed expected transforms/triangles (1-step SE-raised, 2-step unique-max saddle-adjacent, 1-low tent, planar 2-step ramp, flat); the invariants (all four vertices at exact corner Ys; every triangle normal `|y| >= 0.5`; planar cases have coplanar vertices; diagonal choice matches the D2 rule for all 7 pattern classes); guard against vacuous passes (assert the tested branch was reached and the fixture cells are inside the grid)

## 3. Overlay integration

- [x] 3.1 In `_rebuild()`, partition resolved cells by `_is_flat_cell`: flat cells keep writing the existing octagon `MultiMesh` instance exactly as today
- [x] 3.2 Add the non-flat path: one `MeshInstance3D` per non-flat cell with the patch `ArrayMesh` and the shared unshaded transparent state material (state color + alpha ride the vertex color — a `StandardMaterial3D` albedo cannot carry alpha without a texture, so one material serves all states, mirroring the octagon's color pipeline)
- [x] 3.3 Add the bounded slot pool (reuse `MeshInstance3D` + `ArrayMesh` pairs when the non-flat cell set changes between rebuilds); `ponytail:` comment with the cap and the upgrade path
- [x] 3.4 Wire lifecycle: patch instances return to the hidden pool on `clear()`, are children of the overlay node (freed with it on build-mode exit)
- [x] 3.5 Confirm no behavioral change to state rules: `compute_cell_colors` and the white window are untouched; existing `test_placement_grid.gd` color-assignment tests pass (52 asserts)

## 4. Integration and verification tests

- [x] 4.1 Per-object catalog/GLB test (design D6): for every slope object variant, assert the generated patch vertices equal the resolved GLB submesh corner positions within epsilon (with the corner-order reordering) and the internal diagonal matches the D2 rule (or the documented per-family override / saddle2 exception)
- [x] 4.2 Integration on `games/ts/assets/test_terrain.json` (91 slope cells) and `test_map01.json` (461): entering build mode over a slope region yields exactly one non-flat instance per non-flat in-window/footprint cell with Y matching `TerrainSystem.get_cell_corner_heights` × `HEIGHT_STEP` + offset; flat regions yield zero non-flat instances; white region, green, and red states all render through the patch path
  - Note: test_terrain.json's actual fixture content is 4232 diamond cells / 26 slope (46×46 grid); the issue's "91" predates the current fixture. Pins updated to measured values; test also asserts patch vertex Y against the `get_height_at_world_smooth` oracle (issue acceptance 3).
- [x] 4.3 Update `test_plane_y_uses_max_corner_height_plus_offset` to the flat-only scope and add a non-regression test that a 1-step slope cell produces no octagon instance
- [x] 4.4 Full headless test run: `redot --headless -s test/run_tests.gd` (6460 passed, 0 failed)

## 5. Finishing

- [x] 5.1 Lint + format: `gdlint scripts/**/*.gd test/**/*.gd`, `gdformat --check scripts/**/*.gd test/**/*.gd`, then `grep -P '\t'` per repo convention; commit any `.uid` files that appear
- [x] 5.2 Add the `terrain-matched highlight` glossary entry to GLOSSARY.md (Rendering & Audio or Placement & Building cluster, with the patch-builder spec as anchor)
- [ ] 5.3 Smoke test in the Redot editor: place a building across a 1-step slope, a 2-step steep, and a saddle in `TestMap01`; verify the patch reads as the slope (no floating slab, no z-fight, no vertical faces) and that white region cells on non-flat terrain match; verify flat cells still show the octagon
  - First smoke run found: slope patch tint got stronger with every rebuild — `_rebuild_patches` freed only cells that left the set, leaking a still-visible quad (stacked alpha) for surviving cells. Fixed (free-all + pool re-serve) with a stacking regression test; also fixed untyped-array aborts that had made this integration file's passes vacuous. Red color then confirmed matching.
  - Second smoke-run finding: patch corner cut size and inset didn't match the flat octagon. Patches now share the octagon's exact XZ outline (`_octagon_local_xz`, single source of truth for both paths) with vertex heights sampled from `get_height_at_world_smooth` + offset — acceptance-3 oracle holds for all 8 vertices; fold still follows `pick_diagonal`. Awaiting visual re-check.
  - Third smoke-run finding: on tent/saddle cells the highlight bled through the terrain fold. Cause: the octagon vertices are inset (5%) into the cell, so the bilinear `get_height_at_world_smooth` sample deviates from the rendered two-triangle tile by up to `|h_nw+h_se-h_ne-h_sw|/4` (~0.20 m corner / ~0.41 m saddle), far exceeding `PLANE_Y_OFFSET` (0.025 m); and the fan folded along an inset chord parallel to, not on, the true cell diagonal. Fix: split the octagon along the real `derive_crease` diagonal and evaluate each half's vertices on the corresponding terrain triangle plane (the same two planes the baked GLB tile uses). Integration oracle now checks the tile planes, not the bilinear sampler. `slope_saddle2` remains the documented data-exact exception.
- [ ] 5.4 Commit (conventional, `(#386)`) and open the PR `feat: terrain-matched build-mode highlights for slope cells (#386)`
