## 1. Shared nearest-point primitive

- [x] 1.1 Add `nearest_world_point(from: Vector3) -> Vector3` to `scripts/components/FoundationComponent.gd`: footprint rectangle centered on the parent entity's `global_position`, half-extents `foundation * CellUtil.CELL_SIZE * 0.5`, per-axis XZ clamp, Y from the entity.
- [x] 1.2 Add a comment naming the axis-aligned/no-rotation assumption and the upgrade path.
- [x] 1.3 Add geometry tests to `test/unit/test_foundation_component.gd`: outside a face, outside a corner, inside returns self, 1x1 footprint. Expected points computed independently (not from the production formula).

## 2. CombatComponent engagement geometry

- [x] 2.1 Add the failing regression test in `test/unit/test_combat_component.gd`: 4x4 building target, attacker where the footprint center is out of range but the nearest edge is in range; assert it fails to fire on the current code, for the intended reason.
- [x] 2.2 Add `_target_foundation: FoundationComponent` resolved in `set_target` and cleared in `clear_target`.
- [x] 2.3 Add `_effective_target_pos() -> Vector3` (foundation nearest point when a valid component is cached, else `_target.global_position`).
- [x] 2.4 Point `_horizontal_distance` at `_effective_target_pos` (covers range checks and the `close` threshold).
- [x] 2.5 Point `_aim_turrets` and the `_tick_channel` turret slew at `_effective_target_pos`; point `_is_facing_target` at it for `face_toward`.
- [x] 2.6 In `_move_toward_target`, compute the effective point once and use it for the direction, the ground and jumpjet stop positions, and every in-range pull-back / final verification. Keep `_chase_leg_enemy_cell` keyed on `_target.global_position`.
- [x] 2.7 Confirm the regression test from 2.1 passes, and that a 1x1 building and a unit target still measure to `global_position`.

## 3. Guard acquisition consistency

- [x] 3.1 In `GuardComponent._find_nearest_enemy`, measure candidate distance to `nearest_world_point(origin)` for candidates whose `StatsComponent.is_structure()` is true; otherwise `other.global_position`.
- [x] 3.2 Add a test in `test/unit/test_guard_component.gd`: a hold-ground guard acquires an adjacent large building whose center is out of weapon range; a unit outside range stays ignored.

## 4. Test coverage for the changed behaviour

- [x] 4.1 `test/unit/test_combat_component.gd`: attacker stops `range` from the nearest footprint edge, not the center (independently computed expected position).
- [x] 4.2 `test/unit/test_combat_component.gd`: body-facing receives the nearest footprint point (corner-approach case).
- [x] 4.3 `test/unit/test_combat_component.gd`: keep `test_ground_attack_in_range_stops_and_fires`, `test_range_horizontal_distance_used`, `test_moving_attacker_holds_fire_until_facing`, and the 1x1/unit cases green.
- [x] 4.4 `test/unit/test_combat_component_jumpjet.gd`: extend `test_jumpjet_attack_approaches_nearest_point` with a building target; keep the unit-target case unchanged.

## 5. Verification

- [x] 5.1 Run `redot --headless -s test/run_tests.gd` and confirm all tests pass.
- [x] 5.2 Run `gdlint` and `gdformat --check` on the touched scripts and tests.
- [x] 5.3 Run the `grep -P '\t'` tab check per `AGENTS.md`.
- [x] 5.4 Confirm no `.tscn` / `.tres` / `.uid` changes are needed beyond the touched scripts' `.uid` files.
- [x] 5.5 Run `openspec validate fix-360-building-attack-range` and archive the change before merge.

## 6. Review fixes (projectile regression and consistency)

- [x] 6.1 Extend `ProjectileController.setup` `_max_range` by the target foundation half-diagonal for structure targets, so physical shots reach the centre.
- [x] 6.2 Gate `CombatComponent`'s foundation resolution on `StatsComponent.is_structure()`, matching `GuardComponent`.
- [x] 6.3 Bump `BUILDING_HOOD_MARGIN_CELLS` to 4 (rounding slack) and document it.
- [x] 6.4 Regression test: physical projectile damages a 4×4 building fired from nearest-edge range, verified to fail without 6.1.
- [x] 6.5 Tests: multi-cell non-structure measured as a point; guard diagonal-corner building acquisition.
- [x] 6.6 Add the `projectile-runtime` spec delta and revise proposal/design (projectile is functional; guard margin; classifier; `close` semantics).
