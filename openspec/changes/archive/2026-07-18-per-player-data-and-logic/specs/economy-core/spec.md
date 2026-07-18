## MODIFIED Requirements

### Requirement: EconomyManager autoload
The system SHALL provide an `EconomyManager.gd` autoload singleton for credit tracking. It SHALL NOT generate income or run per-frame ticks — it is a pure ledger. EconomyManager SHALL be stateless — it reads and writes PlayerData via PlayerManager.get_player_data() instead of owning its own player data dictionary.

#### Scenario: Add credits
- **WHEN** `EconomyManager.add(0, 500, "harvest")` is called
- **THEN** player 0's balance increases by 500 and `credits_changed` is emitted

#### Scenario: Deduct credits successfully
- **WHEN** `EconomyManager.deduct(0, 300, "build")` is called and player 0 has balance >= 300
- **THEN** player 0's balance decreases by 300, `credits_changed` is emitted, and `true` is returned

#### Scenario: Deduct credits — insufficient funds
- **WHEN** `EconomyManager.deduct(0, 9999, "build")` is called and player 0 has balance < 9999
- **THEN** balance is unchanged, `false` is returned, and `insufficient_funds` is emitted

#### Scenario: Can afford check
- **WHEN** `EconomyManager.can_afford(0, 500)` is called
- **THEN** it returns `true` if player 0's balance >= 500, `false` otherwise

#### Scenario: Get balance
- **WHEN** `EconomyManager.get_balance(0)` is called
- **THEN** it returns player 0's current credit balance

#### Scenario: Multiple player accounts
- **WHEN** `EconomyManager.add(0, 100, "test")` and `EconomyManager.add(1, 200, "test")` are called
- **THEN** player 0 and player 1 have independent balances (100 and 200 respectively)

#### Scenario: Deduct with reason
- **WHEN** `EconomyManager.deduct(0, 100, "build:refinery")` is called
- **THEN** the `credits_changed` signal includes `"build:refinery"` as the reason string

#### Scenario: Stateless reads from PlayerManager
- **WHEN** EconomyManager.get_balance(0) is called
- **THEN** it calls PlayerManager.get_player_data(0) to get the PlayerData instance and reads credits from it

#### Scenario: Stateless writes to PlayerManager
- **WHEN** EconomyManager.add(0, 500, "harvest") is called
- **THEN** it calls PlayerManager.get_player_data(0) to get the PlayerData instance and modifies credits on it
