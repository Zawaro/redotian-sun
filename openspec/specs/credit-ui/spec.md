## ADDED Requirements

### Requirement: Credit display label in BuildMenu
The system SHALL display the current credit balance as a Label node above the building cameo grid in `BuildMenu.tscn`.

#### Scenario: Label shows current balance
- **WHEN** `BuildMenu._ready()` runs
- **THEN** a Label displays `EconomyManager.get_balance(0)` prefixed with "$"

#### Scenario: Label updates on credit change
- **WHEN** `EconomyManager.add()` or `EconomyManager.deduct()` changes the balance
- **THEN** the Label text updates to match the new balance

#### Scenario: No polling
- **WHEN** `_process()` runs
- **THEN** the Label does NOT update its text (updates only from `credits_changed` signal)

### Requirement: Insufficient funds visual feedback
The Label SHALL change color when the player's credit balance is below the cost of the cheapest buildable item.

#### Scenario: Sufficient funds
- **WHEN** `credits >= min(cost of all buildable items)`
- **THEN** the Label color is white

#### Scenario: Insufficient funds
- **WHEN** `credits < min(cost of all buildable items)`
- **THEN** the Label color turns red
