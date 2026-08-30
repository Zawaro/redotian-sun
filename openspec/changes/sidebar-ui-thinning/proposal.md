## Why

`scripts/ui/Sidebar.gd` (812 lines) mixes four blocks of system logic into the UI layer: a placement state machine, sell/repair mode booleans, production click policy, and the credit counter animation. Gameplay scripts reach into the UI to read its state (`scripts/hud/MouseHandler.gd:168-176`, `scripts/ui/PauseMenu.gd:33` query `Sidebar.is_sell_mode()`/`is_debug_place_mode()`) — a gameplay→UI inversion. The placement session logic is also duplicated: Sidebar's debug free-place and BuildingManager's build mode are near-identical "mode flag + 1-frame input skip + `_process` poll" machines, and the mouse-ray→terrain refinement loop exists 4× (Sidebar:788-802, BuildingManager:288-304 and 550-564, MouseHandler:481-494). Tracked as #338.

## What Changes

- **Placement session dissolves into EntityPlacer** (no ported state machine): EntityPlacer gains a single nullable placing-data field with `start_placing(data)`/`stop_placing()`/`is_placing()` wrapping the preview lifecycle it already owns; commit/cancel become event-driven (`_unhandled_input`) instead of `_process` polling, which deletes the 1-frame skip-counter hack on the Sidebar path. Repositioning stays in `_process` (camera pans emit no motion events). The `no_prereqs`-without-factory unit-spawn fallback (Sidebar:522-527) is named (`direct_deploy`) and carried to the new session — it is a gameplay path, not debug cruft.
- **MouseHandler guard moves in the same change**: its `is_debug_place_mode()` click guard must read `EntityPlacer.is_placing()` because commit now flips state in the input phase, before MouseHandler's `_process` polling runs — otherwise the commit click double-fires as a unit order.
- **Sell/repair mode state derives from OrderSystem**: `is_sell_mode()`/`is_action_mode()` become type checks on `active_generator` (`SellOrderGenerator`/`RepairOrderGenerator` vs `UnitOrderGenerator`); OrderSystem gains a `generator_changed` signal so the Sidebar buttons sync themselves. MouseHandler and PauseMenu query OrderSystem, not Sidebar. Completes the design sketched in the archived unified-order-system change.
- **Production click policy moves to ProductionManager**: `handle_cameo_click(player_id, data, button, shift)` plus a queue read API (`get_queue_count`, `get_item_progress`, `is_ready_to_place`, `is_ready_to_spawn`, `has_factory_for`). Sidebar's cameo handler becomes one call; the `debug_menu.no_prereqs` branch moves with it (precedent: PrerequisiteSystem reads DebugMenu flags directly).
- **Shared ground-picking util**: `TerrainSystem.mouse_ray_to_terrain(camera, screen_pos)` replaces all 4 copies of the refinement loop; BuildingManager adopts it (its session machine otherwise stays — full session unification is deferred to a follow-up).
- **CreditCounter component**: the counter animation + tick SFX move to a small `CreditCounter` Control instantiated in `Sidebar.tscn`, connecting EconomyManager itself. Behavior identical (unchanged `credit-ui` requirements).
- Sidebar keeps only view + signal glue: tabs, scroll, grid/cameo creation, production/prerequisite signal handlers, model prewarming, and thin entry points that delegate to the owning systems.

## Capabilities

### New Capabilities

- `mouse-ground-picking`: one screen-point→terrain-position routine on TerrainSystem used by placement previews, order targeting, and future placement consumers; no consumer keeps its own refinement loop.

### Modified Capabilities

- `order-system`: OrderSystem exposes action-mode state derived from the active generator (`is_sell_mode()`, `is_repair_mode()`, `is_action_mode()`) and emits `generator_changed`; callers no longer query the Sidebar for sell/repair state.
- `debug-menu`: EntityPlacer owns the free-placement session (placing data + commit/cancel + `is_placing()` as the placement-mode truth); the Sidebar debug block becomes one-line delegates; the no-factory unit-spawn fallback is carried with explicit `direct_deploy` semantics. Placement-mode truth consumers (PauseMenu ESC guard, MouseHandler click routing) read EntityPlacer.

## Impact

- **Scripts modified**: `scripts/ui/Sidebar.gd` (812 → ~550 lines, view + glue only), `scripts/core/OrderSystem.gd` (mode API + signal), `scripts/entities/EntityPlacer.gd` (placing session, `_unhandled_input`, `_process` reposition), `scripts/hud/MouseHandler.gd` (guards read OrderSystem/EntityPlacer; ray loop adopts util), `scripts/ui/PauseMenu.gd` (guard reads OrderSystem/EntityPlacer), `scripts/buildings/BuildingManager.gd` (adopts ray util in both `_update_preview_position` paths), `scripts/production/ProductionManager.gd` (cameo-click policy + read API), `scripts/core/TerrainSystem.gd` (new util).
- **New files**: `scripts/ui/CreditCounter.gd` (+ `.uid`), new unit/integration tests for OrderSystem mode API, EntityPlacer session, ProductionManager cameo-click policy, and the ground-picking util.
- **Scenes modified**: `scenes/ui/Sidebar.tscn` (add CreditCounter node child) — additive; existing packed scenes keep loading (no property removals from instanced nodes).
- **Tests updated**: pause-guard, cameo-routing, placement debug suites re-pointed at the new seams; a headless input-seam probe validates that `Input.action_press` + explicit `_process` ticks drive the existing polled machines before characterization tests are written against them.
- **Deferred (out of scope, follow-up issue)**: unifying BuildingManager's build-mode session with EntityPlacer's behind a characterization harness; buildings-only production funnel.
