## 1. HUD layout and credit relocation

- [x] 1.1 Create `scenes/ui/CreditsLabel.tscn` containing the `CreditCounter`-scripted `Label` moved out of `Sidebar.tscn`, anchored top-right of the HUD column.
- [x] 1.2 Remove `CreditsLabel` from `scenes/ui/Sidebar.tscn` and shift the Sidebar root down (`offset_top` 0 -> 244, `offset_bottom` 600 -> 844) to clear the minimap.
- [x] 1.3 Instance `CreditsLabel.tscn` and `Minimap.tscn` in `scenes/maps/MapBase01.tscn` HUD: credits pinned at the top, 200x200 minimap centered below it, Sidebar below the minimap.
- [x] 1.4 Repoint the credit counter integration test: rename `test/integration/test_sidebar_credits.gd` to a credits-scene test and change its `SIDEBAR_SCENE` preload/`%CreditsLabel` lookup to `CreditsLabel.tscn` (move the `.uid` with it). Also repointed `test/unit/test_economy_audio.gd`, which instantiated the Sidebar for `%CreditsLabel`.
- [x] 1.5 Run the test runner and confirm the credit counter integration test passes against the new location.

## 2. Minimap render core

- [x] 2.1 Create `scripts/ui/Minimap.gd` (`class_name Minimap`, `extends Control`) and `scenes/ui/Minimap.tscn` (Control that draws the baked texture plus the view-rect overlay in `_draw`); set node name `Minimap`, `mouse_filter = STOP`, nearest texture filter, and commit the `.uid` files.
- [x] 2.2 Add static geometry helpers: diamond dims from `CellUtil.get_diamond_extent`, cell -> texel and texel -> cell using `idx = cell.y * width + cell.x`, with in-diamond guards.
- [x] 2.3 Implement the terrain bake on `grid_initialized` (deferred one frame): per in-diamond cell, `TerrainCatalog.get_cell_art` -> `TerrainArtData.minimap_color(art, land_type)` -> `TerrainArtData.shade_map_color(..., height_ratio, theater low/high radar brightness)`, using `TerrainSystem.get_painted_land_type`; write a persistent RGBA8 `Image`, transparent outside the diamond.
- [x] 2.4 Implement the low-frequency refresh (exported interval, default 2 Hz): copy terrain bytes, multiply by the local fog factor from `ShroudSystem.get_effective_state` honoring `shroud_enabled`/`fog_of_war`, stamp entity and `ResourceComponent` overlay dots (`ArtData.minimap_color`, resource type color fallback for art-less tiberium) with shroud/omit, fog/dim, visible/full, then `ImageTexture.update`.
- [x] 2.5 Build and store the `cell -> target` index of revealed entities during each refresh for click resolution.
- [x] 2.6 Draw the camera view rectangle every frame from the gameplay camera pivot and size projected through `CellUtil.world_to_cell`.

## 3. Minimap input ownership and click handling

- [x] 3.1 Add cached `UIUtil.is_mouse_over_minimap()` mirroring `find_sidebar`.
- [x] 3.2 Add the minimap hover skip to `MouseHandler._process`, `BuildingManager._process`, and `EntityPlacer._process`.
- [x] 3.3 Implement the left-click handler: map local position -> cell -> world, resolve the revealed target entity, call `OrderSystem.get_orders` with `MouseHandler`-style modifiers, execute orders and play the confirmation voice; when no orders result, call `BoundsSystem.center_camera_on_cell`; `accept_event()` so build/placing modes are bypassed and right-click stays unhandled.

## 4. Tests

- [x] 4.1 Add `test/unit/test_minimap.gd` covering cell <-> texel round-trips: diamond interior, out-of-diamond rejection, and square/rectangular/odd/even extents.
- [x] 4.2 Add terrain color precedence tests at the minimap level: authored art color > painted land type > transparent, and resource land type excluded from terrain color.
- [x] 4.3 Add fog composition tests: shroud -> black, explored -> dimmed, visible -> full, across `shroud_enabled`/`fog_of_war` toggle combinations.
- [x] 4.4 Add overlay gating tests: shrouded entity omitted, fog entity dimmed, visible entity full.

## 5. Verification

- [x] 5.1 Run `redot --headless -s test/run_tests.gd` and confirm all tests pass.
- [x] 5.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`.
- [x] 5.3 Run `grep -P '\t' scripts/**/*.gd` and confirm no tabs were introduced.
- [ ] 5.4 Manually verify in-game: minimap shows terrain, fog, resources, and entities; the view rectangle tracks pan/zoom; left-click orders when units are selected and snap-pans otherwise; credits sit above the minimap; a minimap click in build mode does not place a building.

## 6. Orientation and aspect fix (post-implementation)

- [x] 6.1 Diagnose the 45-degree mismatch: cell-index axes map straight to pixels while the play area is a diamond in index space and the gameplay camera is yawed ~45 degrees.
- [x] 6.2 Add pure `Minimap.index_to_pixel` / `pixel_to_index` (45-degree rotation + aspect scale) and `Minimap.size_for_grid` (map W:H within a max size).
- [x] 6.3 Apply the transform in `_draw` (texture via `draw_set_transform_matrix`), `_pixel_to_cell` (inverse), and `_draw_view_rect`; resize/re-centre the control to the map aspect in `_apply_size_for_grid`; switch to linear filtering.
- [x] 6.4 Add tests: aspect preservation, index/pixel round-trip, and play-diamond vertices mapping to the control corners.
- [x] 6.5 Re-run the full suite and lint/format.

## 7. Dots, view-rect clipping, and play-area crop (post-implementation)

- [x] 7.1 Size overlay dots by `FoundationComponent.foundation` (units and resource crystals stay 1 texel); anchor at the footprint origin and register every footprint cell for click targeting.
- [x] 7.2 Clip each camera view-rectangle edge to the minimap rect with a pure Liang-Barsky `clip_segment_to_rect`, drawing only visible segments so no edge traces the minimap border.
- [x] 7.3 Crop the minimap to the `BoundsSystem` play area: inset-aware `index_to_pixel`/`pixel_to_index`/`_draw_transform`, `size_for_play_area`, and an `in_play_area`-gated terrain bake so the permanently-shrouded rim is not rendered.
- [x] 7.4 Add tests: `size_for_play_area` aspect (incl. insets), `in_play_area` vs `CellUtil.is_in_diamond` and inset subset, inset index/pixel round-trip, play-vertex -> control-corner, footprint stamping, and per-edge segment clipping.
- [x] 7.5 Re-run the full suite and lint/format.

