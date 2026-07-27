## 1. GlobalRules helper methods

- [x] 1.1 Add `veteran_combat_multiplier(level)`, `veteran_speed_multiplier(level)`, `veteran_armor_multiplier(level)` to `GlobalRules` (level clamped to `veteran_cap`)
- [x] 1.2 Add `compute_final_damage(base_damage, armor_type, veteran_level)` applying armor modifier + veteran armor reduction, floored at 1 for positive input
- [x] 1.3 Add `production_speed_multiplier(factory_count)` = `1.0 + max(0, count-1) * multiple_factory`
- [x] 1.4 Add `movement_slope_coefficient(locomotor, grade)` returning tracked/wheeled uphill/downhill interpolation, 1.0 for unrecognized locomotor and flat grade

## 2. Armor + veterancy damage (HealthComponent / StatsComponent)

- [x] 2.1 Add `veteran_level: int = 0` export to `StatsComponent`
- [x] 2.2 Make `HealthComponent.take_damage()` resolve the sibling `StatsComponent` and `GlobalRules` (cached, null-guarded) and apply `compute_final_damage` before subtracting; emit the applied amount

## 3. Veterancy speed and combat

- [x] 3.1 Scale `MovementController.move_speed` by `veteran_speed_multiplier(veteran_level)` in `_ready`
- [x] 3.2 Add `CombatComponent.get_effective_damage(weapon)` applying `veteran_combat_multiplier` from the sibling `StatsComponent`

## 4. Movement slope coefficients

- [x] 4.1 Add `MovementController.configure(data)` wiring `locomotor`/`movement_zone` from `EntityData`
- [x] 4.2 In the moving state, sample terrain grade ahead and multiply speed by `movement_slope_coefficient(locomotor, grade)` (null-guarded)

## 5. Production constants

- [x] 5.1 Add optional `build_speed` parameter to `EntityData.get_build_time()` defaulting to the existing constant
- [x] 5.2 In `ProductionManager`, pass `rules.build_speed` to `get_build_time()` and use `rules.production_speed_multiplier(count)` in `_get_production_speed()`, guarding null rules

## 6. Repair step

- [x] 6.1 Source the heal amount in `BuildingManager.repair_building()` from `GlobalRules.repair_step` (null-guarded fallback to 8)

## 7. Tests and quality gate

- [x] 7.1 Add `test/unit/test_global_rules.gd` covering the helper methods (armor+veteran damage, veteran multipliers + cap, production multiplier, slope coefficient, build-time scaling)
- [x] 7.2 Add `test/unit/test_health_component.gd` covering the armor/veterancy `take_damage` path with a real `StatsComponent`
- [x] 7.3 Run gdformat + gdlint + headless test suite; all green
