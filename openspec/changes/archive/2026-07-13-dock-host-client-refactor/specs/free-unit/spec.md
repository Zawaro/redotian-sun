## MODIFIED Requirements

### Requirement: FreeUnitComponent spawns free unit on placement
FreeUnitComponent SHALL spawn a free unit entity adjacent to its parent when the parent enters the scene tree, then remove itself. FreeUnitComponent SHALL call `_find_nearest_resource()` on the spawned harvester's HarvestComponent.

#### Scenario: Spawn on real placement
- **WHEN** a building with FreeUnitComponent and `free_unit_id = "HARV"` is placed into the scene (not a preview ghost)
- **THEN** a "HARV" entity is created in an adjacent free cell, and the component queues itself for removal

#### Scenario: Spawned harvester auto-harvests
- **WHEN** a free harvester is spawned by FreeUnitComponent
- **THEN** it automatically finds the nearest resource node via `HarvestComponent._find_nearest_resource()` and begins harvesting

#### Scenario: Skip on ghost preview
- **WHEN** the parent entity has `_preview` meta set to `true`
- **THEN** FreeUnitComponent does NOT spawn a free unit

#### Scenario: Skip in editor
- **WHEN** `Engine.is_editor_hint()` is true
- **THEN** FreeUnitComponent does NOT spawn a free unit
