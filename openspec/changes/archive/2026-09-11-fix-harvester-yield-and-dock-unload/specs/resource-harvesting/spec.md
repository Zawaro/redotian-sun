## ADDED Requirements

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
