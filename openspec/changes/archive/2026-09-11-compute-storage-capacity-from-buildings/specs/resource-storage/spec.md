## MODIFIED Requirements

### Requirement: Per-category storage capacity
The system SHALL provide a storage capacity per resource category via `EconomyManager.get_storage_capacity(player_id, category)`. Capacity SHALL be computed per player as the sum of `EntityData.storage_capacity[category]` across that player's owned buildings (each owned building instance contributes its declared share for the category). A player with no owned buildings SHALL have capacity 0 for every category, and a category absent from every owned building's `storage_capacity` SHALL return 0. Capacity drives the storage bar denominator and the displayable fill ratio; free credits never count toward it. Enforcement of the cap on the stored value (harvester wait-at-full-storage, no deposit past capacity) is deferred.

#### Scenario: Refinery contributes its declared capacity
- **WHEN** a player owns one building whose `EntityData.storage_capacity` declares `{"tiberium": 2000}` and `EconomyManager.get_storage_capacity(player_id, "tiberium")` is called
- **THEN** it returns 2000

#### Scenario: Capacity sums across owned buildings
- **WHEN** a player owns two buildings that each declare `{"tiberium": 2000}` for the tiberium category
- **THEN** `EconomyManager.get_storage_capacity(player_id, "tiberium")` returns 4000

#### Scenario: No owned buildings means no capacity
- **WHEN** a player owns no buildings and `EconomyManager.get_storage_capacity(player_id, "tiberium")` is called
- **THEN** it returns 0

#### Scenario: Capacity is per player
- **WHEN** player A owns a storage building and player B owns none
- **THEN** `get_storage_capacity(A, "tiberium")` is greater than `get_storage_capacity(B, "tiberium")`

#### Scenario: Unknown category capacity
- **WHEN** a player's owned buildings declare no capacity for category `"weed"` and `EconomyManager.get_storage_capacity(player_id, "weed")` is called
- **THEN** it returns 0

#### Scenario: Capacity drops when a storage building is lost
- **WHEN** a player owns one building declaring `{"tiberium": 2000}` and that building is unregistered (sold, destroyed, or undeployed)
- **THEN** `EconomyManager.get_storage_capacity(player_id, "tiberium")` returns 0
