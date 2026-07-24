## MODIFIED Requirements

### Requirement: StatsComponent
The system SHALL provide a `StatsComponent.gd` (.gd only, no .tscn) that holds entity identity data: id, display_name, entity_type, armor, cost, tech_level, sight, owner, points, crusher, crushable.

#### Scenario: StatsComponent holds identity
- **WHEN** a StatsComponent is configured with EntityData
- **THEN** it exposes `id`, `display_name`, `entity_type`, `armor`, `cost`, `tech_level`, `sight`, `owner`, `points`, `crusher`, `crushable` as readable properties

#### Scenario: Crusher/crushable copied from data
- **WHEN** a StatsComponent is configured with EntityData where `crusher = true` and `crushable = false`
- **THEN** `StatsComponent.crusher` is `true` and `StatsComponent.crushable` is `false`
