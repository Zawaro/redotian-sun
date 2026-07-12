## ADDED Requirements

### Requirement: FreeUnitComponent spawns free unit on placement
FreeUnitComponent SHALL spawn a free unit entity adjacent to its parent when the parent enters the scene tree, then remove itself.

#### Scenario: Spawn on real placement
- **WHEN** a building with FreeUnitComponent and `free_unit_id = "HARV"` is placed into the scene (not a preview ghost)
- **THEN** a "HARV" entity is created in an adjacent free cell, and the component queues itself for removal

#### Scenario: Skip on ghost preview
- **WHEN** the parent entity has `_preview` meta set to `true`
- **THEN** FreeUnitComponent does NOT spawn a free unit

#### Scenario: Skip in editor
- **WHEN** `Engine.is_editor_hint()` is true
- **THEN** FreeUnitComponent does NOT spawn a free unit

### Requirement: Adjacent free cell search
FreeUnitComponent SHALL find an unoccupied cell adjacent to the parent's foundation.

#### Scenario: Orthogonal first
- **WHEN** searching for an adjacent cell
- **THEN** orthogonal cells (N, S, E, W) outside the foundation are checked first

#### Scenario: Diagonal fallback
- **WHEN** no orthogonal cell is free
- **THEN** diagonal cells outside the foundation are checked

#### Scenario: Search radius
- **WHEN** no cell is free within the search radius (~5 cells)
- **THEN** the component silently gives up and removes itself (no entity spawned)

### Requirement: Refinery spawns harvester
The gdi_refinery EntityData SHALL have `factory = "HarvesterType"` and `free_unit = "HARV"`.

#### Scenario: Refinery placement
- **WHEN** a GDI Refinery is placed on the map
- **THEN** a harvester entity ("HARV") is spawned in an adjacent free cell

#### Scenario: Spawned harvester auto-harvests
- **WHEN** a free harvester is spawned by FreeUnitComponent
- **THEN** it automatically finds the nearest Tiberium pod and begins harvesting
