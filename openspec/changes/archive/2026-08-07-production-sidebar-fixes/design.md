## Context

The production and sidebar systems already work in single-player, but a branch review found three
correctness issues and several efficiency issues concentrated in a handful of scripts. All of the
fixes are local; none require new dependencies, new scenes, or data-model changes. The build-time
factor `0.8` is currently duplicated as a constant on `EntityData` and as `GlobalRules.build_speed`,
with a comment noting the two "must match" — a single-source-of-truth smell.

The sidebar rebuilds its whole cameo grid (`queue_free` every child, recreate all buttons) from a
handful of signals — tab switch, scroll, prerequisites changed, and five production signals. Several
of those fire together in a single frame (e.g. `production_completed` + `production_started` when the
queue advances), so the grid can rebuild many times in one frame. Separately, `UIUtil.find_sidebar()`
walks the entire scene tree, and `MouseHandler._process()` calls it (directly and via
`is_mouse_over_sidebar()`) multiple times every frame.

## Goals / Non-Goals

**Goals:**
- Never spawn a unit inside its own factory footprint.
- Scope build-mode-exit queue unblocking to the player who exited.
- Collapse redundant sidebar grid rebuilds to at most one per frame.
- Remove the per-frame full scene-tree walk for the sidebar lookup.
- Give the build-speed factor and the ready-to-place refund a single source of truth.

**Non-Goals:**
- No rewrite of the sidebar to update cameo buttons in place (out of scope; the dirty-flag debounce
  captures the bulk of the cost with a far smaller change).
- No change to exit-cell search geometry, rally points, or `FactoryComponent` spawning.
- No multiplayer input path work beyond the signal-signature fix.

## Decisions

**Exit-cell "not found" is a distinct result, not the center cell.**
`CellUtil.spiral_first_free(center, radius, is_occupied)` returns `center` both when the center is
free and when nothing free is found in range. Because a factory always occupies its own cell, the
center is never a valid free spawn, so `center` returned from the fallback path unambiguously means
"nothing free found." `_find_exit_cell()` now returns `Variant` — the found cell, or `null` when the
result equals the (occupied) center. `_spawn_unit()` treats `null` as failure: it logs a warning and
routes the unit into the existing `_ready_to_spawn` retry list, exactly like the "all factories busy"
case. Reusing that path means the player can retry or cancel-with-refund via the sidebar with no new
UI. Alternative considered: changing `spiral_first_free`'s contract to return a sentinel — rejected
because it is shared by other callers and the local check is smaller and safe.

**`build_mode_changed` carries `player_id`.**
The unblock bug is a missing filter, so the fix routes the player identity through the signal rather
than guessing it downstream. `BuildingManager` emits `build_mode_changed(is_active, player_id)` using
the local player id; `ProductionManager._on_build_mode_changed()` delegates to the existing
`clear_waiting_for_placement(player_id)` helper, which already filters keys by the `player_id:` prefix.
This reuses code that was already written for the correct behavior. Only one listener exists.

**Sidebar refresh is debounced with a dirty flag + deferred call.**
A `_queue_refresh()` sets `_grid_dirty` and defers `_refresh_grid()` once; `_refresh_grid()` clears
the flag on entry. Every signal handler and the tab/scroll/debug paths call `_queue_refresh()` instead
of `_refresh_grid()` directly, so any number of triggers in one frame collapse into a single rebuild at
idle time. This keeps the existing (correct) rebuild logic and is a minimal diff; the per-progress-tick
shader update (`_on_production_progress`) already mutates in place and is left untouched.

**`UIUtil.find_sidebar()` memoizes the resolved node.**
A static cache holds the last resolved `Sidebar`. The lookup returns it when
`is_instance_valid(cache)`, otherwise re-walks and re-caches. A freed node (scene change) fails the
validity check and forces a fresh walk, so the cache self-heals. Fixing it here fixes every caller
(`is_mouse_over_sidebar`, `MouseHandler`) at once. A null result is simply not cached as valid, so the
"no sidebar" case keeps working.

**`get_build_time()` reads `GlobalRules.build_speed`.**
The duplicated `const BUILD_SPEED` is removed. `get_build_time()` reads
`EntityFactory.get_global_rules().build_speed`, falling back to `0.8` when rules are unavailable (e.g.
isolated unit tests). This is an O(1) property read, safe in the production hot loop.

**Ready-to-place entries store the deducted amount.**
`_ready_to_place[player_id]` becomes a list of `{ "data": EntityData, "deducted": float }`. On
completion the reconciled `item.deducted` (exactly `cost`) is stored. `cancel_ready_building()` refunds
the stored amount instead of re-reading `data.cost`, so the refund cannot drift if deduction accounting
ever changes. `get_ready_buildings()` still returns an `Array` of `EntityData` for the sidebar, so no
caller outside `ProductionManager` changes.

**Constant rename.** `SEGMENT_WIDTH_RATIO` → `SEGMENT_PX_PER_UNIT` (value `20.0`), updating its single
use site. Pure clarity, no behavior change.

## Risks / Trade-offs

- [Deferred grid refresh runs at end of frame, not instantly] → Imperceptible for a build menu; tab and
  scroll still resolve within the same frame.
- [Static sidebar cache persists across scene changes] → Guarded by `is_instance_valid`; a freed node
  forces a re-walk, so stale references cannot be returned.
- [`get_build_time()` depends on `EntityFactory` being available] → Falls back to `0.8` when the
  autoload or rules resource is missing, preserving current numeric behavior.
- [Signal signature change] → Only one connection exists in the codebase; both emit sites are updated
  in the same change.
