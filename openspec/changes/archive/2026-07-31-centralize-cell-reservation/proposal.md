## Why

Sub-slot reservation logic is scattered across four consumers with no single source of truth (issue #181): `MovementController._assign_sub_slot_at_cell()` (two-loop scan gated on the transient `_has_sub_slot` flag), `SelectionManager.request_move()` (its own `cell_occupancy` dict that writes `mc._assigned_slot` directly), `EntityPlacer.place_entity()` (a near-copy of the loop), and `SpatialHash._infantry_cell_counts` (IDLE-only capacity). The flag is cleared on arrival while the unit keeps standing on its sub-slot offset, so later arrivals — especially the combat path, which bypasses SelectionManager entirely — cannot see the claim and pile onto the same slot.

## What Changes

- Add `CellReservation` autoload (registered in `project.godot`) as the single source of truth for **in-flight** sub-slot claims. Present occupancy is derived from the SpatialHash grid, so idle units' slots stay visible without holding persistent claims.
- **Present/coming split**: idle infantry occupancy is read from the grid via the unit's assigned slot; only units still *en route* hold a registry claim. Claims are released on arrival.
- Slot claims are made inside `MovementController.set_target_position` (covers both selection moves and the combat path), with an idempotent same-cell retention rule.
- Full-cell fallback: when a target cell has no free slot, the unit spreads via `_find_nearest_free_cell` and re-claims, instead of piling at cell center.
- Capacity becomes `physical idle infantry + in-flight claims`, infantry-scoped only. Vehicle blocking stays purely physical.
- `SelectionManager` drops its `cell_occupancy` dict and `mc._assigned_slot` write; it keeps capacity-aware cell spreading via the new capacity query.
- `EntityPlacer.place_entity()` delegates spawn-slot assignment; `ExitComponent`'s defensive flag write is replaced with a claim release.

## Capabilities

### New Capabilities
- `cell-reservation`: centralized in-flight sub-slot registry (claim/release/capacity), present/coming occupancy split, and auto-cleanup on owner free

### Modified Capabilities
- `infantry-occupancy`: sub-slot occupancy uses the present/coming split; capacity counts physical idle infantry plus in-flight claims, infantry-scoped
- `selection-manager`: removes slot pre-assignment (`_assigned_slot` write + `cell_occupancy`); cell spreading uses the combined capacity query

## Impact

- `project.godot` — register `CellReservation` autoload
- `scripts/core/CellReservation.gd` — new registry autoload
- `scripts/components/MovementController.gd` — `_assign_sub_slot_at_cell` delegates to the registry + grid; spread fallback; release on arrival/stop/death
- `scripts/core/SelectionManager.gd` — remove `cell_occupancy`/`_assigned_slot` write; capacity via CellReservation
- `scripts/entities/EntityPlacer.gd` — delegate spawn slot assignment
- `scripts/components/ExitComponent.gd` — defensive claim release on spawn-out
- `test/unit/test_cell_reservation.gd` — new registry + lifecycle tests
- `test/unit/test_movement_controller.gd` — sub-slot behavior tests (existing file, extended)
