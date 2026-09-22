## 1. Feature-flag infrastructure

- [x] 1.1 Add `features: Dictionary` + `has_feature(id) -> bool` to `GameDefinition`
- [x] 1.2 Add null-safe `GameContext.has_feature(id) -> bool`
- [x] 1.3 Add a `features` block to `games/ts/game.tres` (`breakable_ice`, `resource_tree_regrowth` = true)
- [x] 1.4 Update `GLOSSARY.md` `game definition` row + `feature flag` term
- [x] 1.5 Tests: declared on/off, undeclared, null context

## 2. GlobalRules numeric extraction

- [x] 2.1 Add `power_bar_max_output` + `power_bar_curve_exponent`; PowerBar reads rules with fallback
- [x] 2.2 Add `logic_fps`; CombatComponent ROF uses it (fallback 30)
- [x] 2.3 Add `refinery_unload_rate`; DockUnloadComponent uses it (sentinel default)
- [x] 2.4 Add `homing_turn_per_sec_per_unit`; ProjectileController uses it
- [x] 2.5 Add `primary_resource_category`; EconomyManager default + SelectComponent + DebugMenu use it
- [x] 2.6 Update global-rules-wiring / sidebar-power-ui tests

## 3. Locomotor slope coefficients

- [x] 3.1 Add `uphill_factor`/`downhill_factor` (default 1.0) to `Locomotor`
- [x] 3.2 MovementController reads them; drop `Track`/`Wheel` match and `tracked_*`/`wheeled_*` rules fields
- [x] 3.3 Set factors on `games/ts/locomotors/Track.tres` and `Wheel.tres`
- [x] 3.4 Update `test_movement_locomotor` slope expectations

## 4. EntityData flags + factory migration

- [x] 4.1 Add `breakable_surface`, `resource_spawner`, `procedural_resource_visual`, `harvestable_categories` to `EntityData`
- [x] 4.2 EntityFactory/EntityPlacer branch on flags, drop `"tiberium"`/`"tiberium_tree"`/`ICE` string checks
- [x] 4.3 HarvestComponent `configure()` reads `harvestable_categories`; drop tiberium default and dead radius field
- [x] 4.4 Neutral `resource_type_id` defaults (`""`) + neutral (white) fallback colour
- [x] 4.5 Set the new flags/categories on the relevant `games/ts` entity `.tres`

## 5. Feature gates

- [x] 5.1 Gate ice component + movement damage + pathfinder footing on `breakable_ice`
- [x] 5.2 Gate tree processing in ResourceGrowthSystem on `resource_tree_regrowth`
- [x] 5.3 Remove inert `visceroids`/`meteorites`/`weed_capacity`/`crew_escape` from GlobalRules
- [ ] 5.4 PowerBar feature gate — dropped: the pseudo-flag `twin_power_bar` was fabricated; the
  TS-specific part (scale/curve) is now data (#2.1). No gate needed.

## 6. UI + art data-driven

- [x] 6.1 `GameDefinition.sidebar_tabs`; Sidebar resolves tabs + rebuilds buttons from data
- [x] 6.2 Per-game menu background + accent; MainMenu01/MainMenuItem01 read data with defaults (scene default texture removed)
- [x] 6.3 TerrainCatalog fallback scene from `GameDefinition.fallback_terrain_scene`
- [x] 6.4 Delete `scenes/ui/MainMenu01_old.tscn`
- [ ] 6.5 Resource crystal visuals to art data — deferred to #420 (needs an art schema decision)
- [ ] 6.6 Terrain slope families from catalog data — moved out of this change to #418

## 7. Cleanup

- [x] 7.1 Rename `tib_*` identifiers to `res_*` in ResourceGrowthSystem
- [x] 7.2 Comments updated where logic was mislabeled TS-specific; TS provenance kept where useful
- [x] 7.3 Dedupe Minimap land-type literals against TerrainSystem (script constants)

## 8. Follow-up issues

- [x] 8.1 Filed #418–#428 under #374 (mechanics: mind control, cloning, tech buildings,
  prism/tesla chaining, ion storm, visceroids, meteorites)
- [x] 8.2 Filed #419 for map-format constants extraction

## 9. Verification

- [x] 9.1 `redot --headless -s test/run_tests.gd` green (9030 passed, 0 failed)
- [x] 9.2 `gdlint` + `gdformat --check` clean; tab check after format
- [ ] 9.3 In-editor smoke of Sidebar/MainMenu scene changes (headless only here)
