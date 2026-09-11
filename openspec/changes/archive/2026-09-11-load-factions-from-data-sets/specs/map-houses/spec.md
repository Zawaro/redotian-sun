## MODIFIED Requirements

### Requirement: House id vocabulary
The system SHALL provide a canonical house id vocabulary module (`Houses.gd`) projected from the ordered roster of `FactionCatalog`, not from a hardcoded list. Houses are factions (the rules-side `[Houses]` list); player slots are a separate axis (start locations / waypoints 0-7) and SHALL NOT be modeled as houses. The module SHALL expose `id_for(index)`, `index_for(house_id)`, `display_name_for(house_id)`, and an ordered id accessor, with ordering taken from each faction's `order` field. When no factions are loaded, `id_for` SHALL return `""` and `index_for` SHALL return `-1`.

#### Scenario: Index to id follows loaded roster order
- **WHEN** the registry holds factions whose `order` fields are 0, 1, 2, and 3
- **THEN** `id_for(0)`, `id_for(1)`, `id_for(2)`, and `id_for(3)` return those factions' ids in ascending order

#### Scenario: Id to index
- **WHEN** `index_for(<id of the faction with order 1>)` is called
- **THEN** it returns `1`

#### Scenario: Unknown house
- **WHEN** `index_for("not_a_house")` is called
- **THEN** it returns `-1` and `display_name_for` returns the input unchanged

#### Scenario: Vocabulary matches owner strings
- **WHEN** the active roster includes the factions that ship as `EntityData.owner` values
- **THEN** every shipped owner value (`GDI`, `Nod`, `Neutral`) is a house id, and no house id uses a different casing
