# Project Planning / Roadmap - RTS Edition

## Overview
This document outlines the project planning and roadmap for the Redotian Sun Tiberian Sun remake using the Redot Engine, specifically tailored for real-time strategy game mechanics.

## Current Status
- **Engine Version**: Redot 26.1 LTS
- **Project State**: Development in progress - Core Systems phase
- **Last Updated**: 2026-07-07

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
- [x] Implement RTS-style camera controls (pan, zoom, rotate)
- [x] Create box selection and multi-select functionality
- [ ] Build unit highlighting UI system
- [ ] Add smart camera positioning on events
- [ ] Test with basic unit movement

### 1.2 Base Building System
- [x] Implement building placement validation rules
- [x] Create construction queue with timing/resources
- [ ] Build power grid management system (PowerComponent)
- [ ] Add building states and destruction logic
- [ ] Integrate with economy for costs
- **Note**: Uses EntityFactory + EntityData for building definitions

### 1.3 Economy & Resources
- [ ] Define resource types (Credits, Tiberium)
- [ ] Implement credit generation from structures
- [ ] Create Tiberium harvesting mechanics
- [ ] Build production cost system
- [ ] Add income/expense cycle tracking

### 1.4 Unit Production Pipeline
- [x] Create factory/barracks structure types (FactoryComponent)
- [x] Implement entity data population (populate-entity-data change)
- [x] Implement tabbed build menu sidebar (GitHub Issue #66)
- [x] Implement production queue system (ProductionManager)
- [x] Build prerequisite system (PrerequisiteSystem)
- [x] Add spawn logic for new units via EntityFactory
- [ ] Test with various faction units
- **Note**: Units defined as EntityData .tres files

---

## Phase 2: Movement & Pathfinding (Priority: High)

### 2.1 Navigation System
- [ ] Choose pathfinding approach (A*, navmesh, grid-based)
- [ ] Build navmesh/grid generation from terrain
- [ ] Implement dynamic obstacle avoidance
- [ ] Add terrain cost modifiers
- [ ] Create path smoothing for units

### 2.2 Unit Movement & Commands
- [ ] Implement move command with path following
- [ ] Create attack-move command system
- [ ] Build patrol and gather commands
- [ ] Add formation system (line, column, spread)
- [ ] Test unit pathing in various terrains

---

## Phase 3: Combat System (Priority: High)

### 3.1 Damage & Weapons
- [ ] Define damage types via WarheadData resources
- [ ] Create armor types via GlobalRules.armor_types (customizable dictionary)
- [ ] Build WeaponData resource system (unlimited weapons per entity)
- [ ] Implement projectile or hitscan systems via CombatComponent
- [ ] Add unit health/regeneration mechanics (HealthComponent)
- **Note**: Weapons defined in resources/weapons/ .tres files

### 3.2 Combat AI
- [ ] Create target selection logic for units
- [ ] Implement combat states (idle, chase, attack, flee)
- [ ] Build engagement radius and retreat rules
- [ ] Add morale/stamina systems if applicable
- [ ] Test combat scenarios against various enemies

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
- [ ] Implement cursor system with per-unit resolution (GitHub Issue #70)
- [ ] Implement resource HUD (credits, Tiberium)
- [ ] Add minimap with unit markers
- [ ] Create selection panel for selected units

### 5.2 Game Management
- [ ] Implement pause/resume functionality
- [ ] Add save/load system for game state
- [ ] Create settings/configuration screens
- [ ] Build main menu and faction selection
- [ ] Add tutorial or training mode

---

## Phase 6: World & Environment (Priority: Low)

### 6.1 Terrain Systems
- [ ] Create terrain types with movement modifiers
- [ ] Implement elevation/height system
- [ ] Add Tiberium fields distribution
- [ ] Build environmental hazards if applicable
- [ ] Test terrain interaction with units/buildings
- **Note**: Terrain objects use EntityData with entity_type=TERRAIN

### 6.2 Map Design Tools
- [ ] Create level editor or map import pipeline
- [ ] Implement scenario scripting system
- [ ] Add trigger/event system for missions
- [ ] Build campaign structure for single-player

---

## Phase 7: Factions & Content (Priority: Medium)

### 7.1 Faction Systems
- [ ] Implement GDI faction mechanics
- [ ] Create Nod faction mechanics
- [ ] Build unique unit/structure differences per faction
- [ ] Add faction-specific tech trees
- [ ] Test faction balance in combat scenarios
- **Note**: Faction bonuses stored in GlobalRules.gd

### 7.2 Unit Roster
- [ ] Implement infantry units (EntityData .tres files)
- [ ] Create vehicle units (EntityData .tres files)
- [ ] Build aircraft units if applicable
- [ ] Add hero/special units with unique abilities
- [ ] Test all unit interactions and counters
- **Note**: All units defined in resources/entities/ .tres files

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
- [ ] Set up GUT testing framework (v9.x)
- [ ] Unit testing for all core systems
- [ ] Integration testing across modules
- [ ] Playtesting sessions with gameplay feedback
- [ ] Bug fixes and refinement cycles
- [ ] Performance optimization profiling

### 9.2 Final Polish
- [ ] Visual effects (explosions, damage, construction)
- [ ] Animation quality and transitions
- [ ] Sound design and music integration
- [ ] UI/UX polish and accessibility features
- [ ] Documentation for players and modders

---

## Resources & Dependencies

- **Engine**: Redot Engine 26.1 LTS
- **Programming Language**: GDScript (primary), C# (optional)
- **Documentation**: [Redot Engine Docs](https://docs.redotengine.org/en/stable/)
- **Version Control**: Git with GitHub Issues for task tracking
- **Build System**: Godot 4.x workflow

---

## Next Steps

1. **Per-Player Data & Logic** (Issue #77) — PlayerManager autoload, PlayerData, ProductionState, Faction, MapConfig resources. Refactor EconomyManager/BuildingManager/ProductionManager/Sidebar.
2. **Data Population** (Issue #23) — populate remaining .tres files for entities, weapons, warheads
3. **Component Logic** (Issues #28-40) — implement actual behavior for each component
   - **Highest priority**: HitboxComponent (#29), HealthComponent (#30), CombatComponent (#28) — core combat loop (requires #77 for owner tracking + team-based targeting)
   - **Economy**: PowerComponent (#33), FactoryComponent (#31), TransportComponent (#32) — production and harvesting (requires #77 for per-player production queues)
4. **GlobalRules Integration** (Issue #26) — wire armor calculation, veterancy, movement coefficients
5. **BuildingManager Migration** (Issue #25) — move from BuildingType to EntityFactory
6. **Debug Menu** (Issue #27) — in-game debug tools for testing
7. Conduct early playtesting to validate design decisions
8. Review weekly and adjust timeline based on actual development velocity

---

*Last updated: 2026-07-18 — Per-player infrastructure (#77) added as prerequisite for component logic*
