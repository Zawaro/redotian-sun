## MODIFIED Requirements

### Requirement: HarvestComponent order targeter
HarvestComponent SHALL implement `get_order_for_target()`. When target has ResourceComponent, it SHALL return an OrderResult with cursor HARVEST, priority 20, and execute callback that calls `set_target_node(target)`. When target has DockHostComponent, it SHALL return cursor ENTER, priority 15, and execute callback that calls `set_target_refinery(target)`. Harvesters do NOT have CombatComponent — the HARVEST/ENTER priority ordering is correct for harvester-only scenarios.

#### Scenario: Harvesting tiberium
- **WHEN** a harvester with cargo space available is selected and cursor is over a ResourceComponent entity
- **THEN** cursor SHALL be HARVEST and clicking SHALL call `set_target_node(target)`

#### Scenario: Full cargo
- **WHEN** a harvester with full cargo is selected and cursor is over a ResourceComponent entity
- **THEN** cursor SHALL be HARVEST and clicking SHALL call `set_target_node(target)` — the harvester walks to the tiberium cell first (authentic Tiberian Sun behavior), then routes to a refinery to unload; any in-flight dock SHALL be cancelled before the walk so the dock seek re-engages cleanly after arrival

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

## ADDED Requirements

### Requirement: Full harvester never strands after reaching the field
A harvester whose cargo is full SHALL not remain idle at a tiberium field. When it is ordered to harvest while full, any in-flight dock SHALL be cancelled at order time so the walk-to-field→unload chain is not disrupted by a busy dock client. After it reaches the field (TS-authentic walk-to-field behavior), it SHALL route to the nearest compatible refinery dock to unload. If a dock seek still cannot engage — no dock reachable or the client on retry cooldown — the harvester SHALL schedule a retry and re-attempt docking until a dock becomes reachable. A harvest click SHALL issue only the harvest order: `MouseHandler` pass 2 must return after executing an interact order so the click does not additionally issue a move command that cancels the harvest and strands the full harvester.

#### Scenario: Full harvester ordered to harvest
- **WHEN** a full harvester is ordered to harvest a tiberium field
- **THEN** it SHALL walk to the field, then route to the nearest compatible refinery to unload

#### Scenario: In-flight dock cancelled on harvest order
- **WHEN** a full harvester with an in-flight dock (dock client busy, e.g. mid auto-deliver) is ordered to harvest a tiberium field
- **THEN** the in-flight dock SHALL be cancelled before the harvester walks to the field, and after reaching the field it SHALL route to a refinery to unload

#### Scenario: Dock seek cannot engage immediately
- **WHEN** a full harvester reaches the field and no dock is reachable, so the dock seek does not engage
- **THEN** the harvester SHALL schedule a dock retry and continue re-seeking until it reaches a refinery

#### Scenario: Player-ordered dock never strands
- **WHEN** a harvester is ordered to dock at a refinery while its dock client is busy or on retry cooldown
- **THEN** the harvester SHALL retry docking rather than stopping idle

#### Scenario: Harvest click never double-issues a move
- **WHEN** a player clicks a tiberium field (interact hitbox) with a harvester selected, so the HARVEST order executes
- **THEN** the click SHALL NOT also issue a MOVE order on the same click; `MouseHandler` pass 2 SHALL return after executing an interact order so the "no entity → move" fall-through does not cancel the harvest and strand the full harvester

#### Scenario: Non-full harvester unaffected
- **WHEN** a harvester with cargo space available is ordered to harvest a tiberium field
- **THEN** it SHALL harvest normally and only route to a refinery once full or the field is depleted
