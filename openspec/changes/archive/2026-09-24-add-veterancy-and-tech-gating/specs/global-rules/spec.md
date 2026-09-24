## MODIFIED Requirements

### Requirement: Veterancy multipliers
GlobalRules SHALL contain veterancy bonus fractions per level (`veteran_combat`, `veteran_speed`, `veteran_sight`, `veteran_armor`, `veteran_rof`) and SHALL expose a multiplier accessor for each: `get_veteran_combat_multiplier(level)`, `get_veteran_speed_multiplier(level)`, `get_veteran_sight_multiplier(level)`, `get_veteran_armor_multiplier(level)` and `get_veteran_rof_multiplier(level)`. Each accessor SHALL return `1.0 + fraction * clamp(level, 0, veteran_cap)`, and the armor accessor SHALL negate its fraction so it reduces incoming damage. A `veteran_sight` of `0.0` SHALL resolve to a neutral `1.0` multiplier.

#### Scenario: Veteran combat bonus
- **WHEN** a unit reaches veteran status
- **THEN** its combat damage is increased by `veteran_combat` multiplier (default 0.25 = 25% bonus)

#### Scenario: Veteran sight bonus
- **WHEN** `get_veteran_sight_multiplier(1)` is called with `veteran_sight = 0.25`
- **THEN** it returns 1.25

#### Scenario: Neutral sight default
- **WHEN** `get_veteran_sight_multiplier(2)` is called with `veteran_sight = 0.0`
- **THEN** it returns 1.0

#### Scenario: Veteran ROF bonus
- **WHEN** `get_veteran_rof_multiplier(1)` is called with `veteran_rof = 0.20`
- **THEN** it returns 1.20, used as a divisor on reload delay

#### Scenario: Level clamped to cap
- **WHEN** `get_veteran_combat_multiplier(9)` is called with `veteran_cap = 2`
- **THEN** it treats the level as 2

## ADDED Requirements

### Requirement: Default tech level constant
GlobalRules SHALL contain `tech_level: int` (default `10`) as the fallback current tech level for a session that provides no mission override.

#### Scenario: Fallback level used
- **WHEN** a session starts with no mission tech-level override
- **THEN** the resolved player tech level is the `GlobalRules.tech_level` value

#### Scenario: Custom default
- **WHEN** GlobalRules is loaded with `tech_level = 5`
- **THEN** players in an override-free session start at tech level 5
