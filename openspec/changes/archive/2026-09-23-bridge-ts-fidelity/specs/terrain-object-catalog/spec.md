## MODIFIED Requirements

### Requirement: Bridge-end terrain objects in the catalog
The `terrain_objects/` catalog SHALL include bridge-end objects generated from the original engine's bridge tile footprints (`ovrps` for road, `tovrps` for rail): a `TerrainObject` of `cell_type = "cliff"` whose covered cells carry a road/rail cut through three cells at the deck grade, `rock` banks at the deck grade, and `rock` base cells at ground grade. Each cut cell SHALL carry the matching land (`road`, or `railroad` on the rail end's middle lane), a `corners` array at the cut grade; non-cut cliff cells SHALL carry `rock` cliff `corners`. The object SHALL satisfy the existing catalog data integrity rules (non-empty `cells`, 4-element `corners`, valid `crease`, land drawn from registered land-type ids, resolvable `art_data`). No `.tem` art SHALL be imported; end-cap art aliases the placeholder GLB's `ovrps01` (clear lower) or `ovrps02` (water lower) submesh, rotated per direction.

#### Scenario: Bridge-end object loads as a cliff
- **WHEN** a bridge-end catalog `.tres` is loaded
- **THEN** its `cell_type` is `"cliff"` and it has non-empty `cells`

#### Scenario: Road cut is three road cells
- **WHEN** a road bridge-end object is inspected
- **THEN** three of its cells have `land` set to the road type at the cut grade

#### Scenario: Rail cut middle cell is railroad
- **WHEN** a rail bridge-end object is inspected
- **THEN** its middle cut cell has `land` set to the railroad type

#### Scenario: Bridge end satisfies catalog integrity
- **WHEN** bridge-end objects are validated with the rest of the catalog
- **THEN** each has 4-element `corners`, a valid `crease`, a registered `land`, and resolvable `art_data`
