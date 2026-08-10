## Why

Issuing a move order to a large group of infantry (e.g. 60 light infantry, GH #279) drops FPS ~80% while the group moves. Profiling pins the cost on `ShroudSystem` re-stamping: on every cell crossing, `VisionComponent` unregisters and re-registers the revealer, running **two full disc shadowcasts** (old disc at -1, new disc at +1) each dominated by per-cell Bresenham LOS walks (`_cell_reachable` ≈ 73% of stamp time). With 60 moving infantry that is ~42 stamps / ~4.1ms per frame — sustained for the whole march.

## What Changes

- Add `ShroudSystem.move_revealer(player_id, key, new_cell)`: re-stamps only the **entering/exiting crescent** (the geometric symmetric difference between the old and new discs, O(r) cells) instead of two full O(r²) disc stamps. Overlap cells are untouched — their `visible_count` contribution is unchanged, so no re-stamp is needed.
- `VisionComponent._physics_process` calls `move_revealer` on cell crossing in place of the `_unregister()` + `_register()` pair.
- `register_revealer` / `unregister_revealer` semantics, the Bresenham LOS algorithm, `visible_count` ref-counting, and the resolve cadence are **unchanged**. Buildings still register once and stop processing; temp reveals (`reveal_area`) are unaffected.
- Documented approximation: a revealer's overlap cells whose LOS reachability flips (cells whose sight segment passes within ~1 cell of a terrain blocker — shadow edges) are not re-evaluated on a move; such rare flips self-correct on the next crossing. Making this exact would cost the full re-walk and defeat the purpose.
- Add a perf-guard test asserting a `move_revealer` re-stamps only the crescent, not the full disc.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `fog-of-war`: revealer-movement requirement now specifies an incremental `move_revealer` path (crescent re-stamp, overlap untouched, shadow-edge flip caveat) instead of the unregister+register pair; the incremental-updates requirement gains the "re-stamp only the crescent on move" rule.

## Impact

- `scripts/core/ShroudSystem.gd` — new `move_revealer()`; revealer entries need a last-stamped cell (old disc source); `unregister_revealer` stamps from the last-stamped cell.
- `scripts/components/VisionComponent.gd` — crossing path calls `move_revealer` (`VisionComponent.gd:58-60`).
- `test/unit/test_shroud_system.gd` — new `move_revealer` cases (enter-only, exit-only, overlap-unchanged, terrain-edge self-correction); a `test_perf_guard.gd` style guard.
- No scene, resource, or data changes; no rendering-cadence changes.
