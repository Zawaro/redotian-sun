## ADDED Requirements

### Requirement: Default projectile speed exceeds the fastest unit speed

`GlobalRules.default_projectile_speed` SHALL sit on the same 2× TS time base as movement and SHALL be strictly greater than the world speed of the fastest unit in the active game, so a projectile fired from behind a receding target can still close. The default SHALL be 24 world units per second. Per-weapon and per-projectile TS speeds remain the fidelity path and may author values above it.

#### Scenario: Default outruns the fastest unit

- **WHEN** `GlobalRules.default_projectile_speed` is resolved at the default 24 u/s and the fastest unit is the Orca Fighter (TS Speed 20 → 12.0 u/s)
- **THEN** the default projectile speed is strictly greater than the unit's world speed

#### Scenario: Pursuing shot catches a receding target

- **WHEN** a non-guided projectile at the default speed is fired from behind a target receding at the fastest unit speed
- **THEN** the projectile closes the gap and detonates on the target rather than fizzling at maximum range
