## ADDED Requirements

### Requirement: Ice footing gated by feature flag
`Pathfinder` SHALL consume intact-ice footing only when the active game declares `breakable_ice`. The ice check SHALL be skipped entirely when the flag is off, and water SHALL remain governed by locomotor terrain speeds.

#### Scenario: Feature on
- **WHEN** `breakable_ice` is on and intact ice occupies a water cell
- **THEN** the cell is passable for a ground locomotor that could otherwise not cross water

#### Scenario: Feature off
- **WHEN** `breakable_ice` is off
- **THEN** the ice check is skipped and water passability follows the locomotor's terrain speeds
