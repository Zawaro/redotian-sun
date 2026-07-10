## Why

Tiberian Sun's entire economy is the harvest loop — no passive income exists. Currently the codebase has harvester entity data and a TransportComponent shell, but zero runtime economy logic. Without credit tracking and Tiberium harvesting, there's no gameplay loop: players can't afford units, harvesters have nothing to do, and refineries are decorative. This change implements the full economy backbone so the game becomes playable beyond unit placement.

## What Changes

- Add `EconomyManager` autoload singleton for player credit tracking
- Add `PlayerData` resource for per-player treasury
- Add `TiberiumTreeComponent` for persistent tiberium spawner (indestructible, unselectable, true 1x1 foundation)
- Add `TiberiumComponent` for Tiberium crystal entities (depletable, per-cell, pseudo-foundation)
- Add `HarvestComponent` for harvester behavior (find crystal → fill → find refinery → dock → dump)
- Add `DockComponent` for refinery docking (position, queue, unload rate, allowed entities)
- Add `bib_cells` field to `FoundationComponent` for harvester-accessible building pads
- Add economy-related fields to `EntityData` (tiberium tree, tiberium crystal, bib, dock fields)
- Add economy constants to `GlobalRules` (`starting_credits`, `tiberium_value`, `harvester_fill_rate`)
- Wire stub deduction into `BuildingManager.place_building()` (placeholder until build queue issue)
- Wire `BuildingManager.can_place()` to check for TiberiumComponent (pseudo-foundation blocks buildings)
- Create TiberiumTree entity data + scene, crystal entity data + scene + model for map placement

## Capabilities

### New Capabilities
- `economy-core`: PlayerData resource, EconomyManager autoload for add/deduct/can_afford, credit tracking signals
- `tiberium-tree`: TiberiumTreeComponent for persistent spawner (terrains 1x1 true foundation, indestructible)
- `tiberium-harvesting`: TiberiumComponent, HarvestComponent, DockComponent, bib cells for harvester pathing
- `credit-ui`: Credit balance label above build menu, wired to EconomyManager.credits_changed signal

### Modified Capabilities
- `entity-components`: Add TiberiumTreeComponent, TiberiumComponent, HarvestComponent, DockComponent to component list
- `entity-data`: Add tiberium tree fields, tiberium crystal fields, bib_cells, dock_position, dock_rotation
- `global-rules`: Add `starting_credits`, `tiberium_value`, `harvester_fill_rate` constants

## Impact

- `scripts/components/`: New `TiberiumTreeComponent.gd`, `TiberiumComponent.gd`, `HarvestComponent.gd`, `DockComponent.gd`; modified `FoundationComponent.gd`
- `scripts/data/`: New `PlayerData.gd` resource; `GlobalRules.gd` field additions; `EntityData.gd` field additions
- `scripts/core/`: New `EconomyManager.gd` autoload
- `scripts/entities/EntityFactory.gd`: Wire new components in `_add_components()`
- `scripts/buildings/BuildingManager.gd`: Stub deduction + pseudo-foundation check in `can_place()`
- `scripts/core/SpatialHash.gd`: Bib cell soft-blocking support
- `scripts/ui/BuildMenu.gd`: Credit label connected to EconomyManager
- `scenes/ui/BuildMenu.tscn`: Label above grid
- `resources/`: New entity data .tres for TiberiumTree and Tiberium crystal; updated `global_rules.tres`
- `scenes/entities/terrain/`: New TiberiumTree and crystal scenes
- `assets/models/`: New Tiberium crystal cube-cluster model
- `project.godot`: Register `EconomyManager` autoload
