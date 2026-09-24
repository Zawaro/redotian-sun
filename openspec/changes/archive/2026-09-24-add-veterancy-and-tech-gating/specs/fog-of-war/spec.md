## ADDED Requirements

### Requirement: Veteran sight scales the revealer radius
A revealer's registered radius SHALL be the owner's effective sight: `sight × GlobalRules.get_veteran_sight_multiplier(veteran_level)`, rounded to whole cells. When an entity's rank changes, its `VisionComponent` SHALL re-register the revealer with the new radius so the revealed area grows (or shrinks) from the next reveal. A `veteran_sight` of `0.0` SHALL leave the radius unchanged.

#### Scenario: Veteran sees further
- **WHEN** a unit with `sight = 6`, `veteran_sight = 0.25` is promoted to veteran
- **THEN** its revealer is re-registered with a radius of 8 cells (6 × 1.25 rounded)

#### Scenario: Neutral sight leaves radius unchanged
- **WHEN** a unit is promoted with `veteran_sight = 0.0`
- **THEN** its registered radius is unchanged

#### Scenario: Rookie radius matches base sight
- **WHEN** a rookie unit registers a revealer
- **THEN** its radius equals its base `sight`

#### Scenario: Buildings are unaffected
- **WHEN** a building with `veteran_sight = 0.0` is promoted
- **THEN** its revealer radius is unchanged
