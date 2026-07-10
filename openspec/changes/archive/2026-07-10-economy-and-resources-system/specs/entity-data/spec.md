## ADDED Requirements

### Requirement: EntityData TiberiumTree fields
EntityData SHALL include fields for TiberiumTree configuration.

#### Scenario: Create TiberiumTree data
- **WHEN** an EntityData is created with `tiberium_tree = true`, `spawned_entity_id = "TIB"`, `radius_cells = 8`, `node_count = 12`, `amount_per_node = 300`, `max_amount_per_node = 300`
- **THEN** the entity is a tiberium tree spawner with radius 8, 12 nodes of 300 tiberium each

### Requirement: EntityData Tiberium crystal fields
EntityData SHALL include fields for tiberium crystal entities (depletable resource per cell).

#### Scenario: Create tiberium crystal data
- **WHEN** an EntityData is created with `tiberium_resource = true`, `tiberium_amount = 300`, `tiberium_max_amount = 300`, `tiberium_type = 0`, `tiberium_regrowth_rate = -1.0`
- **THEN** the entity is a green tiberium crystal with 300 tiberium, using GlobalRules default regrowth

### Requirement: EntityData bib cells
EntityData SHALL include `bib_cells: PackedVector2i` for defining harvester-accessible cells within a building's foundation.

#### Scenario: Refinery with bib cells
- **WHEN** an EntityData is created with `foundation = Vector2i(4,3)`, `bib_cells = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1), Vector2i(3, -1)]`
- **THEN** the bottom row of cells are bib for harvester docking access

#### Scenario: Building without bib cells
- **WHEN** an EntityData is created without setting `bib_cells`
- **THEN** `bib_cells` is an empty PackedVector2i

### Requirement: EntityData dock configuration
EntityData SHALL include `dock_position: Vector3` and `dock_rotation: float` for buildings with docking capability.

#### Scenario: Refinery with dock
- **WHEN** an EntityData is created with `dock_position = Vector3(0, 0, -2)`, `dock_rotation = 180.0`
- **THEN** the building has a dock 2 units behind the building center, facing south
