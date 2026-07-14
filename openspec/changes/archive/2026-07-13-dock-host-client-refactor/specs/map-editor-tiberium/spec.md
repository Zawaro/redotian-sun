## MODIFIED Requirements

### Requirement: Paint Tiberium tool
The editor SHALL paint Tiberium pod entities on cells via click+drag, using the Strength and Radius parameters. Entities are placed at the center of 2×2 unit cells. The editor SHALL use `resource_type_id` in the overrides dict.

#### Scenario: Paint brush on single cell
- **WHEN** Paint Tiberium is active and the player clicks a cell
- **THEN** a pod entity is created via `EntityFactory.create_entity("TIB")` with `tiberium_amount = strength% * max_amount`, `resource_type_id = "tiberium_green"`, positioned at the cell center

#### Scenario: Paint brush radius
- **WHEN** Paint Tiberium is active and Radius = 3
- **THEN** all cells within a 3-cell radius of the clicked cell are painted in the same pass

#### Scenario: Paint adds to existing pod
- **WHEN** a cell already has a pod entity and the player paints over it
- **THEN** the pod's amount increases by `strength% * max_amount`, capped at `tiberium_max_amount`
