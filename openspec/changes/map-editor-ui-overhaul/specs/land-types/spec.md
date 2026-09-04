## ADDED Requirements

### Requirement: LandType group for editor browsing
Each LandType SHALL carry a `group: String` (default empty) naming the bottom-bar tileset group it belongs to (e.g. "Sand", "Pavement"). Land types with the same group SHALL appear together in the editor's bottom bar; the group value SHALL have no gameplay effect.

#### Scenario: Grouped browsing
- **WHEN** two test-fixture LandTypes (e.g. "sand_dune" and "sand_rough") both carry group "Sand"
- **THEN** the editor bottom bar lists them together under the Sand group

Shipped v1 data groups each land type into its own group; multi-member groups arise from authored data and test fixtures.

### Requirement: New land types ship with locomotor speeds
The five editor LAT paint types (`sand`, `pavement`, `green`, `crystal`, `mold`) SHALL have per-locomotor terrain-speed entries on every locomotor whose `terrain_speeds` lists `clear`, using clear's multiplier. LAT `crystal` is a ground surface — it SHALL NOT be conflated with tiberium resource entities. Painting any of these types SHALL NOT block ground units.

#### Scenario: Passability parity with clear
- **WHEN** a locomotor's terrain speeds give "clear" a multiplier of 1.0
- **THEN** the same locomotor lists "sand", "pavement", "green", "crystal", and "mold" at 1.0

## MODIFIED Requirements

### Requirement: LandType registry in GlobalRules
GlobalRules SHALL contain a `land_types: Dictionary` mapping land type id strings to `LandType` resources, SHALL expose `get_land_type(id: String) -> LandType`, and SHALL support unlimited user-defined types. The dictionary SHALL be customizable — modders can register new `.tres` files (e.g. a "lava" type). The shipped registry SHALL include the editor LAT paint types: `sand`, `pavement`, `green`, `crystal`, and `mold`, each with an id, display name, editor color, and group.

#### Scenario: Default land types
- **WHEN** GlobalRules is loaded
- **THEN** `land_types` contains at least "clear", "rough", "road", "water", "cliff", "resource", "sand", "pavement", "green", "crystal", and "mold"

#### Scenario: LAT paint types resolvable
- **WHEN** GlobalRules is loaded
- **THEN** `get_land_type` resolves "sand", "pavement", "green", "crystal", and "mold"

#### Scenario: Custom land type registration
- **WHEN** a mod adds a "lava" LandType and registers it in `land_types`
- **THEN** `get_land_type("lava")` returns that LandType resource

#### Scenario: Unknown land type lookup
- **WHEN** `get_land_type("unknown")` is called for an id not in the registry
- **THEN** it returns `null`

### Requirement: LandType resource class
The system SHALL provide a `LandType.gd` resource class defining a terrain surface type's identity and editor presentation. Properties SHALL include `id: String`, `display_name: String`, `color: Color` (editor/debug), and `group: String` (editor bottom-bar tileset grouping, default empty). Surface identity is the only functional property — all movement behavior for a surface is defined by per-locomotor terrain speeds, not by the LandType itself.

#### Scenario: Create clear land type
- **WHEN** a LandType resource is created with `id = "clear"`, `display_name = "Clear"`, `color = Color(0.4, 0.7, 0.3)`, `group = "Clear"`
- **THEN** the resource holds those values and defines no movement behavior of its own

#### Scenario: Group defaults to empty
- **WHEN** a LandType resource is created without setting `group`
- **THEN** `group` is an empty string
