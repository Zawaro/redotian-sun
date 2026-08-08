# Project Planning / Roadmap - RTS Edition

## Overview
This document outlines the project planning and roadmap for the Redotian Sun Tiberian Sun remake using the Redot Engine, specifically tailored for real-time strategy game mechanics.

## Current Status
- **Engine Version**: Redot 26.2 LTS
- **Project State**: Core Systems complete — mission layer (GDI Mission 01) is next
- **Last Updated**: 2026-08-08
- **Live status**: See `00-0_project_status.md` for a verified system-by-system breakdown

---

## Entity System Foundation (GitHub Issue #22)

**Status**: ✅ Implemented (architecture + core components)

The composition-based entity system is a prerequisite for most game systems. All entities (buildings, units, infantry, terrain) are created from a single `EntityData.gd` resource with dynamically added components.

**Implemented:**
- `EntityData.gd` — single resource class with ALL entity properties
- `EntityFactory.gd` — autoload that creates entities from data, adds components dynamically
- `Entity.tscn` — single base scene (empty Node3D root)
- `WeaponData.gd` — unlimited weapons per entity via `Array[WeaponData]`
- `ArtData.gd` — separate visual properties per entity, model loading via ArtComponent
- `GlobalRules.gd` — default game values from rules.ini, customizable armor types
- 7 new components: StatsComponent, FoundationComponent, PowerComponent, RadarComponent, FactoryComponent, TransportComponent, SpecialAbilityComponent
- Updated components: CombatComponent (unlimited weapons), MovementController (locomotor/movement_zone)
- ArtComponent loads models from ArtData at runtime

**Remaining work** (see GitHub Issues #23-40):
- Data population: ~30 .tres files for entities, weapons, warheads, art
- Component logic: Each component needs actual behavior (see component-specific issues)
- Integration: BuildingManager migration, GlobalRules wiring
- Validation: Component-level validation, graceful degradation

**See**: GitHub Issue #22 for full architecture details

---

## Phase 1: Core RTS Systems (Priority: Critical)

### 1.1 Camera & Selection System
- [x] Implement RTS-style camera controls (pan, zoom, edge-scroll; rotate is NOT implemented)
- [x] Create box selection and multi-select functionality
- [x] Build selection overlay UI system (brackets, health bars, pips)
- [ ] Add smart camera positioning on events
- [x] Test with basic unit movement

### 1.2 Base Building System
- [x] Implement building placement validation rules
- [x] Create construction queue with timing/resources (ProductionManager queue)
- [ ] Build power grid management system (PowerComponent — Issue #33)
- [x] Add building states and destruction logic (sell, repair, destroy cleanup)
- [x] Integrate with economy for costs
- **Note**: Uses EntityFactory + EntityData for building definitions

### 1.3 Economy & Resources
- [x] Define resource types (Credits, Tiberium — ResourceType hierarchy)
- [x] Implement credit generation from structures (harvest → dock → unload → credits)
- [x] Create Tiberium harvesting mechanics
- [x] Build production cost system
- [ ] Add income/expense cycle tracking

### 1.4 Unit Production Pipeline
- [x] Create factory/barracks structure types (FactoryComponent)
- [x] Implement entity data population (populate-entity-data change)
- [x] Implement tabbed build menu sidebar (GitHub Issue #66)
- [x] Implement production queue system (ProductionManager)
- [x] Build prerequisite system (PrerequisiteSystem)
- [x] Add spawn logic for new units via EntityFactory
- [x] Test with various faction units
- **Note**: Units defined as EntityData .tres files

---

## Phase 2: Movement & Pathfinding (Priority: High)

### 2.1 Navigation System
- [x] Choose pathfinding approach (A* — custom grid, NOT NavigationServer3D)
- [x] Build grid from terrain (Pathfinder.gd, A* with binary-heap + terrain costs)
- [x] Implement dynamic obstacle avoidance (radial repulsion steering)
- [x] Add terrain cost modifiers (per-locomotor terrain_speeds, slope, bib penalty)
- [x] Create path smoothing for units (Catmull-Rom splines, LOS string-pulling)

### 2.2 Unit Movement & Commands
- [x] Implement move command with path following
- [x] Create attack command system (left-click enemy → chase → fire)
- [ ] Build patrol and gather commands (gather exists via HarvestComponent; patrol missing)
- [ ] Add formation system (line, column, spread — static offsets only, no FormationComponent)
- [x] Test unit pathing in various terrains

---

## Phase 3: Combat System (Priority: High)

### 3.1 Damage & Weapons
- [x] Define damage types via WarheadData resources (27 .tres)
- [x] Create armor types via GlobalRules.armor_types (5 ArmorType .tres)
- [x] Build WeaponData resource system (44 .tres, unlimited weapons per entity)
- [x] Implement projectile or hitscan systems via CombatComponent (hitscan MVP; runtime projectiles = Issue #78 pending)
- [ ] Add unit health/regeneration mechanics (HealthComponent exists; regen not implemented)
- **Note**: Weapons defined in resources/weapons/ .tres files

### 3.2 Combat AI
- [ ] Create target selection logic for units
- [ ] Implement combat states (idle, chase, attack, flee)
- [ ] Build engagement radius and retreat rules
- [ ] Add morale/stamina systems if applicable
- [ ] Test combat scenarios against various enemies
- **Note**: Entirely greenfield — units only fight when player-ordered

---

## Phase 4: Fog of War & Vision (Priority: Medium)

### 4.1 Vision System
- [ ] Design fog of war layers (explored, unexplored, hidden)
- [ ] Implement vision radius per unit/structure
- [ ] Build line-of-sight calculations against terrain/buildings
- [ ] Add dynamic fog updates on movement/death events
- [ ] Create minimap integration

### 4.2 Map Exploration
- [ ] Track explored map percentage for win conditions
- [ ] Implement vision sharing between units/structures
- [ ] Add reveals and blackouts mechanics
- [ ] Test with various unit compositions

---

## Phase 5: UI/UX & Interface (Priority: Medium)

### 5.1 RTS Interface Elements
- [x] Build tabbed sidebar with 4 categories (GitHub Issue #66)
- [x] Implement production queue display with angular progress
- [x] Implement cursor system with per-unit resolution (GitHub Issue #70)
- [x] Implement centralized input routing — InputSettings autoload, camera actions, edge scroll toggle
- [ ] Implement resource HUD (credits done; Tiberium, income, power missing)
- [ ] Add minimap with unit markers (only editor minimap exists)
- [ ] Create selection panel for selected units (health bars exist; stats/actions panel missing)

### 5.2 Game Management
- [ ] Implement pause/resume functionality
- [ ] Add save/load system for game state
- [ ] Create settings/configuration screens
- [ ] Build main menu and faction selection (MainMenu01 visual only — only "Exit" works)
- [ ] Add tutorial or training mode

---

## Phase 6: World & Environment (Priority: Low)

### 6.1 Terrain Systems
- [x] Create terrain types with movement modifiers (LandType .tres + per-locomotor terrain_speeds)
- [x] Implement elevation/height system (TerrainSystem heightfield + cascade)
- [x] Add Tiberium fields distribution (paint tool + ResourceGrowthSystem)
- [ ] Build environmental hazards if applicable (ice works; radiation/toxicity missing)
- [x] Test terrain interaction with units/buildings
- **Note**: Terrain objects use EntityData with entity_type=TERRAIN

### 6.2 Map Design Tools
- [x] Create level editor or map import pipeline (MapEditor + JSON v4)
- [ ] Implement scenario scripting system (entirely missing — needed for missions)
- [ ] Add trigger/event system for missions (entirely missing)
- [ ] Build campaign structure for single-player (entirely missing)

### 6.3 Tiberium Growth
- [x] ResourceGrowthSystem (tree + crystal timers, batching, spread limits)

---

## Phase 7: Factions & Content (Priority: Medium)

### 7.1 Faction Systems
- [x] Implement GDI faction data (.tres)
- [x] Create Nod faction data (.tres)
- [ ] Build unique unit/structure differences per faction (data-level differences exist; no mechanic bonuses)
- [ ] Add faction-specific tech trees (per-faction prerequisite data; no research/upgrades)
- [ ] Test faction balance in combat scenarios
- **Note**: Faction bonuses stored in GlobalRules.gd; no FactionManager/bonus logic yet

### 7.2 Unit Roster
- [x] Implement infantry units (EntityData .tres files — 26)
- [x] Create vehicle units (EntityData .tres files — 38)
- [x] Build aircraft units if applicable (8, no weapons populated)
- [ ] Add hero/special units with unique abilities
- [ ] Test all unit interactions and counters
- **Note**: All units defined in resources/entities/ .tres files (~408 total)

---

## Phase 8: Advanced Features (Priority: Low)

### 8.1 Multiplayer Support
- [ ] Design network architecture for multiplayer
- [ ] Implement sync system for game state
- [ ] Add lobby/matchmaking features
- [ ] Create replay system for recorded games
- [ ] Test multiplayer stability and latency handling

### 8.2 Modding Support
- [ ] Create modding framework via EntityFactory.register_data_set()
- [ ] Build asset import/export tools
- [ ] Add script extensibility points
- [ ] Design mod distribution pipeline
- [ ] Document modding API for community
- **Note**: EntityFactory supports layered data sets for mods/DLCs

---

## Phase 9: Testing & Polish (Priority: High - Ongoing)

### 9.1 Quality Assurance
- [x] Set up custom test runner (GUT rejected — breaks on Redot 26.x class_name registration)
- [x] Unit testing for all core systems (74 files, 777 methods, 4364 asserts)
- [x] Integration testing across modules (7 integration suites)
- [ ] Playtesting sessions with gameplay feedback
- [ ] Bug fixes and refinement cycles
- [ ] Performance optimization profiling (open: #221 SDFGI, #222 shadow grain)

### 9.2 Final Polish
- [ ] Visual effects (explosions, damage, construction — none implemented)
- [ ] Animation quality and transitions
- [ ] Sound design and music integration (AudioManager done; music/EVA/content missing)
- [ ] UI/UX polish and accessibility features
- [ ] Documentation for players and modders

---

## Resources & Dependencies

- **Engine**: Redot Engine 26.2 LTS
- **Programming Language**: GDScript only (no C# bindings)
- **Documentation**: [Redot Engine Docs](https://docs.redotengine.org/en/stable/)
- **Version Control**: Git with GitHub Issues for task tracking
- **Build System**: Redot editor workflow (no external build system)

---

## Next Steps

### Next Milestone: GDI Mission 01 (Reinforce Phoenix Base)
Two-tier milestone (GitHub milestone #1). MVP tier = playable build & destroy loop; completionist tier = `milestone-tier2` labeled. Umbrella: #260. See `00-0_project_status.md` (GDI Mission 01 section) and the issue series #226–258 + #260–268.
- **MVP critical path:** #260 (umbrella), #262 (menu→map), #261 (guard AI), #236 (mission boot), #237 (trigger engine), #240 (objectives/win-lose), #247 (entity placement), #264 (attack-move)
- **MVP map:** #226–#234 (importer, land-type paint, water, cliffs, bridges, buildout, waypoints)
- **MVP defense/polish:** #245 (Component Tower defense), #246 (radar), #255 (music), #258 (EVA)
- **New gap issues added 2026-08-08:** #260 umbrella, #261 guard/auto-engage AI, #262 menu→gameplay, #263 pause, #264 attack-move, #265 Special tab superweapons, #266 credit SFX, #267 aircraft & helipad, #268 CI pin 26.2

### Priority: First Blood Goal (Issue #84)
End-to-end combat demo: deploy MCV → build base → train infantry → destroy enemy Con Yard. See `plans/10-1_first_blood_goal.md` for full breakdown.

1. ~~**Per-Player Data & Logic** (Issue #77)~~ ✅
2. ~~**MapEditor Entity Placement** (Issue #83)~~ ✅
3. ~~**MCV Deploy** (Issue #80)~~ ✅
4. ~~**Weapon Data** (Issue #23)~~ ✅
5. ~~**Prerequisite Chain** (Issue #81)~~ ✅
6. ~~**Attack Command** (Issue #79)~~ ✅
7. ~~**CombatComponent Firing** (Issue #28)~~ ✅ — hitscan MVP, fire rate timer, range check, target tracking, player-move-cancels-attack
8. ~~**Death Handling** (Issue #30/#82)~~ ✅ — death handler now frees node + unregisters cells (voice + cleanup)
9. **Projectile System** (Issue #78) + **ProjectileData Resource** (Issue #89) — future upgrade from hitscan
10. **HitboxComponent** (Issue #29) — future upgrade, needs projectile to trigger it

### Remaining Component Logic (Issues #28-40)
- **Economy**: PowerComponent (#33)
- **Movement**: Locomotor enforcement (#34), Terrain movement costs (#51) — mostly done
- **UI**: Infantry health bars (#39), Art damaged states (#38)

### Infrastructure
- **GlobalRules Integration** (Issue #26) — wire armor, veterancy, movement coefficients
- **BuildingManager Migration** (Issue #25) — move from BuildingType to EntityFactory
- **Debug Menu** (Issue #27) — in-game debug tools for testing
- Conduct early playtesting to validate design decisions
- Review weekly and adjust timeline based on actual development velocity

---

*Last updated: 2026-08-08 — status report added, roadmap synced to codebase (see plans/00-0_project_status.md)*
