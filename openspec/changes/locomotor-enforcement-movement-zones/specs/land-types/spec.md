## ADDED Requirements

### Requirement: LandType resource class
The system SHALL provide a `LandType.gd` resource class defining a terrain surface type's identity and editor presentation. Properties SHALL include `id: String`, `display_name: String`, and `color: Color` (editor/debug). Surface identity is the only functional property — all movement behavior for a surface is defined by per-locomotor terrain speeds, not by the LandType itself.

#### Scenario: Create clear land type
- **WHEN** a LandType resource is created with `id = "clear"`, `display_name = "Clear"`, `color = Color(0.4, 0.7, 0.3)`
- **THEN** the resource holds those values and defines no movement behavior of its own

### Requirement: LandType registry in GlobalRules
GlobalRules SHALL contain a `land_types: Dictionary` mapping land type id strings to `LandType` resources, SHALL expose `get_land_type(id: String) -> LandType`, and SHALL support unlimited user-defined types. The dictionary SHALL be customizable — modders can register new `.tres` files (e.g. a "lava" type).

#### Scenario: Default land types
- **WHEN** GlobalRules is loaded
- **THEN** `land_types` contains at least "clear", "rough", "road", "water", and "cliff"

#### Scenario: Custom land type registration
- **WHEN** a mod adds a "lava" LandType and registers it in `land_types`
- **THEN** `get_land_type("lava")` returns that LandType resource

#### Scenario: Unknown land type lookup
- **WHEN** `get_land_type("unknown")` is called for an id not in the registry
- **THEN** it returns `null`
