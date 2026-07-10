## ADDED Requirements

### Requirement: PlayerData resource
The system SHALL provide a `PlayerData.gd` resource class for per-player treasury state.

#### Scenario: Create player with starting credits
- **WHEN** a PlayerData resource is created with `player_id = 0`, `credits = 1000`
- **THEN** the resource holds `player_id = 0` and `credits = 1000`

#### Scenario: Zero default credits
- **WHEN** a PlayerData is created without setting `credits`
- **THEN** `credits` is `0`

### Requirement: EconomyManager autoload
The system SHALL provide an `EconomyManager.gd` autoload singleton for credit tracking. It SHALL NOT generate income or run per-frame ticks — it is a pure ledger.

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
