## 1. Impact report dedup

- [x] 1.1 Add the `impact_played(damage_type, position)` signal to `EntityFactory` and make `play_impact_effects_at` an instance method that emits it
- [x] 1.2 Return early in `EntityFactory._on_entity_damaged` when `SpatialHash.is_overlay_entity(entity)` so a mixed entity+overlay hit reports once
- [x] 1.3 Add `test_mixed_entity_and_overlay_hit_plays_one_impact_report` in `test_ground_shot_damage.gd` (counts exactly one report)

## 2. Overlay scan gate

- [x] 2.1 Early-return in `SpatialHash.find_cell_overlays` when `not can_damage_walls and not can_damage_tiberium`
- [x] 2.2 Add `test_incapable_warhead_scans_no_overlays` (empty for a no-flag warhead, one for `can_damage_walls`)

## 3. Ground projectile max range

- [x] 3.1 Free a ground shot at `_max_range` inside the `not target_valid` branch of `ProjectileController._physics_process`, reusing the branch's single return
- [x] 3.2 Add `test_ground_projectile_fizzles_at_max_range`

## 4. Force-fire shroud gate

- [x] 4.1 Pass the raw `target_pos` (not the bounds-clamped `bounds.pos`) to `_ground_shroud_gate` in `OrderSystem.get_cursor` and `get_orders`
- [x] 4.2 Add `test_force_fire_outside_diamond_judges_clicked_cell_not_clamp`

## 5. Minimap deck targeting

- [x] 5.1 Resolve the clicked cell's top surface level/height in `Minimap._handle_click` and set `MOD_TARGET_LEVEL`

## 6. Process and verification

- [x] 6.1 Mark archived `add-force-fire-ground-targeting` task 8.4 complete with an automated-coverage note
- [x] 6.2 `gdlint` and `gdformat --check` clean on all changed scripts/tests; no tabs introduced
- [x] 6.3 Full suite green (`redot --headless -s test/run_tests.gd`): 11129 passed, 0 failed
