# Project Planning / Roadmap - RTS Edition

## Overview
This document outlines the project planning and roadmap for the Redotian Sun Tiberian Sun remake using the Redot Engine, specifically tailored for real-time strategy game mechanics.

## Current Status
- **Engine Version**: Redot 26.1 LTS
- **Project State**: Development in progress - Core Systems phase
- **Last Updated**: 2026-02-26

---

## Phase 1: Core RTS Systems (Priority: Critical)

### 1.1 Camera & Selection System
- [ ] Implement RTS-style camera controls (pan, zoom, rotate)
- [ ] Create box selection and multi-select functionality
- [ ] Build unit highlighting UI system
- [ ] Add smart camera positioning on events
- [ ] Test with basic unit movement

### 1.2 Base Building System
- [ ] Implement building placement validation rules
- [ ] Create construction queue with timing/resources
- [ ] Build power grid management system
- [ ] Add building states and destruction logic
- [ ] Integrate with economy for costs

### 1.3 Economy & Resources
- [ ] Define resource types (Credits, Tiberium)
- [ ] Implement credit generation from structures
- [ ] Create Tiberium harvesting mechanics
- [ ] Build production cost system
- [ ] Add income/expense cycle tracking

### 1.4 Unit Production Pipeline
- [ ] Create factory/barracks structure types
- [ ] Implement unit training queues
- [ ] Build tech tree and prerequisite system
- [ ] Add spawn logic for new units
- [ ] Test with various faction units

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
- [ ] Define damage types (bullet, explosive, energy)
- [ ] Create armor types and resistance calculations
- [ ] Build weapon system with stats (range, fire rate, damage)
- [ ] Implement projectile or hitscan systems
- [ ] Add unit health/regeneration mechanics

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
- [ ] Create selection panel for selected units
- [ ] Build production queue display
- [ ] Implement resource HUD (credits, Tiberium)
- [ ] Add minimap with unit markers
- [ ] Create build menu interface

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

### 7.2 Unit Roster
- [ ] Implement infantry units (marines, engineers)
- [ ] Create vehicle units (tanks, APCs)
- [ ] Build aircraft units if applicable
- [ ] Add hero/special units with unique abilities
- [ ] Test all unit interactions and counters

---

## Phase 8: Advanced Features (Priority: Low)

### 8.1 Multiplayer Support
- [ ] Design network architecture for multiplayer
- [ ] Implement sync system for game state
- [ ] Add lobby/matchmaking features
- [ ] Create replay system for recorded games
- [ ] Test multiplayer stability and latency handling

### 8.2 Modding Support
- [ ] Create modding framework (custom units, maps)
- [ ] Build asset import/export tools
- [ ] Add script extensibility points
- [ ] Design mod distribution pipeline
- [ ] Document modding API for community

---

## Phase 9: Testing & Polish (Priority: High - Ongoing)

### 9.1 Quality Assurance
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

1. Focus on Phase 1 tasks first (Camera, Selection, Base Building)
2. Create detailed issue tickets in repository for each checklist item
3. Set up GitHub Projects board to track progress
4. Begin implementation with Camera and Selection systems
5. Conduct early playtesting to validate design decisions
6. Review weekly and adjust timeline based on actual development velocity

---

*Last updated: 2026-02-26 by Core Systems Lead*
