## ADDED Requirements

### Requirement: Fog of war configuration
`GlobalRules` SHALL contain a `fog_of_war: bool` (default `false`) that gates fog-gated interaction filtering, a `shroud_grows: bool` (default `false`) that enables shroud growth, and a `shroud_growth_interval: float` (default `10.0`) holding the gameplay seconds between each one-cell shroud growth step. These SHALL be exported on the resource and editable in `resources/global_rules.tres`.

#### Scenario: Defaults disabled
- **WHEN** GlobalRules loads with defaults
- **THEN** `fog_of_war` is false, `shroud_grows` is false, and `shroud_growth_interval` is `10.0`

#### Scenario: Overridable in resource
- **WHEN** a map or mod sets `shroud_growth_interval` to a different value in `resources/global_rules.tres`
- **THEN** ShroudSystem uses that interval for growth ticks
