## ADDED Requirements

### Requirement: Low power build rate coefficients
GlobalRules SHALL contain `worst_low_power_build_rate_coefficient: float` (default 0.3) and `best_low_power_build_rate_coefficient: float` (default 0.75) under the "Production and Power Effects" export group, from rules.ini [General] `WorstLowPowerBuildRate`/`BestLowPowerBuildRate`. These SHALL be editable in `resources/global_rules.tres`.

#### Scenario: Defaults match rules.ini
- **WHEN** GlobalRules loads with defaults
- **THEN** `worst_low_power_build_rate_coefficient` is 0.3 and `best_low_power_build_rate_coefficient` is 0.75

#### Scenario: Overridable in resource
- **WHEN** a mod sets `worst_low_power_build_rate_coefficient = 0.5` in `resources/global_rules.tres`
- **THEN** the power grid's build-rate interpolation uses 0.5 as the worst bound
