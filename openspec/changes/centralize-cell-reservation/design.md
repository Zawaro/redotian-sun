## Context

Sub-slot assignment lives on `MovementController` as `_assigned_slot` / `_sub_slot_position` / `_has_sub_slot`, read cross-entity via private-field access and an O(n) scan of the whole `entities` group. The flag is transient: cleared on arrival (`MovementController.gd:388, 440`) and in `_finish_stop()` while the unit stays at its sub-slot offset. Because the "already at cell" check is gated on `_has_sub_slot`, an idle occupant's slot is invisible to later arrivals. `SelectionManager.request_move` pre-assigns `mc._assigned_slot` from a `cell_occupancy` dict that only counts IDLE infantry, so a second order can overshoot a cell's 3 slots. `CombatComponent._move_toward_target` calls `set_target_position` directly, bypassing all of the above — the main piling path.

Chosen model (option B): a **present/coming split**. Present occupancy comes from the SpatialHash grid (physical reality, cannot leak); only in-flight (coming) units hold registry claims. This avoids persistent idle claims entirely while still fixing the pile: the "at cell" check reads the grid entry's always-set `_assigned_slot` instead of the transient flag.

## Goals / Non-Goals

**Goals:**
- Single source of truth for in-flight sub-slot claims and combined capacity
- Idle occupants' slots visible to later arrivals without persistent claims
- Race-free, deterministic slot assignment under ordered batching
- Combat path fixed for free (routes through `set_target_position`)
- Spread fallback instead of cell-center piling when a cell is full
- Auto-cleanup of claims on unit free

**Non-Goals:**
- Vehicle cell reservation (`SpatialHash._reserved`) — separate concern, unchanged
- Building blocking / BIB cells — unchanged in SpatialHash
- `CellSubPositions` position math — unchanged
- Preferred-slot hint from SelectionManager — dropped (ordered batching + spread produce the same result)
- Terrain passability / movement zones — issue #34, requires a terrain data model
- Full Locomotor system — deferred to #34

## Decisions

### 1. Autoload, not static class

**Decision**: `CellReservation` is a Node autoload registered in `project.godot` (14th singleton), mirroring SpatialHash.

**Rationale**: The registry is *stateful* — the only static-class precedent (`CellSubPositions`) is stateless. Autoloads get lifecycle hooks, are discoverable in `project.godot`, and the test runner already injects autoloads. Static state would lack a natural reset point across matches/tests.

**Alternative considered**: Static `class_name` with a static dict. Rejected — stateful static singletons have no repo precedent, no reset point, and are invisible to new devs.

### 2. Present/coming split — no persistent idle claims

**Decision**: `CellReservation` holds claims only for units *en route* (not yet present in the SpatialHash grid at the destination cell). Present idle infantry are counted via the grid, reading each entry's always-set `_assigned_slot`.

**Rationale**: Deriving present occupancy from physical data cannot leak or go stale. Claims (intent) only cover the gap where a unit is coming but not yet present. This eliminates the whole release/keep matrix (no stop-state disambiguation, no phantom idle claims) while fixing the pile, because the "at cell" check no longer depends on the transient `_has_sub_slot` flag.

**Alternative considered**: Persistent idle claims with a release matrix (option A). Rejected — fragile across IDLE/MOVING/WAIT/ROTATING stop semantics and leaks a slot forever on a missed release.

### 3. Claim at movement start, single path

**Decision**: `set_target_position` claims via `CellReservation.reserve_sub_slot(cell, owner)`. Same-cell re-reserve is idempotent (returns the existing claim unchanged); a move to a different cell releases the old claim.

**Rationale**: Every destination decision funnels through `set_target_position` — selection moves, combat moves, scatter nudges, rally — so one claim site covers all paths. Idempotency prevents slot shuffling on repeated orders to the same cell (combat re-approach).

**Alternative considered**: Immediate claim at order time in `request_move`. Rejected — combat doesn't route through SelectionManager, so two claim sites would be needed, plus release-on-cancel wiring for moves that never start.

### 4. Full-cell spread fallback

**Decision**: When `reserve_sub_slot` returns -1 (no free slot), `MovementController` falls back to `_find_nearest_free_cell(target_cell)` and re-claims there instead of settling at cell center.

**Rationale**: Closes the concurrent-order gap (two orders targeting the same cell in the same frame both see 0 claims at capacity-query time). The late claimer finds the cell full and spreads — same safety as immediate reservation, without order-time claims.

### 5. Combined, infantry-scoped capacity

**Decision**: `CellReservation.is_cell_full(cell)` returns true when `physical idle infantry (grid) + in-flight claims >= 3`. It is consulted only by infantry targeting (`_find_infantry_cell`, `_assign_sub_slot_at_cell`). Vehicle blocking and `_is_cell_occupied_by_idle` vehicle paths stay purely physical.

**Rationale**: Physical count cannot overshoot; claims catch in-flight units before arrival. Scoping to infantry prevents claims from blocking vehicles on physically-empty cells.

### 6. Cleanup on owner free

**Decision**: Release claims on the owner's `tree_exited` (connected once per owner). Every read additionally prunes entries whose owner fails `is_instance_valid`.

**Rationale**: Death is `health_zero → queue_free()` (deferred); `tree_exited` is the reliable release point and covers death, map teardown, and editor deletion. TransportComponent never removes units from the tree (verified), so no spurious releases. Pruning guards against any missed signal.

### 7. Release timing

**Decision**: Arrival (IDLE at destination) and mid-path stop release the claim; the claim is otherwise replaced on the next move via re-reserve. `_finish_stop` releases the claim.

**Rationale**: With the present/coming split, a present unit needs no claim — release on arrival is correct and matches current behavior; the pile is fixed by grid-slot visibility, not by holding the claim.

### 8. Remove the flag gate

**Decision**: `_assign_sub_slot_at_cell` builds taken slots from (a) grid entries at the cell via `_assigned_slot` (no `_has_sub_slot` gate) and (b) `CellReservation` claims on the cell. `_has_sub_slot`/`_assigned_slot` remain on MC only as the local claim cache, set from the registry result.

**Rationale**: Minimal drift surface; the registry is the source of truth, MC mirrors the result for its own pathing math.

## Risks / Trade-offs

- **Stale claim on missed `tree_exited`** → reads prune `!is_instance_valid` owners; worst case a slot is withheld one frame.
- **Double counting present+coming** → an in-flight unit near the destination cell boundary could appear in both grid and registry; the grid `get_entries(cell)` only includes units physically in that cell, so overlap is bounded and self-corrects on arrival.
- **Behavior change**: infantry no longer gate occupancy on `_has_sub_slot` — that is the fix, not a regression; idle spreading is preserved via `_assigned_slot`.
- **Two counts must agree at steady state** → documented invariant plus a test comparing grid physical count + claims to `CellReservation` capacity.
- **`_scatter_blockers` / `nudge_from_cell` / ExitComponent nudges** call `set_target_position` on other units → handled naturally by reserve/release in the API.
