## ADDED Requirements

### Requirement: Ice takes warhead damage
An ice entity SHALL take warhead damage only when both the game declares the `breakable_ice` feature and the warhead sets `WarheadData.can_damage_walls`. When either condition fails, ice SHALL take no warhead damage. Ice is reached through the cell-overlay pass of shot resolution: a force-fire shot with no entity target, or collateral from a shot that did have one. This gate is independent of the existing weight-based surface damage, which is driven by occupancy rather than warheads.

#### Scenario: Ice damaged when the feature and flag are both present
- **WHEN** the game declares `breakable_ice` and a shot whose warhead sets `can_damage_walls` resolves over an ice cell
- **THEN** that ice entity's health SHALL decrease

#### Scenario: Ice untouched without the warhead flag
- **WHEN** the game declares `breakable_ice` and a shot whose warhead clears `can_damage_walls` resolves over an ice cell
- **THEN** that ice entity's health SHALL be unchanged

#### Scenario: Ice untouched when the feature is off
- **WHEN** the game does not declare `breakable_ice` and a shot whose warhead sets `can_damage_walls` resolves over an ice cell
- **THEN** that ice entity's health SHALL be unchanged

#### Scenario: Warhead-killed ice drowns its occupants
- **WHEN** warhead damage drives an ice entity's health to zero while the `breakable_ice` feature is on and units occupy its cell
- **THEN** the ice SHALL be destroyed and those occupants SHALL drown, per the existing breakage requirement
