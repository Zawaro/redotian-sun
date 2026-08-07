## ADDED Requirements

### Requirement: Default build time derives from GlobalRules build speed
`EntityData.get_build_time()` SHALL return the explicit `build_time` when it is positive. Otherwise it SHALL compute the build time from `cost` and the game-wide build-speed factor, which SHALL be sourced from `GlobalRules.build_speed` rather than a duplicated constant. When GlobalRules is unavailable, it SHALL fall back to the default factor `0.8`.

#### Scenario: Explicit build time takes precedence
- **WHEN** `build_time` is set to a positive value
- **THEN** `get_build_time()` returns that value unchanged

#### Scenario: Computed from GlobalRules build speed
- **WHEN** `build_time` is unset and GlobalRules is available
- **THEN** `get_build_time()` computes `cost * GlobalRules.build_speed * 60 / 1000`

#### Scenario: Fallback when GlobalRules unavailable
- **WHEN** `build_time` is unset and GlobalRules cannot be resolved
- **THEN** `get_build_time()` computes the time using the default factor `0.8`
