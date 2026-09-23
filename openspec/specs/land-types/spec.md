# land-types Specification

## Purpose

LandType is the surface-identity registry: each terrain surface type (clear, rough, road, water, cliff, resource, the editor LAT paint types sand/pavement/green/crystal/mold, and modder-defined types) has an id, display name, editor color, and editor grouping. LandTypes carry no movement behavior — speed and passability per surface live in the Locomotor registry. The `resource` type marks resource-occupied crystal fields; `TerrainSystem.get_land_type()` resolves those cells dynamically. The sparse painted overlay records non-default land types on the terrain grid and round-trips through map JSON.
## Requirements
### Requirement: LandType resource class
The system SHALL provide a `LandType.gd` resource class defining a terrain surface type's identity and editor presentation. Properties SHALL include `id: String`, `display_name: String`, `color: Color` (editor/debug), and `group: String` (editor bottom-bar tileset grouping, default empty). Surface identity is the only functional property — all movement behavior for a surface is defined by per-locomotor terrain speeds, not by the LandType itself. `group` is presentation-only and SHALL have no gameplay effect.

#### Scenario: Create clear land type
- **WHEN** a LandType resource is created with `id = "clear"`, `display_name = "Clear"`, `color = Color(0.4, 0.7, 0.3)`
- **THEN** the resource holds those values and defines no movement behavior of its own

#### Scenario: Group defaults to empty
- **WHEN** a LandType resource is created without setting `group`
- **THEN** `group` is an empty string

#### Scenario: Grouped browsing
- **WHEN** two LandTypes share the group `"Sand"`
- **THEN** the editor bottom bar lists them together under the Sand group

### Requirement: LandType registry in GlobalRules
GlobalRules SHALL contain a `land_types: Dictionary` mapping land type id strings to `LandType` resources, SHALL expose `get_land_type(id: String) -> LandType`, and SHALL support unlimited user-defined types. The dictionary SHALL be customizable — modders can register new `.tres` files (e.g. a "lava" type). The shipped registry SHALL additionally include the editor LAT paint types `sand`, `pavement`, `green`, `crystal`, and `mold`, each with an id, display name, editor color, and group.

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

### Requirement: Resource land type registered in GlobalRules
`GlobalRules.land_types` SHALL register a `"resource"` land type (id `resource`, display name `"Resource"`), so per-locomotor `resource` terrain speeds pass `validate_locomotor_keys()` and modders can repaint it.

#### Scenario: Resource land type available
- **WHEN** GlobalRules is loaded
- **THEN** `get_land_type("resource")` returns the `resource` LandType resource

### Requirement: New land types ship with locomotor speeds
Every locomotor whose `terrain_speeds` lists `clear` SHALL list the five editor LAT paint types (`sand`, `pavement`, `green`, `crystal`, `mold`) at clear's multiplier. LAT `crystal` is a ground surface and SHALL NOT be conflated with tiberium resource entities. Painting any of these types SHALL NOT block ground units.

#### Scenario: Passability parity with clear
- **WHEN** a ground locomotor lists `clear` at a multiplier
- **THEN** it lists `sand`, `pavement`, `green`, `crystal`, and `mold` at the same multiplier and passes all five

### Requirement: Painted land type overlay persists in map JSON
`TerrainSystem` SHALL persist the sparse painted land-type overlay: assigning a non-default land type SHALL record it, assigning the default (`clear`) or an empty id SHALL clear the override, and `export_to_json` SHALL write only the non-default overrides as a `"land_types"` object. `import_from_json` SHALL restore the overlay, and a map without the key SHALL load with no overrides.

#### Scenario: Override round-trip
- **WHEN** a cell is painted `rough` and the map is exported and re-imported
- **THEN** that cell reports `rough` as its painted land type

#### Scenario: Default is not persisted
- **WHEN** a cell is painted `clear`
- **THEN** no `"land_types"` entry is written for it and it reports no painted override

#### Scenario: Absent key loads clean
- **WHEN** a map with no `"land_types"` key is imported
- **THEN** every cell reports no painted override

### Requirement: Deck passability is the road row
Bridge deck passability and cost SHALL be taken from the land row the deck cell resolves, with the destination terrain figure skipped entirely. A road-bridge lane SHALL use the locomotor's Road row; a rail-bridge middle lane SHALL use its Railroad row. This SHALL hold regardless of the ground land type beneath the deck (water, beach, clear). A water-only locomotor SHALL NOT treat the deck as passable.

#### Scenario: Deck uses road cost over water
- **WHEN** a wheeled unit crosses a road-bridge deck cell over water
- **THEN** the deck cost uses the wheeled locomotor's Road multiplier

#### Scenario: Rail lane uses the railroad row
- **WHEN** a unit crosses a rail-bridge middle lane
- **THEN** the deck cost uses the locomotive's Railroad multiplier

#### Scenario: Terrain figure skipped on deck
- **WHEN** a tracked unit whose water speed is zero crosses a road deck over water
- **THEN** the deck is passable because the deck uses the Road row

#### Scenario: Ship refused on deck
- **WHEN** `is_passable` is evaluated for a Ship locomotor on a deck surface
- **THEN** the deck is not passable

