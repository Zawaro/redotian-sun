## ADDED Requirements

### Requirement: Unload credits the refinery owner
When `DockUnloadComponent` converts cargo into credits, it SHALL attribute the credits to the refinery building's owner (`StatsComponent.player_id` on the unload component's parent entity). The docker entity's owner SHALL NOT be consulted. When the refinery has no valid owner id (`< 0` or missing `StatsComponent`), no credits SHALL be granted.

#### Scenario: Harvester unloads at own refinery
- **WHEN** a player 1 harvester unloads cargo at a player 1 refinery
- **THEN** the credits SHALL be added to player 1's balance

#### Scenario: Credits never follow the docker
- **WHEN** a harvester owned by any player unloads at a refinery owned by player 2 (e.g. via a future legitimate path)
- **THEN** the credits SHALL be added to player 2's balance, not the harvester owner's and not the local player's

#### Scenario: Ownerless refinery pays nothing
- **WHEN** a docked docker unloads at a refinery without a valid owner id
- **THEN** no credits SHALL be added for any player

## MODIFIED Requirements

### Requirement: HarvestComponent order targeter
HarvestComponent SHALL implement `get_order_for_target()`. When target has ResourceComponent, it SHALL return an OrderResult with cursor HARVEST, priority 20, and execute callback that calls `set_target_node(target)`. When target has DockHostComponent AND the target's owner exactly matches the harvester's owner (both valid ids), it SHALL return cursor ENTER, priority 15, and execute callback that calls `set_target_refinery(target)`. When the target dock host is foreign-owned or either side has an unset owner id (`< 0` or missing `StatsComponent`), get_order_for_target() SHALL return null so downstream order generators can resolve the order. Harvesters do NOT have CombatComponent — the HARVEST/ENTER priority ordering is correct for harvester-only scenarios.

#### Scenario: Harvesting tiberium
- **WHEN** a harvester with cargo space available is selected and cursor is over a ResourceComponent entity
- **THEN** cursor SHALL be HARVEST and clicking SHALL call `set_target_node(target)`

#### Scenario: Full cargo
- **WHEN** a harvester with full cargo is selected and cursor is over a ResourceComponent entity
- **THEN** cursor SHALL be HARVEST and clicking SHALL call `set_target_node(target)` — the harvester walks to the tiberium cell first (authentic Tiberian Sun behavior), then routes to a refinery to unload; any in-flight dock SHALL be cancelled before the walk so the dock seek re-engages cleanly after arrival

#### Scenario: Docking at refinery
- **WHEN** a harvester is selected and cursor is over a same-owner DockHostComponent entity
- **THEN** cursor SHALL be ENTER and clicking SHALL call `set_target_refinery(target)`

#### Scenario: Enemy refinery produces no ENTER order
- **WHEN** a harvester is ordered onto a dock host owned by another player
- **THEN** get_order_for_target() SHALL return null and no ENTER order SHALL be issued

#### Scenario: No match
- **WHEN** target has neither ResourceComponent nor DockHostComponent
- **THEN** get_order_for_target() SHALL return null

### Requirement: Full harvester never strands after reaching the field
A harvester whose cargo is full SHALL not remain idle at a tiberium field. When it is ordered to harvest while full, any in-flight dock SHALL be cancelled at order time so the walk-to-field→unload chain is not disrupted by a busy dock client. After it reaches the field (TS-authentic walk-to-field behavior), it SHALL route to the nearest compatible same-owner refinery dock to unload. If a dock seek still cannot engage — no same-owner dock reachable or the client on retry cooldown — the harvester SHALL remain near the field on its retry cooldown loop and re-attempt docking until a friendly dock becomes reachable, retaining its full cargo. A harvest click SHALL issue only the harvest order: `MouseHandler` pass 2 must return after executing an interact order so the click does not additionally issue a move command that cancels the harvest and strands the full harvester.

#### Scenario: Full harvester ordered to harvest
- **WHEN** a full harvester is ordered to harvest a tiberium field
- **THEN** it SHALL walk to the field, then route to the nearest compatible same-owner refinery to unload

#### Scenario: In-flight dock cancelled on harvest order
- **WHEN** a full harvester with an in-flight dock (dock client busy, e.g. mid auto-deliver) is ordered to harvest a tiberium field
- **THEN** the in-flight dock SHALL be cancelled before the harvester walks to the field, and after reaching the field it SHALL route to a refinery to unload

#### Scenario: No friendly refinery — idle with retry
- **WHEN** a full harvester cannot find any same-owner refinery within search radius (e.g. own refineries destroyed)
- **THEN** the harvester SHALL stay near the field with its cargo retained, re-attempting the dock seek on the retry cooldown, and SHALL NOT dock at or queue toward a foreign-owned refinery
