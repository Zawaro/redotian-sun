## 1. Directory Setup

- [x] 1.1 Create `resources/entities/aircraft/` directory

## 2. ArtData Placeholders

- [x] 2.1 Create `resources/art/infantry/e2_art.tres` (placeholder_size=Vector3(0.4, 1.0, 0.4))
- [x] 2.2 Create `resources/art/infantry/e3_art.tres` (placeholder_size=Vector3(0.4, 1.0, 0.4))
- [x] 2.3 Create `resources/art/vehicles/bike_art.tres` (placeholder_size=Vector3(0.8, 0.6, 1.5))
- [x] 2.4 Create `resources/art/vehicles/apc_art.tres` (placeholder_size=Vector3(1.0, 0.8, 2.0))
- [x] 2.5 Create `resources/art/aircraft/orca_art.tres` (placeholder_size=Vector3(1.5, 0.5, 2.0))
- [x] 2.6 Create `resources/art/aircraft/harpy_art.tres` (placeholder_size=Vector3(1.2, 0.5, 1.8))

## 3. Infantry Entity Data

- [x] 3.1 Create `resources/entities/infantry/e2_disc_thrower.tres` with rules.ini stats
- [x] 3.2 Create `resources/entities/infantry/e3_rocket_infantry.tres` with rules.ini stats

## 4. Vehicle Entity Data

- [x] 4.1 Create `resources/entities/vehicles/nod_attack_cycle.tres` with rules.ini stats
- [x] 4.2 Create `resources/entities/vehicles/gdi_apc.tres` with rules.ini stats

## 5. Aircraft Entity Data

- [x] 5.1 Create `resources/entities/aircraft/gdi_orca.tres` with rules.ini stats
- [x] 5.2 Create `resources/entities/aircraft/nod_harpy.tres` with rules.ini stats

## 6. Verification

- [x] 6.1 Run `redot --headless -s test/run_tests.gd` to verify no regressions
- [x] 6.2 Verify EntityFactory loads all new entities (check _entity_cache size)
