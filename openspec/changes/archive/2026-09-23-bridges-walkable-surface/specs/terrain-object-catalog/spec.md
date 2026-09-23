## ADDED Requirements

### Requirement: Bridge-end terrain objects in the catalog
The `terrain_objects/` catalog SHALL include bridge-end objects: a `TerrainObject` of `cell_type = "cliff"` whose covered cells carry a road cut through three cells. Each cut cell SHALL have `land = "road"` (or the active game's road land type) and `corners` at the cut grade, and the non-cut cliff cells SHALL have cliff `corners` and `land`. The object SHALL satisfy the existing catalog data integrity rules (non-empty `cells`, 4-element `corners`, valid `crease`, land drawn from registered land-type ids, resolvable `art_data`). A rail bridge-end variant SHALL exist with the rail road cut.

#### Scenario: Bridge-end object loads as a cliff
- **WHEN** a bridge-end catalog `.tres` is loaded
- **THEN** its `cell_type` is `"cliff"` and it has non-empty `cells`

#### Scenario: Road cut is three road cells
- **WHEN** a bridge-end object is inspected
- **THEN** exactly three of its cells have `land` set to the road type at the cut grade

#### Scenario: Bridge end satisfies catalog integrity
- **WHEN** bridge-end objects are validated with the rest of the catalog
- **THEN** each has 4-element `corners`, a valid `crease`, a registered `land`, and resolvable `art_data`

#### Scenario: Rail end variant exists
- **WHEN** the catalog is scanned
- **THEN** a rail bridge-end variant with the rail road cut is present
