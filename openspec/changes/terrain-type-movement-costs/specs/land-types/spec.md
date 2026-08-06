## ADDED Requirements

### Requirement: Resource land type registered in GlobalRules
`GlobalRules.land_types` SHALL register a `"resource"` land type (id `resource`,
display name `"Resource"`), so per-locomotor `resource` terrain speeds pass
`validate_locomotor_keys()` and modders can repaint it.

#### Scenario: Resource land type available
- **WHEN** GlobalRules is loaded
- **THEN** `get_land_type("resource")` returns the `resource` LandType resource
