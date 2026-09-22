## ADDED Requirements

### Requirement: Storage HUD uses the active primary category
The selected-entity storage display and the default economy category SHALL use `GlobalRules.primary_resource_category`, not the `"tiberium"` literal. `EconomyManager` SHALL resolve its default category from the active rules, falling back to the last-known category when no rules are active.

#### Scenario: TS primary category
- **WHEN** the active rules set `primary_resource_category = "tiberium"`
- **THEN** the storage bar reads the player's `"tiberium"` balance

#### Scenario: RA2 primary category
- **WHEN** the active rules set `primary_resource_category = "ore"`
- **THEN** the storage bar reads the player's `"ore"` balance and credit updates for `"ore"` refresh it

#### Scenario: Debug credit grant
- **WHEN** the debug menu grants credits
- **THEN** the balance is tagged with the active primary category
