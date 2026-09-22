# resource-harvesting Specification

## Purpose

Harvester behavior: seeking resource cells, filling cargo, and unloading at refineries.
## Requirements
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

### Requirement: HarvestComponent removes get_cursor_for_target
HarvestComponent SHALL remove the existing `get_cursor_for_target()` method. Cursor behavior is now provided by `get_order_for_target()`.

#### Scenario: Old method removed
- **WHEN** `get_cursor_for_target()` is called on HarvestComponent
- **THEN** it SHALL not exist (method removed)

### Requirement: Full harvester never strands after reaching the field
A harvester whose cargo is full SHALL not remain idle at a tiberium field. When it is ordered to harvest while full, any in-flight dock SHALL be cancelled at order time so the walk-to-field→unload chain is not disrupted by a busy dock client. After it reaches the field (TS-authentic walk-to-field behavior), it SHALL route to the nearest compatible same-owner refinery dock to unload. If a dock seek still cannot engage — no same-owner dock reachable or the client on retry cooldown — the harvester SHALL remain near the field on its retry cooldown loop and re-attempt docking until a friendly dock becomes reachable, retaining its full cargo. A harvest click SHALL issue only the harvest order: `MouseHandler` pass 2 must return after executing an interact order so the click does not additionally issue a move command that cancels the harvest and strands the full harvester.

#### Scenario: Full harvester ordered to harvest
- **WHEN** a full harvester is ordered to harvest a tiberium field
- **THEN** it SHALL walk to the field, then route to the nearest compatible same-owner refinery to unload

#### Scenario: In-flight dock cancelled on harvest order
- **WHEN** a full harvester with an in-flight dock (dock client busy, e.g. mid auto-deliver) is ordered to harvest a tiberium field
- **THEN** the in-flight dock SHALL be cancelled before the harvester walks to the field, and after reaching the field it SHALL route to a refinery to unload

#### Scenario: Dock seek cannot engage immediately
- **WHEN** a full harvester reaches the field and no same-owner dock is reachable, so the dock seek does not engage
- **THEN** the harvester SHALL schedule a dock retry and continue re-seeking until it reaches a friendly refinery

#### Scenario: No friendly refinery — idle with retry
- **WHEN** a full harvester cannot find any same-owner refinery within search radius (e.g. own refineries destroyed)
- **THEN** the harvester SHALL stay near the field with its cargo retained, re-attempting the dock seek on the retry cooldown, and SHALL NOT dock at or queue toward a foreign-owned refinery

#### Scenario: Player-ordered dock never strands
- **WHEN** a harvester is ordered to dock at a refinery while its dock client is busy or on retry cooldown
- **THEN** the harvester SHALL retry docking rather than stopping idle

#### Scenario: Harvest click never double-issues a move
- **WHEN** a player clicks a tiberium field (interact hitbox) with a harvester selected, so the HARVEST order executes
- **THEN** the click SHALL NOT also issue a MOVE order on the same click; `MouseHandler` pass 2 SHALL return after executing an interact order so the "no entity → move" fall-through does not cancel the harvest and strand the full harvester

#### Scenario: Non-full harvester unaffected
- **WHEN** a harvester with cargo space available is ordered to harvest a tiberium field
- **THEN** it SHALL harvest normally and only route to a refinery once full or the field is depleted

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

### Requirement: Resource cell yield measured in bales
A harvestable resource cell's amount SHALL be expressed in bales, not a normalized 0-1 health ratio. A ripe tiberium cell SHALL yield exactly 11 collectable bales: tiberium has 12 growth stages (0-11) and the depleted stage yields nothing. Harvesting drains bales continuously (discrete per-stage art is deferred). Per-cell bale capacity SHALL be data-driven per `ResourceType` via `bales_per_cell` (default `1.0` for backward compatibility; `11` for tiberium). `ResourceComponent.get_amount()` SHALL return remaining bales, `get_max_amount()` SHALL return the cell's bale capacity, and `collect(bales)` SHALL remove the requested bales (clamped to what remains) and return the bales actually removed. Health SHALL remain the backing store; bales and health SHALL convert through the cell's bale capacity.

#### Scenario: Ripe cell yields 11 bales
- **WHEN** a full-health tiberium cell (`bales_per_cell = 11`) is harvested to depletion one bail at a time
- **THEN** the total bales returned by `collect()` SHALL equal 11 and `get_amount()` SHALL reach 0

#### Scenario: Partial collect
- **WHEN** `collect(3)` is called on a full tiberium cell
- **THEN** it SHALL return 3 and `get_amount()` SHALL be 8

#### Scenario: Collect clamps to remaining
- **WHEN** `collect(20)` is called on a cell with 5 bales remaining
- **THEN** it SHALL return 5, `get_amount()` SHALL be 0, and the cell SHALL be depleted

#### Scenario: Depleted cell yields nothing
- **WHEN** `collect(n)` is called on a cell with 0 bales remaining
- **THEN** it SHALL return 0

#### Scenario: Default capacity preserves ratio semantics
- **WHEN** a `ResourceComponent` has no resolvable `ResourceType` (e.g. an isolated unit test)
- **THEN** `bales_per_cell` SHALL default to `1.0` and full health SHALL equal 1.0 bale

### Requirement: Harvester load spans cells at reference capacity
A full 28-bale harvester load SHALL be obtainable from roughly 2.5 ripe tiberium cells, and the credits deposited for a full load SHALL equal total cargo bales multiplied by the resource type's `value` (700 for 28 Riparius bales at 25 credits/bail).

#### Scenario: 28 bales from ~2.5 ripe cells
- **WHEN** a harvester drains ripe tiberium cells (11 bales each) until `get_cargo_total()` reaches `storage` (28)
- **THEN** two cells SHALL be fully drained and 6 bales SHALL be drawn from a third cell

#### Scenario: Full load is worth 700 credits
- **WHEN** a harvester carrying 28 `tiberium_green` bales unloads at a refinery
- **THEN** the refinery owner SHALL receive 700 credits

### Requirement: Reference harvest fill rate
Harvesting SHALL fill cargo at `GlobalRules.harvester_fill_rate` bales per real second. The rate SHALL use the project's 2x TS time base (30 logic ticks/second, matching the existing `build_speed = 0.4` convention): TS authors 18 ticks per bail (9 stage ticks x HarvesterLoadRate 2), giving 30/18 = approximately 1.67 bales/s, so a full 28-bale load fills in about 17 seconds excluding travel. Because rates are expressed per real second and applied via `delta`, the host frame rate SHALL NOT change that duration.

#### Scenario: Fill rate data value
- **WHEN** `games/ts/global_rules.tres` is loaded
- **THEN** `harvester_fill_rate` SHALL be approximately 1.667

#### Scenario: Fill time
- **WHEN** an empty harvester with `storage = 28` harvests continuously at the configured fill rate
- **THEN** it SHALL reach full cargo in approximately 17 seconds

### Requirement: Harvest categories from data
`HarvestComponent` SHALL obtain its harvestable categories from `EntityData.harvestable_categories` via a `configure` method, rather than a compile-time `["tiberium"]` default. An empty list SHALL mean the harvester accepts every resource category.

#### Scenario: Configure from data
- **WHEN** a harvester is created from data with `harvestable_categories = ["tiberium"]`
- **THEN** `harvestable_types` is `["tiberium"]`

#### Scenario: No restrictive default
- **WHEN** harvester data leaves `harvestable_categories` empty
- **THEN** the harvester accepts every category

