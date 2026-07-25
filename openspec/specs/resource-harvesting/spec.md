## MODIFIED Requirements

### Requirement: HarvestComponent order targeter
HarvestComponent SHALL implement `get_order_for_target()`. When target has ResourceComponent, it SHALL return an OrderResult with cursor HARVEST, priority 20, and execute callback that calls `set_target_node(target)`. When target has DockHostComponent, it SHALL return cursor ENTER, priority 15, and execute callback that calls `set_target_refinery(target)`. Harvesters do NOT have CombatComponent — the HARVEST/ENTER priority ordering is correct for harvester-only scenarios.

#### Scenario: Harvesting tiberium
- **WHEN** a harvester with cargo space available is selected and cursor is over a ResourceComponent entity
- **THEN** cursor SHALL be HARVEST and clicking SHALL call `set_target_node(target)`

#### Scenario: Full cargo
- **WHEN** a harvester with full cargo is selected and cursor is over a ResourceComponent entity
- **THEN** cursor SHALL be ENTER (direct to refinery, not harvest)

#### Scenario: Docking at refinery
- **WHEN** a harvester is selected and cursor is over a DockHostComponent entity
- **THEN** cursor SHALL be ENTER and clicking SHALL call `set_target_refinery(target)`

#### Scenario: No match
- **WHEN** target has neither ResourceComponent nor DockHostComponent
- **THEN** get_order_for_target() SHALL return null

### Requirement: HarvestComponent removes get_cursor_for_target
HarvestComponent SHALL remove the existing `get_cursor_for_target()` method. Cursor behavior is now provided by `get_order_for_target()`.

#### Scenario: Old method removed
- **WHEN** `get_cursor_for_target()` is called on HarvestComponent
- **THEN** it SHALL not exist (method removed)
