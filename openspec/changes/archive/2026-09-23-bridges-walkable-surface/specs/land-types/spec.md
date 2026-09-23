## ADDED Requirements

### Requirement: Bridge deck land type registered in GlobalRules
`GlobalRules.land_types` SHALL register a bridge/deck land type (id `bridge`, display name `"Bridge"`, editor color, group `"Bridge"`), so it can be referenced by locomotor `terrain_speeds` and pass `validate_locomotor_keys()`. The deck land type SHALL be resolved at runtime from bridge overlay surfaces at their level and SHALL NOT be a painted overlay type persisted in `land_types`. Resolving a deck SHALL NOT change the ground cell's painted land type.

#### Scenario: Bridge land type available
- **WHEN** GlobalRules is loaded
- **THEN** `get_land_type("bridge")` returns the bridge LandType resource

#### Scenario: Validator accepts the bridge key
- **WHEN** `GlobalRules.validate_locomotor_keys()` runs after a `bridge` terrain speed is added
- **THEN** it returns no error for the `bridge` key

#### Scenario: Bridge is not persisted as a painted override
- **WHEN** a map is exported after a bridge entity is placed
- **THEN** the bridge cell is not written to the `land_types` overlay

### Requirement: Deck passability is the road row
The bridge/deck surface SHALL be treated as a road-cost surface: deck passability and cost SHALL use the locomotor's Road row, and the destination land type's terrain figure SHALL be skipped entirely for the deck. This SHALL hold regardless of the ground land type beneath the deck (water, beach, clear). A water-only locomotor SHALL NOT treat the deck as passable.

#### Scenario: Deck uses road cost over water
- **WHEN** a wheeled unit crosses a deck cell over water
- **THEN** the deck cost uses the wheeled locomotor's Road multiplier

#### Scenario: Terrain figure skipped on deck
- **WHEN** a tracked unit whose water speed is zero crosses a deck over water
- **THEN** the deck is passable because the deck uses the Road row

#### Scenario: Ship refused on deck
- **WHEN** `is_passable` is evaluated for a Ship locomotor on a deck surface
- **THEN** the deck is not passable
