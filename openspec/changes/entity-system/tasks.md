## 1. Setup & Infrastructure

- [x] 1.1 Add `references/` and `external_assets/` to .gitignore
- [x] 1.2 Download rules.ini and art.ini to references/ folder
- [x] 1.3 Create `scripts/data/` directory structure
- [x] 1.4 Create `resources/entities/`, `resources/art/`, `resources/weapons/`, `resources/warheads/` directories

## 2. Data Layer — EntityData

- [x] 2.1 Create `scripts/data/EntityData.gd` with all entity properties (id, display_name, entity_type, strength, armor, cost, tech_level, sight, owner, points, weapons, speed, movement_zone, locomotor, foundation, height, power, powered, radar, factory, free_unit, passengers, dock, harvester, storage, pip_scale, special ability flags, prerequisite, art_data)
- [x] 2.2 Create `scripts/data/WeaponData.gd` with weapon properties (id, damage, rate_of_fire, range, warhead, projectile, fire_flh, barrel_length, anti_air, anti_ground, splash_radius, ammo)
- [x] 2.3 Create `scripts/data/WarheadData.gd` with warhead properties (id, damage_modifier, cell_spread, death_anim)
- [x] 2.4 Create `scripts/data/ArtData.gd` with visual properties (id, is_voxel, is_remapable, foundation, height, turret_offset, barrel_length, primary_fire_flh, secondary_fire_flh, model_path, cameo_path, buildup_scene, active_anims, new_theater, flat, extra_damage_stage, terrain_palette, demand_load)
- [x] 2.5 Create `scripts/data/ActiveAnimData.gd` with animation properties (anim_name, damaged_anim, offset_x, offset_y, z_adjust, y_sort, requires_power, powered_light, loop)
- [x] 2.6 Create `scripts/data/GlobalRules.gd` with default game values (veteran_ratio, build_speed, refund_percent, repair_rate, armor_types dictionary, veterancy multipliers, movement coefficients, production constants)
- [x] 2.7 Create `scripts/data/MapOverride.gd` stub (TODO: map/mission overrides for later phase)
- [x] 2.8 Register EntityData, WeaponData, WarheadData, ArtData, ActiveAnimData, GlobalRules as Redot custom types in project.godot

## 3. Components — New

- [x] 3.1 Create `scripts/components/StatsComponent.gd` (.gd only) — holds id, display_name, entity_type, armor, cost, tech_level, sight, owner, points
- [x] 3.2 Create `scripts/components/FoundationComponent.gd` (.gd only) — holds foundation: Vector2i, height: float
- [x] 3.3 Create `scripts/components/PowerComponent.gd` (.gd only) — holds power: int, powered: bool
- [x] 3.4 Create `scripts/components/RadarComponent.gd` (.gd only) — holds radar: bool
- [x] 3.5 Create `scripts/components/FactoryComponent.gd` (.gd only) — holds factory_type: String, free_unit: String
- [x] 3.6 Create `scripts/components/TransportComponent.gd` (.gd only) — holds passengers, dock, harvester, storage, pip_scale
- [x] 3.7 Create `scripts/components/SpecialAbilityComponent.gd` (.gd only) — holds cloakeable, self_healing, c4, engineer, disguise, agent, thief, tiberium_proof, immune_to_veins, capturable
- [x] 3.8 Create `scripts/components/ArtComponent.gd` + `scenes/components/ArtComponent.tscn` — links to ArtData, manages AnimationPlayer/3D child

## 4. Components — Updated

- [x] 4.1 Update `scripts/components/CombatComponent.gd` — support unlimited weapons via `weapons: Array[WeaponData]`, turret support, validate weapons on configure
- [x] 4.2 Create `scenes/components/CombatComponent.tscn` — root Node3D with script, optional turret mesh child
- [x] 4.3 Update `scripts/components/MovementController.gd` — add `locomotor: String` and `movement_zone: String` exports, preserve existing movement behavior

## 5. Entity Factory

- [x] 5.1 Create `scenes/entities/Entity.tscn` — empty Node3D root (single base scene)
- [x] 5.2 Create `scripts/entities/EntityFactory.gd` autoload — data cache, create_entity(), component addition logic, component wiring, validation logging
- [x] 5.3 Register EntityFactory as autoload in project.godot
- [x] 5.4 Implement component addition rules (property → component mapping per design doc)
- [x] 5.5 Implement component wiring (HitboxComponent.health_component, SelectComponent.health_component NodePath references)
- [x] 5.6 Implement mod/DLC data set registration (register_data_set(), layered overrides)
- [x] 5.7 Implement override support (optional overrides: Dictionary parameter on create_entity)

## 6. Validation

- [x] 6.1 Add validate() method to EntityData.gd — check id, strength, cost, owner, return PackedStringArray of errors
- [x] 6.2 Add validate() method to WeaponData.gd — check id, damage, range
- [ ] 6.3 Add component-level validation to each new component (StatsComponent, FoundationComponent, etc.)
- [ ] 6.4 Implement TODO logging for unimplemented properties in components
- [ ] 6.5 Add graceful degradation in EntityFactory — skip invalid components, log warnings, don't crash

## 7. Data Population — Global Rules

- [x] 7.1 Create `resources/global_rules.tres` from rules.ini [General] section — veteran factors, repair rates, build speed, etc.
- [x] 7.2 Populate armor_types dictionary in GlobalRules (none, wood, light, heavy, concrete)
- [ ] 7.3 Create warhead .tres files from rules.ini [Warheads] section (HE, AP, Fire, Sonic, etc.)

## 8. Data Population — Weapons

- [ ] 8.1 Create weapon .tres files for infantry weapons (Minigun, Grenade, M1Carbine, etc.)
- [ ] 8.2 Create weapon .tres files for vehicle weapons (RaiderCannon, 120mm, MammothTusk, etc.)
- [ ] 8.3 Create weapon .tres files for building weapons (LaserFire, SAM, Vulcan, etc.)

## 9. Data Population — Entities

- [x] 9.1 Create EntityData .tres for GDI infantry (E1, E2, E3, MEDIC, ENGINEER)
- [ ] 9.2 Create EntityData .tres for Nod infantry (E1, CYBORG, UMAGON, GHOST)
- [x] 9.3 Create EntityData .tres for GDI vehicles (MCV, HARV, APC, 4TNK, SONIC)
- [x] 9.4 Create EntityData .tres for Nod vehicles (BGGY, BIKE, HARV, CAR, TTNK)
- [x] 9.5 Create EntityData .tres for GDI structures (GACNST, GAPOWR, GAPILE, GARADR, GAWEAP, GAHPAD, GADEPT, GATECH, GACTWR, GAFIRE)
- [x] 9.6 Create EntityData .tres for Nod structures (NACNST, NAPOWR, NAAPWR, NAHAND, NARADR, NAWEAP, NAHPAD, NATECH, NAOBEL, NAMISL, NASTLH)
- [x] 9.7 Create EntityData .tres for terrain objects (TREE01-TREE25, SROCK01-SROCK05, TIBTRE01-TIBTRE03)

## 10. Data Population — Art

- [ ] 10.1 Create ArtData .tres for GDI infantry (E1, E2, E3, MEDIC, ENGINEER)
- [ ] 10.2 Create ArtData .tres for Nod infantry (E1, CYBORG, UMAGON, GHOST)
- [ ] 10.3 Create ArtData .tres for GDI vehicles (MCV, HARV, APC, 4TNK, SONIC)
- [ ] 10.4 Create ArtData .tres for Nod vehicles (BGGY, BIKE, HARV, CAR, TTNK)
- [ ] 10.5 Create ArtData .tres for GDI structures (GACNST, GAPOWR, GAPILE, GARADR, GAWEAP, etc.)
- [ ] 10.6 Create ArtData .tres for Nod structures (NACNST, NAPOWR, NAAPWR, NAHAND, etc.)
- [ ] 10.7 Create ArtData .tres for terrain objects (TREE01-TREE25, SROCK01-SROCK05)

## 11. Integration

- [ ] 11.1 Update `scripts/buildings/BuildingManager.gd` to use EntityFactory (dual-path: old BuildingType + new EntityData)
- [x] 11.2 Create `scenes/entities/dev/NodBuggyDev.tscn` — keep existing hand-built scene as test entity
- [ ] 11.3 Test entity spawning in gameplay scene — verify EntityFactory creates entities correctly
- [ ] 11.4 Test component wiring — verify HitboxComponent and SelectComponent receive HealthComponent reference
- [ ] 11.5 Test validation — verify errors are logged for invalid data, entities still spawn gracefully

## 12. Cleanup

- [ ] 12.1 Remove `scripts/buildings/BuildingType.gd` (superseded by EntityData)
- [ ] 12.2 Remove `resources/buildings/*.tres` (replaced by resources/entities/structures/*.tres)
- [ ] 12.3 Update BuildingManager to fully use EntityFactory (remove old BuildingType path)
- [x] 12.4 Run gdlint and gdformat on all new scripts
- [ ] 12.5 Run existing tests to verify no regressions
