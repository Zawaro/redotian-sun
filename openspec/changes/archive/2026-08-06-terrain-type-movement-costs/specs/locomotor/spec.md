## ADDED Requirements

### Requirement: Resource terrain speed per ground locomotor
Every ground `Locomotor` SHALL declare a `"resource"` entry in `terrain_speeds`
using the TS tiberium percentages: `Foot` and `Jumpjet` at `0.9`, `Track` and
`Subterranean` at `0.7`, `Wheel` and `Amphibious` at `0.5`. `Hover` SHALL declare
`"resource": 1.0`. `Ship` SHALL declare no `"resource"` entry (impassable, TS
Float = 0%). `Fly` SHALL declare none (airborne). The existing `is_passable` and
`get_speed_multiplier` methods SHALL consume these entries unchanged.

#### Scenario: Wheeled unit slows in a crystal field
- **WHEN** a wheeled unit (`resource = 0.5`) enters a resource-occupied cell
- **THEN** its terrain speed multiplier is `0.5`

#### Scenario: Hover is unaffected by crystal fields
- **WHEN** a hover unit (`resource = 1.0`) enters a resource-occupied cell
- **THEN** its terrain speed multiplier is `1.0`

#### Scenario: Ship cannot cross crystal fields
- **WHEN** `is_passable("resource")` is called on a Ship locomotor
- **THEN** it returns `false`

#### Scenario: Validation accepts the resource key
- **WHEN** `GlobalRules.validate_locomotor_keys()` runs after the `resource`
  land type is registered
- **THEN** it returns no errors for the `resource` terrain speed keys
