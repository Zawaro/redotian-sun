## 1. Shared adjacency/white-region helper

- [x] 1.1 Extract `adjacent_reachable_cells()` (two-step dilation: friendly footprints dilated by `maxi(adjacent, 0)`, then by full foundation size per XZ axis) into a function consumed by both `_is_adjacency_satisfied` and the overlay; `_is_adjacency_satisfied` behavior stays identical
- [x] 1.2 Unit tests: known-example dilation (2x2 building, adjacent=1, 3x2 ghost), adjacent=0 touching case, negative adjacent clamps to 0, ghost-adjacent-governs case, boundary cells just inside/outside the region

## 2. PlacementGridOverlay

- [x] 2.1 Create `scripts/core/PlacementGridOverlay.gd`: chamfered-octagon mesh generator (XZ = 90% of `CellUtil.CELL_SIZE`, corners cut ~15%), one `MultiMeshInstance3D`, one shared unshaded vertex-color transparent material created at init
- [x] 2.2 Implement API: `set_white_cells(cells)`, `set_cursor(origin, footprint)`, `clear()`; per-instance flat position at max terrain corner height + 0.05; green/red assignment via `_is_cell_free` / `_is_in_play_area` results passed in or queried
- [x] 2.3 Unit tests: octagon geometry (corner vertices cut, footprint 90%), plane Y = max corner height + 0.05, color assignment (green on free, red on blocked, white cells painted white)

## 3. BuildingManager wiring

- [x] 3.1 Instantiate the overlay on `enter_build_mode`, set white cells once via the shared helper; refresh green/red per cursor move through `set_cursor`
- [x] 3.2 Delete `_add_grid_and_indicators`, `_quad`, `_build_cell_mesh`, and the per-frame material allocations in `_update_preview_mesh`; slim `_update_preview_mesh` down to calling the overlay
- [x] 3.3 Clamp `adjacent` with `maxi(adjacent, 0)` at the read site for validation

## 4. Test updates and verification

- [x] 4.1 Update tests asserting preview child structure (`test/unit/test_building_manager.gd`, `test/integration/test_asset_preview_scene.gd`) for the new overlay-based preview
- [x] 4.2 Regression test: no line-grid nodes added to the preview during build mode
- [x] 4.3 Run `redot --headless -s test/run_tests.gd`, `gdlint`, and `gdformat --check`; check for tabs after formatting

## 5. Review adjustments (user smoke-test round 1)

- [x] 5.1 Window white cells to the old line-grid radius around the ghost center; window follows the cursor
- [x] 5.2 Red out-of-white ghost footprint cells when `adjacent > 0`
- [x] 5.3 Tuning: cell coverage 95%, red/green alpha 0.7, ghost alpha 0.45
- [x] 5.4 Update tests + spec/design; suite, gdlint, gdformat clean

## 6. Bib dilation fix (user review round 2)

- [x] 6.1 Regression test: 3x3 foundation with bottom-row bibs — cell past the bib strip is white and satisfies adjacency
- [x] 6.2 Fix `_friendly_building_cells` to dilate the full foundation rect (origin + foundation) instead of stored non-bib cells
- [x] 6.3 Pin test neighbor fixtures to explicit foundations; suite + lint + format clean

## 7. Review fixes (user review round 2)

- [x] 7.1 Refresh white region when the ghost type switches mid-session (regression test)
- [x] 7.2 Defer overlay rendering until the first cursor update (regression test)
- [x] 7.3 Nits: dead clamp in reach radius, drop unused helper param, value-agnostic test messages, spec/design record the smoke-tuned 0.025 offset
