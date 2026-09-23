## REMOVED Requirements

### Requirement: Ground locomotors declare a bridge terrain speed
**Reason**: There is no `bridge` land type in Tiberian Sun, so a `"bridge"` terrain-speed entry is meaningless. Deck cells resolve `road` or `railroad`, which ground locomotors already declare.

**Migration**: Remove the `"bridge"` entry from `Foot`, `Track`, `Wheel`, and `Amphibious` `terrain_speeds`. Keep the `road` and `railroad` rows; a road deck is crossed on the Road row and a rail middle lane on the Railroad row.

## MODIFIED Requirements

### Requirement: Large height steps cost from the road row
A locomotor SHALL cost a transition of two or more height levels (including a four-level bridge step) from the deck's resolved land row rather than the destination ground land type, so a unit keeps road-like speed climbing onto a deck over water: the Road row for a road deck, the Railroad row for a rail-bridge middle lane. On a deck the terrain figure SHALL be skipped entirely. Any rail-specific movement restriction SHALL be applied by the movement system from the rail bridge kind.

#### Scenario: Large step uses road multiplier
- **WHEN** a unit transitions a step of two or more levels onto a road deck
- **THEN** the cost uses the unit locomotor's road multiplier

#### Scenario: Deck skips the terrain figure
- **WHEN** a unit whose destination ground land type has zero speed crosses onto a deck
- **THEN** the deck transition is allowed at the deck land row's cost

#### Scenario: Rail high deck
- **WHEN** a rail bridge is crossed
- **THEN** its middle lane is treated as a railroad deck for cost and passability
