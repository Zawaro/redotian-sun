## MODIFIED Requirements

### Requirement: EconomyManager autoload
The system SHALL provide an `EconomyManager.gd` autoload singleton for credit tracking. It SHALL NOT generate income or run per-frame ticks — it is a pure ledger. EconomyManager SHALL delegate all state to PlayerData via PlayerManager.get_player_data() — it owns no player data dictionary and no per-frame timers. Balance and mutation APIs SHALL be category-aware: `add`, `deduct`, `can_afford`, and `get_balance` accept a resource category defaulting to `"tiberium"`. `add` SHALL accept an `is_free` flag: default credits the category's **stored** value (harvest deposits, production-cancel refunds); `is_free = true` credits **free credits** (starting credits, crate bonuses, debug money, sell refunds) which never count toward storage. `deduct` SHALL spend stored credits first, then free. `get_balance` with no category SHALL return free credits plus the stored value of displayable (`display_in_hud = true`) categories, so hidden groups never reach the HUD; with a category it SHALL return that category's stored value.

#### Scenario: Add harvest credits to stored
- **WHEN** `EconomyManager.add(0, 500, "harvest")` is called
- **THEN** player 0's tiberium stored value increases by 500 and `credits_changed` is emitted

#### Scenario: Add free credits do not touch stored
- **WHEN** `EconomyManager.add(0, 1000, "crate", "tiberium", true)` is called
- **THEN** player 0's tiberium stored value is unchanged, `get_balance(0)` increases by 1000, and `get_balance(0, "tiberium")` returns 0

#### Scenario: Add credits to a hidden category
- **WHEN** `EconomyManager.add(0, 100, "harvest", "weed")` is called
- **THEN** player 0's weed stored value increases by 100 and the displayable balance is unchanged

#### Scenario: Deduct credits successfully
- **WHEN** `EconomyManager.deduct(0, 300, "build")` is called and player 0 has balance >= 300
- **THEN** player 0's total balance decreases by 300, `credits_changed` is emitted, and `true` is returned

#### Scenario: Deduct drains stored credits first
- **WHEN** player 0 has 500 stored tiberium and 1000 free credits and `EconomyManager.deduct(0, 800, "build")` is called
- **THEN** stored tiberium becomes 0 and free credits become 700 (total 700)

#### Scenario: Deduct credits — insufficient funds
- **WHEN** `EconomyManager.deduct(0, 9999, "build")` is called and player 0's total balance < 9999
- **THEN** balances are unchanged, `false` is returned, and `insufficient_funds` is emitted

#### Scenario: Can afford check
- **WHEN** `EconomyManager.can_afford(0, 500)` is called
- **THEN** it returns `true` if player 0's total balance (stored + free) >= 500, `false` otherwise

#### Scenario: Get balance
- **WHEN** `EconomyManager.get_balance(0)` is called
- **THEN** it returns free credits plus the sum of player 0's displayable stored category balances

#### Scenario: Get balance for a specific category
- **WHEN** `EconomyManager.get_balance(0, "tiberium")` is called
- **THEN** it returns player 0's tiberium **stored** value (never free credits)

#### Scenario: Multiple player accounts
- **WHEN** `EconomyManager.add(0, 100, "test")` and `EconomyManager.add(1, 200, "test")` are called
- **THEN** player 0 and player 1 have independent balances (100 and 200 respectively)

#### Scenario: Deduct with reason
- **WHEN** `EconomyManager.deduct(0, 100, "build:refinery")` is called
- **THEN** the `credits_changed` signal includes `"build:refinery"` as the reason string

#### Scenario: Stateless reads from PlayerManager
- **WHEN** EconomyManager.get_balance(0) is called
- **THEN** it calls PlayerManager.get_player_data(0) to get the PlayerData instance and reads stored category balances and free credits from it

#### Scenario: Stateless writes to PlayerManager
- **WHEN** EconomyManager.add(0, 500, "harvest") is called
- **THEN** it calls PlayerManager.get_player_data(0) to get the PlayerData instance and modifies the tiberium stored value on it

#### Scenario: Storage capacity query
- **WHEN** `EconomyManager.get_storage_capacity(0, "tiberium")` is called
- **THEN** it returns 2000
