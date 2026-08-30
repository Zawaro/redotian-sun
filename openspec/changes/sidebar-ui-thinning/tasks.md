## 1. Phase 1 — Shared ground picking (design D1 prerequisite)

- [x] 1.1 Add `TerrainSystem.mouse_ray_to_terrain(camera: Camera3D, screen_pos: Vector2) -> Variant` (ground-plane intersect + 4-iteration `get_height_at_world_smooth` refinement, null on miss) in `scripts/core/TerrainSystem.gd`
- [x] 1.2 Write the headless input-seam probe (`test/integration/test_input_seam_probe.gd`): `Input.action_press("select_entity")` + explicit `_bm._process(0.016)` — record whether just-pressed fires; if it does not, document that placement tests must drive `_unhandled_input`/public API directly
- [x] 1.3 Unit-test the util with a known flat-terrain case, a sloped case, and a miss (per `mouse-ground-picking` spec)
- [x] 1.4 Switch the four consumers to the util: `Sidebar._update_debug_preview_position` (788-802), `BuildingManager` (288-304 and 550-564), `MouseHandler` (481-494); delete the inline loops; grep confirms one refinement implementation
- [x] 1.5 Run full suite (`redot --headless -s test/run_tests.gd`) + gdlint/gdformat — green before proceeding

## 2. Phase 2 — OrderSystem mode API (design D4)

- [x] 2.1 Add `OrderSystem.is_sell_mode()`, `is_repair_mode()`, `is_action_mode()` (generator-type checks) and `generator_changed` signal (emit in `set_generator` and `cancel`) in `scripts/core/OrderSystem.gd`
- [x] 2.2 Unit-test the mode API: sell/repair/unit transitions, signal emission on set and cancel
- [x] 2.3 Flip `MouseHandler.gd:168-176` to `OrderSystem.is_action_mode()` + `OrderSystem.cancel()`; flip `PauseMenu.gd:33` ESC guard to OrderSystem queries
- [x] 2.4 Sidebar `_on_sell_pressed`/`_on_repair_pressed`/`exit_action_mode` become signal-driven: toggle calls `set_generator`/`cancel`, `generator_changed` subscription syncs `sell_button`/`repair_button` visuals; delete `_sell_mode`, `_repair_mode`, `is_sell_mode()`, `is_repair_mode()`
- [x] 2.5 Update pause-guard and sell/repair tests to the OrderSystem seam; suite green

## 3. Phase 3 — EntityPlacer placement session (design D1-D3, D5 fallback)

- [x] 3.1 Add placing session to `scripts/entities/EntityPlacer.gd`: `placing_data: EntityData` field, `start_placing(data)`/`stop_placing()`/`is_placing()`, `_unhandled_input` commit (`select_entity` → `finalize_preview` + stop_placing) and cancel (`deselect_entity`/ESC → `cancel_preview` + stop_placing), 2-line `_process` reposition calling `mouse_ray_to_terrain`
- [x] 3.2 Add click-frame latch (`_consumed_click_frame`) set on commit; expose `did_consume_click_this_frame()`
- [x] 3.3 Wire MouseHandler: replace `sidebar.is_debug_place_mode()` guard (L81) with EntityPlacer placing/latch check so the commit click never double-fires as an order (integration test: start_placing → commit tick → assert no order executed on the placed entity)
- [x] 3.4 Move the no-factory fallback into ProductionManager (or EntityPlacer entry) as named `direct deploy` path; Sidebar:522-527 branch delegates
- [x] 3.5 Sidebar debug block becomes one-line delegates (`enter/exit_debug_place_mode`/`is_debug_place_mode` over start_placing/stop_placing/is_placing); `_get_current_entities` debug branch reads the delegate; delete `_start_debug_place`, `_finalize_debug_place`, `_update_debug_preview_position`, `_get_camera_3d`, `_debug_skip_input`, `_debug_place_mode` and the `_process` block (120-134)
- [x] 3.6 Flip PauseMenu ESC guard placement check to `EntityPlacer.is_placing()`; rewrite the stale PauseMenu comment about `_process` exit ordering
- [x] 3.7 Update debug-menu placement tests (DebugMenu:423,441,443 entry paths, scene-change reset) to the new seam; add session tests: placing-start click cannot commit, commit/cancel event-driven, reposition tracks camera pan; suite green

## 4. Phase 4 — Production click policy + CreditCounter (design D5, D6)

- [x] 4.1 Add `ProductionManager.handle_cameo_click(player_id, data, button, shift)` absorbing `_handle_left_click`/`_handle_right_click` policy; add read API `get_queue_count`, `get_item_progress`, `is_ready_to_place`, `is_ready_to_spawn`, `has_factory_for`
- [x] 4.2 Collapse Sidebar `_on_cameo_gui_input` to one `handle_cameo_click` call (place-anywhere start branch calls the delegate); delete `_handle_left_click`, `_handle_right_click`, `_is_ready_to_place`, `_is_ready_to_spawn`, `_get_queue_count`, `_get_item_progress`, `_get_queue_items_for_entity`, `_factory_exists_for_queue`; cameo visuals read the new API
- [x] 4.3 Unit-test `handle_cameo_click`: place-ready, retry-spawn, resume-paused, stack with shift, cancel-refund, pause-vs-cancel priority, direct-deploy fallback vs factory-exists
- [x] 4.4 Create `scripts/ui/CreditCounter.gd` (+ `.uid`): counter state, cadence constants, accumulator clamp, tick SFX, EconomyManager connection, insufficient-funds color; add as node child in `scenes/ui/Sidebar.tscn`; delete the counter block from `Sidebar.gd`; re-point `test_economy_audio.gd`/`test_sidebar_credits.gd` at the component
- [x] 4.5 Verify Sidebar.tscn loads in a fresh instantiation (additive node, no broken references)

## 5. Wrap-up

- [x] 5.1 Structural audit: grep `Sidebar.gd` contains no `_debug`, no skip counters, no `is_action_just_pressed`, no `project_ray_origin`, no mode booleans; `wc -l` ~550
- [ ] 5.2 Full suite + `gdlint` + `gdformat --check` + tab grep; commit each phase as its own conventional commit (`refactor(scope): ... (#338)`)
- [x] 5.3 File the follow-up issue: unify BuildingManager build-mode session behind a characterization harness (buildings-only production funnel)
- [x] 5.4 Update AGENTS.md if the autoload/feature docs mention Sidebar placement responsibilities
