## ADDED Requirements

### Requirement: TiberiumTreeComponent
The system SHALL provide a `TiberiumTreeComponent.gd` (.gd only) for persistent tiberium spawner entities. See `tiberium-tree` spec for full requirements.

#### Scenario: Tree spawns crystals
- **WHEN** a TiberiumTreeComponent is configured with `spawned_entity_id = "TIB"`, `radius_cells = 8`
- **THEN** it spawns crystal entities within the radius

### Requirement: TiberiumComponent
The system SHALL provide a `TiberiumComponent.gd` (.gd only) for harvestable tiberium crystal entities with pseudo-foundation. See `tiberium-harvesting` spec for full requirements.

#### Scenario: Crystal with 3 visual stages
- **WHEN** a TiberiumComponent is configured with `amount = 500`, `max_amount = 500`
- **THEN** visual stage is determined by `amount / max_amount` ratio

### Requirement: HarvestComponent
The system SHALL provide a `HarvestComponent.gd` (.gd only) for harvester behavior. See `tiberium-harvesting` spec for full requirements.

#### Scenario: Harvester auto-seeks crystal
- **WHEN** a HarvestComponent is idle with empty cargo
- **THEN** it seeks the nearest Tiberium crystal with available amount

### Requirement: DockComponent
The system SHALL provide a `DockComponent.gd` (.gd only) for buildings with docking capability. See `tiberium-harvesting` spec for full requirements.

#### Scenario: Refinery dock with queue
- **WHEN** a DockComponent is configured with `unload_rate = 28.0`, `allowed_entities = ["HARV"]`
- **THEN** it accepts one harvester at a time and queues additional ones
