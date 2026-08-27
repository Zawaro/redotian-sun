## 1. Bounds gate in OrderSystem

- [x] 1.1 Add `_target_out_of_bounds(target: Node3D, target_cell: Vector2i) -> bool` to `OrderSystem`, cell-tested via `BoundsSystem.is_in_play_area`, mirroring `_fog_filter_target`'s cell/footprint fallback and null-scoping.
- [x] 1.2 Guard `get_cursor`/`get_orders` so an out-of-bounds entity target returns `CursorState.Type.GENERIC_BLOCKED` / empty orders (reject, never fall through to move).
- [x] 1.3 Clamp ground orders (`target == null`) by passing `BoundsSystem.clamp_to_visible_diamond(target_pos)` into the generator so the move/attack-ground lands on the edge while the cursor stays MOVE.

## 2. Test coverage

- [x] 2.1 Create `test/unit/test_order_bounds.gd` covering: ground move outside clamps to in-bounds; ground move inside unclamped.
- [x] 2.2 Add tests: attack on out-of-bounds entity returns empty orders + BLOCKED cursor; in-bounds attack unchanged.
- [x] 2.3 Add tests: harvest/dock on out-of-bounds entity rejected; rally point clamps to edge.
- [x] 2.4 Add test proving an automatic harvester move (`HarvestComponent` → `MovementController.set_target_position`) outside bounds is unaffected.

## 3. Verify

- [x] 3.1 Run `redot --headless -s test/run_tests.gd` and confirm all pass.
- [x] 3.2 Run `gdlint scripts/core/OrderSystem.gd test/unit/test_order_bounds.gd` and `gdformat --check` on both, then grep for accidental tab insertion.