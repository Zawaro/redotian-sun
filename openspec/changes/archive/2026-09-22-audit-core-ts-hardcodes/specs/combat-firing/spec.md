## ADDED Requirements

### Requirement: Weapon rate of fire time base from rules
`CombatComponent` SHALL convert a weapon's `rate_of_fire` (logic ticks) to seconds using `GlobalRules.logic_fps`, rather than a compile-time frame-rate constant. The weapon cooldown SHALL be `rate_of_fire / logic_fps` seconds.

#### Scenario: ROF conversion
- **WHEN** the active rules set `logic_fps = 30.0` and the weapon has `rate_of_fire = 30`
- **THEN** the firing cooldown is 1.0 second

#### Scenario: No rules fallback
- **WHEN** no GlobalRules are active
- **THEN** the conversion falls back to 30 logic ticks per second without error
