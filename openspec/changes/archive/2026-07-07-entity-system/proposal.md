## Why

The project currently has a minimal entity system: a `BuildingType.gd` resource with 9 fields, hardcoded component scenes, and no data-driven approach for units or infantry. To build a full RTS with 40+ entity types (infantry, vehicles, buildings, terrain), we need a composition-based entity system that:

1. Defines all entity data in `.tres` resources derived from Tiberian Sun's `rules.ini` and `art.ini`
2. Uses a single base entity scene with dynamically added components
3. Supports unlimited weapons, armor types, and active animations per entity
4. Provides load-time validation with error logging
5. Enables mod/DLC support via layered data sets

Without this, every new entity requires hand-building a `.tscn` scene with hardcoded components — unscalable for an RTS with 40+ unit types.

## What Changes

- **New `EntityData.gd` resource class** with ALL entity properties (single class, no per-type subclasses)
- **New `WeaponData.gd` resource** for unlimited weapons per entity
- **New `ArtData.gd` resource** for visual properties (separate from gameplay data)
- **New `GlobalRules.gd` resource** with default game values from rules.ini
- **New `EntityFactory.gd` autoload** that creates entities from data + dynamically adds components
- **Single `Entity.tscn` base scene** (empty Node3D root) — components added at runtime
- **7 new components**: StatsComponent, FoundationComponent, PowerComponent, RadarComponent, FactoryComponent, TransportComponent, SpecialAbilityComponent
- **2 updated components**: CombatComponent (unlimited weapons), MovementController (locomotor/movement_zone)
- **ArtComponent** (.tscn) for animation support
- **Data files**: `resources/entities/`, `resources/art/`, `resources/weapons/`, `resources/warheads/`
- **Reference files**: `references/` folder (gitignored) for rules.ini and art.ini
- **External assets**: `external_assets/` folder (gitignored) for copyrighted Westwood/EA content
- **BREAKING**: `BuildingType.gd` and `resources/buildings/*.tres` are superseded — BuildingManager updated to use EntityFactory

## Capabilities

### New Capabilities
- `entity-data`: EntityData resource class, WeaponData, ArtData, ActiveAnimData — the data layer for all entities
- `entity-factory`: EntityFactory autoload that creates entities from data and adds components dynamically
- `entity-components`: New components (Stats, Foundation, Power, Radar, Factory, Transport, SpecialAbility, Art) and updates to existing ones (Combat, MovementController)
- `global-rules`: GlobalRules resource with default game values, armor type database, warhead definitions
- `entity-validation`: Load-time validation on EntityData and component-level validation with error logging

### Modified Capabilities
<!-- No existing specs to modify -->

## Impact

- **Scenes modified**: `scenes/entities/Entity.tscn` (new), `scenes/components/CombatComponent.tscn` (new), `scenes/components/ArtComponent.tscn` (new), `scenes/entities/dev/NodBuggyDev.tscn` (kept as test entity)
- **Scripts modified**: `scripts/buildings/BuildingManager.gd` (updated to use EntityFactory), `scripts/components/MovementController.gd` (extended with locomotor/movement_zone exports)
- **Scripts removed**: `scripts/buildings/BuildingType.gd` (superseded by EntityData)
- **Resources removed**: `resources/buildings/*.tres` (replaced by `resources/entities/structures/*.tres`)
- **New autoloads**: `EntityFactory` registered in `project.godot`
- **New folders**: `scripts/data/`, `resources/entities/`, `resources/art/`, `resources/weapons/`, `resources/warheads/`, `references/`, `external_assets/`
- **No external dependencies** added — pure GDScript + Redot Engine
