## 1. Data model

- [x] 1.1 Add `jumpjet_target_height: float = 5.0` export to `scripts/data/Locomotor.gd` (terrain height units)
- [x] 1.2 Set `jumpjet_target_height = 5.0` in `resources/locomotors/Jumpjet.tres`

## 2. MovementController vertical state machine

- [x] 2.1 Add `enum VerticalState { GROUND, ASCENDING, AIR, DESCENDING }` + `_vertical_state` field
- [x] 2.2 Compute `_jumpjet_air_height = jumpjet_target_height * HEIGHT_STEP` in `_resolve_locomotor()`; keep `_hover_height` for hover only
- [x] 2.3 Change `_is_floating()` to `_is_hover or (_is_jumpjet and _vertical_state != GROUND)`
- [x] 2.4 Add `_update_vertical(delta)` moving Y at `move_speed * delta` with ASCENDING→AIR / DESCENDING→GROUND transitions; call it in `_physics_process` IDLE branch and the moving path
- [x] 2.5 Add `_apply_zone_desire()` (GROUND↔AIR transitions, reversal handling)
- [x] 2.6 Extend `set_target_position(target, unblock_buildings, keep_zone = false)`: desired zone from move path, `keep_zone` retention, and "new order while descending → AIR"
- [x] 2.7 Guard all Y-snaps (arrival branches, `_handle_wait`, `_snap_to_terrain`) to skip jumpjets so `_update_vertical` owns altitude
- [x] 2.8 Make `_terrain_speed_factor()` return 1.0 when jumpjet is airborne

## 3. CombatComponent

- [x] 3.1 Pass `keep_zone = true` in `_move_toward_target()`
- [x] 3.2 Change range check to horizontal (XZ) distance in `_physics_process()`

## 4. Tests

- [x] 4.1 Unit tests: jumpjet target-height config (default 5.0 × HEIGHT_STEP; override)
- [x] 4.2 Unit tests: ascend/descend transitions move Y at `move_speed * delta` and reach GROUND/AIR
- [x] 4.3 Unit tests: `keep_zone` attack retention (grounded walks, airborne flies, mid-transition ascends)
- [x] 4.4 Unit tests: hover on fly-order arrival; land on walk-order arrival; descend interrupt ascends
- [x] 4.5 Unit tests: airborne terrain speed factor = 1.0
- [x] 4.6 Unit tests: CombatComponent XZ range check (vertical separation ignored, airborne attacker fires)
- [x] 4.7 Run full suite (`redot --headless -s test/run_tests.gd`) + `gdlint` / `gdformat` check on new/edited files

## 5. Finalization

- [x] 5.1 Update `openspec/specs/` (new `jumpjet-vertical-transitions`, delta `combat-firing`) by archiving the change
- [x] 5.2 Commit on `feat/34-locomotor-enforcement-movement-zones` with Conventional Commits format referencing #34
