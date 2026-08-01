## ADDED Requirements

### Requirement: FoundationComponent registers only non-bib cells as building cells
`FoundationComponent._ready()` SHALL register the entity's foundation cells as building cells EXCLUDING its bib cells. Bib cells SHALL be registered only via `register_bib_cells()` and SHALL NOT appear in `_building_cells` (and therefore SHALL NOT be returned by `get_blocked_cells()` as building-blocked). This SHALL match the exclusion already performed by `BuildingManager.place_building`.

#### Scenario: Map-loaded refinery dock cell is not building-blocked
- **WHEN** a refinery with bib cells is added to the tree and its FoundationComponent registers
- **THEN** its bib cells (including the dock pad) SHALL be absent from `_building_cells`
- **AND** present in `_bib_cells` (via `is_bib_cell`)

#### Scenario: Non-bib foundation cells remain blocked
- **WHEN** a multi-cell building registers its foundation
- **THEN** all foundation cells that are not bib cells SHALL be present in `_building_cells`

#### Scenario: Unregistration matches registration
- **WHEN** the building leaves the tree
- **THEN** the same non-bib foundation cells SHALL be unregistered from `_building_cells`
- **AND** the bib cells SHALL be unregistered from `_bib_cells`

#### Scenario: Non-buildings still skip registration
- **WHEN** the entity is not a BUILDING (vehicle/infantry)
- **THEN** `FoundationComponent._ready` SHALL register no cells
