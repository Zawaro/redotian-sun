## ADDED Requirements

### Requirement: Veteran ROF shortens reload delay
When setting a weapon group's cooldown after firing, `CombatComponent` SHALL divide the base cooldown by `GlobalRules.get_veteran_rof_multiplier(veteran_level)`. A rookie (`veteran_level = 0`) SHALL use the base cooldown unchanged. The bonus SHALL apply from the next shot after a promotion.

#### Scenario: Veteran reloads faster
- **WHEN** a veteran unit with `veteran_rof = 0.20` and a 1.0 s base cooldown fires
- **THEN** the cooldown is set to 1.0 / 1.20 s

#### Scenario: Rookie uses base cooldown
- **WHEN** a rookie unit fires
- **THEN** the cooldown equals the base rate-of-fire conversion

#### Scenario: Bonus applies after promotion
- **WHEN** a unit is promoted mid-engagement
- **THEN** its subsequent cooldowns use the veteran ROF multiplier
