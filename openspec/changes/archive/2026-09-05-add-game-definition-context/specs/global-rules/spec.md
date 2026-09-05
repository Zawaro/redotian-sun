## MODIFIED Requirements

### Requirement: GlobalRules resource
The system SHALL provide a `GlobalRules.gd` resource class containing all default game values from rules.ini [General] section. GlobalRules SHALL be stored per game as `res://games/<id>/global_rules.tres` (for Tiberian Sun: `res://games/ts/global_rules.tres`), referenced by that game's GameDefinition. The active instance SHALL be resolved through GameContext (see game-context spec).

#### Scenario: Load global rules
- **WHEN** the game starts with the default game
- **THEN** GlobalRules is loaded from the active game's definition with default values (veteran_ratio=10.0, build_speed=0.8, refund_percent=0.5, etc.)

### Requirement: Fog of war configuration
`GlobalRules` SHALL contain a `fog_of_war: bool` (default `false`) that gates fog-gated interaction filtering, a `shroud_grows: bool` (default `false`) that enables shroud growth, and a `shroud_growth_interval: float` (default `10.0`) holding the gameplay seconds between each one-cell shroud growth step. These SHALL be exported on the resource and editable in the active game's `global_rules.tres` (`games/ts/global_rules.tres` for Tiberian Sun).

#### Scenario: Defaults disabled
- **WHEN** GlobalRules loads with defaults
- **THEN** `fog_of_war` is false, `shroud_grows` is false, and `shroud_growth_interval` is `10.0`

#### Scenario: Overridable in resource
- **WHEN** a map or mod sets `shroud_growth_interval` to a different value in the active game's `global_rules.tres`
- **THEN** ShroudSystem uses that interval for growth ticks

### Requirement: Low power build rate coefficients
GlobalRules SHALL contain `worst_low_power_build_rate_coefficient: float` (default 0.3) and `best_low_power_build_rate_coefficient: float` (default 0.75) under the "Production and Power Effects" export group, from rules.ini [General] `WorstLowPowerBuildRate`/`BestLowPowerBuildRate`. These SHALL be editable in the active game's `global_rules.tres` (`games/ts/global_rules.tres` for Tiberian Sun).

#### Scenario: Defaults match rules.ini
- **WHEN** GlobalRules loads with defaults
- **THEN** `worst_low_power_build_rate_coefficient` is 0.3 and `best_low_power_build_rate_coefficient` is 0.75

#### Scenario: Overridable in resource
- **WHEN** a mod sets `worst_low_power_build_rate_coefficient = 0.5` in the active game's `global_rules.tres`
- **THEN** the power grid's build-rate interpolation uses 0.5 as the worst bound
