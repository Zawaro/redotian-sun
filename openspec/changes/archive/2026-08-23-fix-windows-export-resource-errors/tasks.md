# Implementation Tasks

## 1. Fix warhead multiplier serialization

- [x] 1.1 Rewrite `armor_damage_multipliers` in `resources/warheads/fire2.tres` as a keyed dictionary (clone of fire: `{"none": 6.0, "wood": 1.48, "light": 0.59, "heavy": 0.06, "concrete": 0.02}`)
- [x] 1.2 Rewrite `armor_damage_multipliers` in `resources/warheads/firestormwh.tres` as a keyed dictionary (all `1.0`)
- [x] 1.3 Rewrite `armor_damage_multipliers` in `resources/warheads/ioncannonwh.tres` as a keyed dictionary (all `1.0`)
- [x] 1.4 Rewrite `armor_damage_multipliers` in `resources/warheads/ionwh.tres` as a keyed dictionary (`none:0.9, wood:0.75, light:0.6, heavy:0.25, concrete:1.0`)
- [x] 1.5 Rewrite `armor_damage_multipliers` in `resources/warheads/tankogas.tres` as a keyed dictionary (`none:0.9, wood:1.0, light:0.6, heavy:0.25, concrete:0.1`)
- [x] 1.6 Rewrite `armor_damage_multipliers` in `resources/warheads/veinholewh.tres` as a keyed dictionary (all `1.0`)
- [x] 1.7 Confirm each of the 6 files has no remaining `PackedFloat32Array` or trailing `}` mismatch

## 2. Fix ResourceCrystal scene mesh references

- [x] 2.1 Add `[sub_resource type="CubeMesh" id="CubeMesh_resource"]` to `scenes/entities/terrain/ResourceCrystal.tscn` and bump `load_steps`
- [x] 2.2 Replace bare `mesh = CubeMesh` with `mesh = SubResource("CubeMesh_resource")` on Stage0/Stage1/Stage2
- [x] 2.3 Confirm any other scenes/scripts referencing `ResourceCrystal.tscn` still load

## 3. Remove the stray HitboxComponent fragment

- [x] 3.1 `git rm scripts/components/HitboxComponent.tres` (orphan: path and uid referenced nowhere; canonical `scenes/components/HitboxComponent.tscn` untouched)
- [x] 3.2 Confirm `scenes/components/HitboxComponent.gd` + `.tscn` are unchanged and `entities/EntityFactory` HitboxComponent instantiation path still resolves

## 4. Verify no load errors

- [x] 4.1 Run `redot --headless --import` — no parse/load errors for resources/warheads/*, ResourceCrystal.tscn, or HitboxComponent.tres
- [x] 4.2 Re-run the Windows export — completes without "Failed loading resource" / "No loader found" errors
- [x] 4.3 Run the test suite (`redot --headless -s test/run_tests.gd`) — no regressions

## 5. Packed-build data catalog fix

- [x] 5.1 Fresh Linux export from current branch (`redot --headless --export-release Linux`) — confirm `Unknown entity id` + `no art for family ''` reproduced on current code
- [x] 5.2 Instrument `EntityFactory._scan_directory` (and `TerrainCatalog` counterpart) to log per-file `load()` result / `ResourceLoader.get_resource_type()` — isolate whether DirAccess enumeration, script-class resolution, or `load == null` is the failing step inside the pack
- [x] 5.3 Implement the minimal root-cause fix per design D4a/D4b (keep the shared `register_data_set()` pattern; no hardcoded id lists, no `.godot` dependency)
- [x] 5.4 Re-export Linux AND Windows; run `TestMap02` headless from each `pck` — zero `Unknown entity id:`, zero `no art for family ''`
- [x] 5.5 Confirm editor flow unaffected (run map via normal startup) and full test suite still green

## 6. Folded housekeeping

- [x] 6.1 Diagnose `test/unit/test_terrain_system.gd` pre-existing parse error
- [x] 6.2 Fix the parse error (keeping assertions meaningful) or, if genuinely stale, document and remove deliberately — never weaken an assert
- [x] 6.3 Re-run full test suite — `test_terrain_system.gd` runs with 0 failures