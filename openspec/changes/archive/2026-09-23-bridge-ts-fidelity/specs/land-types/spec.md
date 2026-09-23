## REMOVED Requirements

### Requirement: Bridge deck land type registered in GlobalRules
**Reason**: Tiberian Sun has no `bridge` land type; bridge deck cells use ordinary land types. The synthetic type was an artifact of the first bridge model.

**Migration**: Remove `games/ts/land_types/bridge.tres`, its `GlobalRules.land_types` registration, the `TerrainSystem.BRIDGE_LAND_TYPE` constant and its level>0 return, and the `"bridge"` rows from the four ground locomotors. A deck cell now resolves `road` (road bridge lane) or `railroad` (rail bridge middle lane).

## MODIFIED Requirements

### Requirement: Deck passability is the road row
Bridge deck passability and cost SHALL be taken from the land row the deck cell resolves, with the destination terrain figure skipped entirely. A road-bridge lane SHALL use the locomotor's Road row; a rail-bridge middle lane SHALL use its Railroad row. This SHALL hold regardless of the ground land type beneath the deck (water, beach, clear). A water-only locomotor SHALL NOT treat the deck as passable.

#### Scenario: Deck uses road cost over water
- **WHEN** a wheeled unit crosses a road-bridge deck cell over water
- **THEN** the deck cost uses the wheeled locomotor's Road multiplier

#### Scenario: Rail lane uses the railroad row
- **WHEN** a unit crosses a rail-bridge middle lane
- **THEN** the deck cost uses the locomotive's Railroad multiplier

#### Scenario: Terrain figure skipped on deck
- **WHEN** a tracked unit whose water speed is zero crosses a road deck over water
- **THEN** the deck is passable because the deck uses the Road row

#### Scenario: Ship refused on deck
- **WHEN** `is_passable` is evaluated for a Ship locomotor on a deck surface
- **THEN** the deck is not passable
