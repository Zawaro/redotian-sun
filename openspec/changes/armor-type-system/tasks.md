## 1. Armor Type Data Layer

- [x] 1.1 Create `scripts/data/ArmorType.gd` (`class_name ArmorType extends Resource`) with `id`, `display_name`, `color` fields
- [x] 1.2 Create armor type `.tres` files: `resources/armor_types/{none,wood,light,heavy,concrete}.tres` (values from rules.ini armor classes)
- [x] 1.3 Add unit tests for ArmorType resource properties

## 2. Warhead Data Rework

- [x] 2.1 Change `WarheadData.armor_damage_multipliers` from `PackedFloat32Array[5]` to `Dictionary` keyed by armor id; update `validate()` to check every key exists in the GlobalRules armor registry and every registered armor type has an entry
- [x] 2.2 Author warhead `.tres` files under `resources/warheads/` from rules.ini `Verses=` values for all warheads referenced by weapon `.tres` files: SA, AP, HE, Super, Fire, Gas, Mechanical, HollowPoint, SonicWarhead, RailShot, RailShot2, PlasmaWH, Organic, ORCAHE, ORCAAP, ARTYHE, EMPuls, Slimer, Shard, SAMWH, RPG (default multipliers 1.0 for warheads without a Verses line)
- [x] 2.3 Add unit tests for WarheadData keyed-multiplier lookup and validate() coverage

## 3. GlobalRules Registries

- [x] 3.1 Repurpose `GlobalRules.armor_types` to `{id: ArmorType}` registry; add `get_armor_type(id)`, `get_armor_ids()`
- [x] 3.2 Add `GlobalRules.warheads: Dictionary` `{id: WarheadData}` and `get_warhead(id)`
- [x] 3.3 Add `min_damage: int = 1` and `max_damage: int = 1000` fields
- [x] 3.4 Add warhead armor-multiplier lookup helper (unknown warhead/armor → 1.0, supports >1.0 and 0.0)
- [x] 3.5 Register armor types and warheads in `resources/global_rules.tres`
- [x] 3.6 Add unit tests for GlobalRules registries, accessors, and multiplier lookup (known/unknown/overkill/zero)

## 4. Combat Damage Resolution

- [x] 4.1 Update `CombatComponent._fire_weapon()` to resolve `weapon.warhead` → WarheadData, look up multiplier for target `StatsComponent.armor`, compute `clampi(round(damage * multiplier), min_damage, max_damage)`, and pass the final value to `take_damage`
- [x] 4.2 Add unit tests for armor resolution (SA vs heavy, AP vs heavy, min floor, max cap, zero-damage pairing, unknown warhead/armor fallback)

## 5. Remaining GlobalRules Wiring

- [x] 5.1 Add `StatsComponent.veteran_level: int = 0`; apply veteran armor reduction to incoming damage
- [x] 5.2 Apply `veteran_speed` in MovementController; apply tracked/wheeled uphill/downhill slope coefficients from terrain grade
- [x] 5.3 Wire `build_speed` / `multiple_factory` into ProductionManager; `EntityData.get_build_time()` accepts optional build_speed
- [x] 5.4 Wire `repair_step` into `BuildingManager.repair_building()`
- [x] 5.5 Expose `CombatComponent.get_effective_damage()` with `veteran_combat` scaling
- [x] 5.6 Add unit tests for veterancy (combat/speed/armor), slope coefficients, production constants, repair step

## 6. Validation & Cleanup

- [x] 6.1 Run test suite headless (`redot --headless -s test/run_tests.gd`) and confirm all tests pass
- [x] 6.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; fix violations and check for tab introduction
- [x] 6.3 Update openspec delta specs (global-rules, combat-firing, armor-types) to final state
