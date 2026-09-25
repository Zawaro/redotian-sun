## ADDED Requirements

### Requirement: Span takes warhead damage
A LOW normal bridge span cell SHALL take damage from a weapon hit whose warhead sets `WarheadData.can_damage_walls`, and SHALL take no damage from a warhead whose `can_damage_walls` is clear. Bridge cells that the destructibility split marks indestructible — every end piece and every high-bridge cell, including rail bridges — SHALL take no damage from any warhead and SHALL remain in the bridge registry. Damage reaches a span through the cell-overlay pass of the shot resolution: a force-fire shot with no entity target, or collateral from a shot that did have one. Bridge damage is reached through force-fire targeting, which is the only order path that can target a bridge at all.

#### Scenario: Warhead with the flag damages a low span
- **WHEN** a shot whose warhead sets `can_damage_walls` resolves over a cell holding a destructible LOW normal span
- **THEN** that span's health SHALL decrease

#### Scenario: Warhead without the flag leaves the span untouched
- **WHEN** a shot whose warhead clears `can_damage_walls` resolves over a cell holding a destructible LOW normal span
- **THEN** that span's health SHALL be unchanged

#### Scenario: High bridge cell is immune to every warhead
- **WHEN** a shot whose warhead sets `can_damage_walls` resolves over a cell holding a high-bridge piece
- **THEN** that piece's health SHALL be unchanged and it SHALL remain in the bridge registry

#### Scenario: End piece is immune to every warhead
- **WHEN** a shot whose warhead sets `can_damage_walls` resolves over a cell holding a bridge end piece
- **THEN** that piece's health SHALL be unchanged and it SHALL remain in the bridge registry

#### Scenario: Destroyed low span leaves the registry
- **WHEN** a destructible LOW normal span's health reaches zero from warhead damage
- **THEN** it SHALL leave the `bridge` group and the cell SHALL revert to ground behaviour, using the existing destruction hook
