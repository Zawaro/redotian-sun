## 1. Regression test (write first, proves the bug)

- [x] 1.1 In `test/unit/test_vision_component.gd`, add `test_building_reveal_centered_on_footprint`: build an entity with `entity_type = BUILDING`, `foundation = Vector2i(2, 2)`, `sight = 3`, `player_id = 0`, position it at `CellUtil.cell_origin_to_world(origin, Vector2i(2, 2))`, add it to the container, and call `_physics_process(0.0)`
- [x] 1.2 Assert a cell inside the footprint is visible, and assert a cell one step diagonally outside the footprint on the `-X,-Z` side (`origin - Vector2i(1, 1)`) is visible; today the reveal disc sits off the footprint so this fails
- [x] 1.3 Assert the reveal is not offset: compare visibility of `origin - Vector2i(1, 1)` and `origin + foundation` (both should be visible with sight 3), so a one-sided offset cannot pass
- [x] 1.4 Run `redot --headless -s test/run_tests.gd` and confirm the new test fails on the unfixed implementation

## 2. Fix `VisionComponent._center_cell()`

- [x] 2.1 In `scripts/components/VisionComponent.gd`, remove the `if _foundation != Vector2i(1, 1)` half-foundation offset from `_center_cell()` and return `CellUtil.world_to_cell(_parent.global_position)`
- [x] 2.2 Update the `_center_cell()` behavior comment to state that an entity's `global_position` is already the footprint center (placed by `cell_origin_to_world`), so no footprint offset is applied

## 3. Verify

- [x] 3.1 Run `redot --headless -s test/run_tests.gd`; the new test and the full suite pass
- [x] 3.2 Confirm the existing building vision tests still pass unchanged (`test_building_registers_once_permanent`, `test_building_revealer_ignores_terrain`)
- [x] 3.3 Run `gdlint scripts/components/VisionComponent.gd test/unit/test_vision_component.gd` and `gdformat --check scripts/components/VisionComponent.gd test/unit/test_vision_component.gd`
- [x] 3.4 Run `grep -P '\t' scripts/components/VisionComponent.gd test/unit/test_vision_component.gd` to confirm no tabs were introduced

## 4. Close out

- [x] 4.1 Note in the PR description that `blocks_terrain = false` for building revealers is a separate, undecided concern (terrain occlusion) and link the issue
- [x] 4.2 After merge, archive the change with `/opsx-archive`
