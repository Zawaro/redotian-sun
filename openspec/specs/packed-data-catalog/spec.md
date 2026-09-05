# packed-data-catalog Specification

## Purpose

Data catalogs must populate identically in exported `.pck` builds and the editor. The shared `register_data_set()` directory scan used by `EntityFactory`, `TerrainCatalog`, and `AudioManager` must enumerate and load every `.tres` under a registered `res://` directory even when the resources live inside a packed file — including pack-style entries that carry a `.remap` suffix.

## Requirements

### Requirement: Data catalog registration in packed builds
The system SHALL populate its data catalogs from `.tres` data the same way in an exported `.pck` build as in the editor. The shared `register_data_set(path)` directory scan (used by `EntityFactory`, `TerrainCatalog`, and `AudioManager`) SHALL enumerate and `load()` every `.tres` under a registered `res://` directory even when the resources live inside a packed file.

#### Scenario: Entity catalog populated in packed build
- **WHEN** a map is loaded in an exported build (`res://scenes/maps/TestMap02.tscn` run from a `.pck`)
- **THEN** `EntityFactory.create_entity("GDI_LIGHT_INFANTRY")`, `NOD_LIGHT_INFANTRY`, `GDI_REFINERY`, `GDI_POWER_PLANT`, `GDI_BARRACKS`, `GDI_HARVESTER`, `NOD_MCV`, `GDI_CONSTRUCTION_YARD`, `TIBERIUM_RIPARIUS`, and `TIBERIUM_TREE` all resolve, and NO `EntityFactory: Unknown entity id:` warning is printed

#### Scenario: Terrain art catalog populated in packed build
- **WHEN** terrain is rendered from an exported build
- **THEN** every cell resolves an art family via `TerrainCatalog`, and NO `TerrainRenderer: no art for family ''` warning is printed

#### Scenario: Parity with editor
- **WHEN** the same map is loaded from the project tree (editor/`--headless --import`)
- **THEN** the identical set of entity ids and terrain families resolve

### Requirement: Packed catalog load does not depend on editor caches
The packed-build catalog scan SHALL work without `.godot/` editor caches, an editor-generated `.import` manifest, the editor filesystem, or `uid_cache.bin` being present at runtime. The failure SHALL be root-caused and fixed rather than papered over (no hardcoded entity id lists, no `.godot` dependency).

#### Scenario: Scan iterates pack directory
- **WHEN** `DirAccess.open("res://games/ts/entities/")` is called in an exported build
- **THEN** it SHALL enumerate the `.tres` files packed under that directory and each one SHALL `load()` successfully as an `EntityData`
- **THEN** the catalog contains every packed entity id

#### Scenario: Pack directory entries carry a remap suffix
- **WHEN** an exported build enumerates a data directory whose pack stores resources as `<name>.<ext>.remap` entries (Redot/Godot pack behavior)
- **THEN** the catalog scan SHALL still recognize and load the underlying resource, stripping the `.remap` suffix from the enumerated name before the extension check and load
- **THEN** no entry matching a packed `.tres` remains unloaded because its enumerated name ended in `.remap`