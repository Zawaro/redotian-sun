## Context

`Sidebar.gd` (812 lines) is a controller wearing a view: it owns a debug free-placement state machine, sell/repair mode booleans, production click policy, and the credit counter animation. Gameplay scripts invert the dependency direction by reaching into the UI: `MouseHandler.gd:168-176` and `PauseMenu.gd:33` read `Sidebar.is_sell_mode()`/`is_debug_place_mode()`; `MouseHandler.gd:81` routes clicks away from orders while debug placement is active.

Two placement machines coexist, near line-for-line: Sidebar's debug free-place (mode flag, `_debug_skip_input = 1`, `_process` poll of `Input.is_action_just_pressed`, EntityPlacer preview, no validity) and BuildingManager's build mode (`is_build_mode`, `_skip_input_frames = 1`, same poll shape, own schematic preview, `can_place` validity, `_skip_next_deduction` debug-cost flag). The mouse-ray→ground→terrain refinement loop is copy-pasted 4× (Sidebar:788-802, BuildingManager:288-304 and 550-564, MouseHandler:481-494). Both machines poll raw `Input.is_action_just_pressed` inside `_process`, which bypasses GUI event consumption — that polling is the root cause the skip-frame counters exist to paper over.

The skip-frame and the debug free-place machinery carry two entry paths: the "place anywhere" cheat path (Sidebar:484-487) and the `no_prereqs`-without-factory unit-spawn fallback (Sidebar:522-527). The fallback only fires with cheats enabled but is a spawn mechanism, not UI cruft.

An exploration pass (ADHD diverge/deepen, 5 frames, verified against source) converged on "dissolve, don't port" as the extraction shape.

## Goals / Non-Goals

**Goals**
- Sidebar contains only view + signal glue; no placement state, no mode booleans, no click policy, no counter animation state.
- One placement-mode truth (`EntityPlacer.is_placing()`); gameplay guards never read UI state.
- Sell/repair mode state derived from `OrderSystem.active_generator` type; `generator_changed` drives UI sync.
- Single implementation of the ray→terrain refinement routine.
- Zero behavior change visible to the player (same placement UX, same cadence, same buttons).

**Non-Goals**
- Unifying BuildingManager's build-mode session with the new session (deferred to a follow-up, gated on a characterization harness). The two preview renderers are semantically different (schematic = "does it fit", ghost = "what will it look like") and stay separate.
- Routing placement through OrderSystem's order funnel (placement targets ground + footprint, not entities — forced fit).
- Touching the map editor's placement (separate capability, editor-owned).
- Deleting or redesigning DebugMenu; its flags stay where they are (read via group reference, per its spec).

## Decisions

### D1: Dissolve the session into EntityPlacer instead of porting the state machine
EntityPlacer already owns the preview lifecycle (`start_preview`/`update_preview_position`/`finalize_preview`/`cancel_preview`, `_preview_data`). The session adds one nullable `placing_data: EntityData` field: `start_placing(data)` wraps `start_preview`, `stop_placing()` wraps `cancel_preview`, `is_placing()` wraps `has_preview`. No mode enum, no enter/exit bookkeeping, no skip counter.
*Alternative considered*: shared `PlacementSession` class run by both machines — attractive, but BuildingManager's session carries validity + a different renderer + the deduction flag; sharing the skeleton before a characterization harness exists risks regressing a working core system for unity. Deferred.

### D2: Event-driven commit/cancel; repositioning stays in `_process`
Commit (`select_entity`) and cancel (`deselect_entity`/ESC) are handled in `EntityPlacer._unhandled_input` — GUI consumption already guarantees the placement-start cameo-click can't commit it (Button input is consumed before `_unhandled_input`), so `_debug_skip_input`/`_skip_input_frames`-style counters die on this path. Preview repositioning deliberately stays a two-line `_process` call: mouse-motion events don't fire during camera pans, so pure event-driven positioning leaves the ghost stale mid-pan.
*Alternative considered*: converting everything to `_unhandled_input` including motion — rejected (stale ghost during pans).

### D3: MouseHandler coupling lands in the same change
`MouseHandler._process` polls raw `Input.is_action_just_pressed("select_entity")`, which ignores `set_input_as_handled`. Today its `sidebar.is_debug_place_mode()` guard works only because mode-exit happens in `_process` ordering. Once commit flips state in the input phase, the same physical click would fire a unit order on the freshly placed entity. Mitigation: MouseHandler checks `EntityPlacer.is_placing()` (latched for the current frame via a `consumed_click_frame` field on EntityPlacer) before order resolution. Both edits land in one PR — the guard change without the session move is dead code, the session move without the guard change is a double-fire bug.
*Alternative considered*: converting MouseHandler's click path to `_unhandled_input` too — the permanent fix, but it rewrites the order funnel's input contract; out of scope here, noted as follow-up.

### D4: Sell/repair state is a type check, not stored state
`Sidebar._sell_mode`/`_repair_mode` are derived mirrors of `OrderSystem.active_generator`'s type (clicks already route through `set_generator(SellOrderGenerator.new())` / `.new(RepairOrderGenerator)`). OrderSystem gains `is_sell_mode()`/`is_repair_mode()`/`is_action_mode()` (type checks) and a `generator_changed` signal (emitted from `set_generator` and `cancel`); the Sidebar subscribes and syncs its own button visuals. MouseHandler and PauseMenu query OrderSystem. This completes the design sketched in the archived unified-order-system change.
*Alternative considered*: keeping booleans and moving them wholesale to OrderSystem — rejected: stores the same fact twice.

### D5: Production click policy moves as one entry point
ProductionManager gains `handle_cameo_click(player_id, data, button, shift)` absorbing `_handle_left_click`/`_handle_right_click` policy (place-ready/retry-spawn/resume/stack/cancel-refund/pause), plus read API for the cameo visuals (`get_queue_count`, `get_item_progress`, `is_ready_to_place`, `is_ready_to_spawn`, `has_factory_for`). The `debug_menu.no_prereqs`-without-factory branch moves into `handle_cameo_click` (precedent: `PrerequisiteSystem` reads DebugMenu flags via group reference) and is spec'd as its own `direct deploy` path so it can't silently change semantics when the Sidebar block deletes. Sidebar's cameo handler becomes one call + `set_input_as_handled()`.
*Alternative considered*: leaving the no_prereqs branch at the Sidebar call site — rejected: it splits one decision across two layers.

### D6: CreditCounter as a component, not a helper
`scripts/ui/CreditCounter.gd` (a Control with a Label) owns the animation state, cadence constants, accumulator clamp, tick SFX, and the EconomyManager connection; `Sidebar.tscn` instantiates it. Behavior identical to the `credit-ui` spec (no delta needed). Cheap, satisfies "max UI-thin", and gives the counter a testable home independent of the cameo grid.
*Alternative considered*: leaving the counter in Sidebar — reasonable (one consumer), but the change's stated goal is a pure-UI Sidebar and the extraction is ~55 lines with zero behavioral risk.

### D7: Test seam probe before characterization
The repo's headless runner drives per-frame logic with explicit ticks (`sidebar.call("_step_counter", 0.05)`) and synthesized events (`test_pause_menu.gd` calls `_unhandled_input` directly). `Input.is_action_just_pressed` is frame-stamped and may not flush in headless `-s` mode — so a 30-line probe (`Input.action_press("select_entity")` → explicit `_process(0.016)` → assert placement happened) validates the seam before any characterization test relies on it. If the seam fails, tests drive `_unhandled_input`/public API directly instead (the post-refactor machines are event-driven anyway, which the probe result informs).

## Risks / Trade-offs

- [Commit click double-fires as a unit order] → D3: EntityPlacer click-frame latch + MouseHandler guard check in the same PR; regression test drives both consumers in one tick sequence.
- [GUI event ordering assumptions differ between debug build and test harness] → D7 probe first; tests target the new event-driven API, not the legacy poll loop.
- [`generator_changed` double-fires if Sidebar also calls `cancel()` on toggle-off] → Sidebar toggles call `set_generator`/`cancel` and let the signal (not its own branch) unpress buttons; one subscription, no state mirror.
- [MouseHandler `_process` order vs EntityPlacer `_unhandled_input` order changes cursor behavior on placement frames] → the latch check is "was a placement consumed this frame", not "is placing now", so post-placement frames resolve orders normally.
- [Scene loading: `Sidebar.tscn` gains a node] → additive child node with its own script; existing saves/loads unaffected; no instanced-node properties removed.
- [Fallback path (D5) changes behavior if misread as debug-only] → spec'd as `direct deploy` requirement with a factory-exists negative scenario; production keeps its own `no_prereqs` cost handling.

## Migration Plan

Land in four independently-green PR-sized phases (order matters; each keeps the full suite green):
1. **Geometry + seam**: `TerrainSystem.mouse_ray_to_terrain()` + probe test; switch all four consumers to it (pure refactor, no behavior change).
2. **OrderSystem mode API**: add queries + `generator_changed`; flip MouseHandler/PauseMenu to OrderSystem; Sidebar subscribes; delete `_sell_mode`/`_repair_mode` mirrors.
3. **Placement session**: EntityPlacer placing session + `_unhandled_input` + click latch; MouseHandler guard swap; Sidebar debug block becomes delegates; direct-deploy fallback named and moved; delete skip counter and debug session block.
4. **Production policy + CreditCounter**: `handle_cameo_click` + read API; Sidebar cameo handler collapses; CreditCounter extraction; Sidebar.tscn node added.

Rollback: each phase is a conventional commit range revert; no data/schema changes, no save-format changes.

## Open Questions

- Does the MouseHandler click-latch (D3) generalize into converting MouseHandler's click path to `_unhandled_input` now (bigger, permanent) or strictly stay a latch (small, follow-up)? Default: latch now, conversion as follow-up issue.
- Should BuildingManager's two internal `_update_preview_position` paths collapse to one before or after adopting the shared util? (They differ by `_skip_next_deduction` context; collapsing is safe but not required.) Default: adopt util, keep paths.
