## ADDED Requirements

### Requirement: Bridge overlay data fields
`EntityData` SHALL expose bridge overlay fields used to resolve a deck surface: a bridge kind (`bridge_kind`, default none) distinguishing `low`, `high`, and `rail`; an end-piece flag (`bridge_end`, default false); a deck grade/rise (`bridge_rise`, default four height steps) used by the high deck height; and a deck level (`bridge_level`, default 0) used to place the surface in the cell's stack. A `bridge_kind` other than none SHALL mark the entity as a bridge overlay for component attachment and registry resolution. A `bridge_level` at or above `TerrainSystem.MAX_HEIGHT` SHALL be invalid.

#### Scenario: Defaults are inert
- **WHEN** an `EntityData` is created without bridge fields
- **THEN** `bridge_kind` is none, `bridge_end` is false, `bridge_level` is 0, and the entity is not treated as a bridge

#### Scenario: Low bridge declared
- **WHEN** an `EntityData` sets the low bridge kind
- **THEN** it is treated as a low bridge overlay at its level

#### Scenario: High bridge rise and level declared
- **WHEN** an `EntityData` sets the high bridge kind with a rise and a level
- **THEN** its deck surface is placed at that level, `bridge_rise` above the ground

#### Scenario: Rail kind declared
- **WHEN** an `EntityData` sets the rail bridge kind
- **THEN** it is treated as a high bridge variant

#### Scenario: Level bound enforced
- **WHEN** an `EntityData` declares a bridge level at or above `MAX_HEIGHT`
- **THEN** the level is rejected as invalid
