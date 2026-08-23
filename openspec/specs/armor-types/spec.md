## ADDED Requirements

### Requirement: ArmorType resource class
The system SHALL provide an `ArmorType` resource class (`scripts/data/ArmorType.gd`, `class_name ArmorType extends Resource`) defining the identity and display properties of a single armor class. It SHALL contain `id: String` (unique identifier, e.g. "heavy"), `display_name: String`, and `color: Color`.

#### Scenario: ArmorType properties
- **WHEN** an ArmorType resource is created with `id = "heavy"`, `display_name = "Heavy"`
- **THEN** the resource exposes those values for registry lookup and UI

### Requirement: Armor type data files
The system SHALL provide one `.tres` file per armor class under `resources/armor_types/`. The default set SHALL be `none`, `wood`, `light`, `heavy`, `concrete` (matching the armor classes defined in rules.ini).

#### Scenario: Default armor set
- **WHEN** the game loads GlobalRules
- **THEN** the armor type registry contains `none`, `wood`, `light`, `heavy`, and `concrete`

#### Scenario: Mod adds a new armor class
- **WHEN** a mod drops a new `.tres` (`resources/armor_types/flak.tres`) and registers it in `global_rules.tres`
- **THEN** the armor type registry gains a "flak" entry with no schema or code change

### Requirement: Armor type registry on GlobalRules
GlobalRules SHALL hold `armor_types: Dictionary` mapping armor type id → `ArmorType` resource. It SHALL expose `get_armor_type(id: String) -> ArmorType` returning the ArmorType or `null` for unknown ids, and `get_armor_ids() -> Array[String]` returning the registered armor ids.

#### Scenario: Lookup existing armor type
- **WHEN** `get_armor_type("heavy")` is called on a loaded GlobalRules
- **THEN** it returns the ArmorType resource for "heavy"

#### Scenario: Lookup unknown armor type
- **WHEN** `get_armor_type("unknown")` is called
- **THEN** it returns `null`

#### Scenario: Enumerate armor ids
- **WHEN** `get_armor_ids()` is called
- **THEN** it returns the registered armor type ids (e.g. ["none", "wood", "light", "heavy", "concrete"])

### Requirement: Armor type validation
The system SHALL validate that every armor id referenced by data (warheads, entities) exists in the GlobalRules armor type registry.

#### Scenario: Warhead references unknown armor
- **WHEN** a WarheadData's multiplier dictionary references an armor id not in the registry
- **THEN** `validate()` reports an error for that warhead

#### Scenario: Entity references unknown armor
- **WHEN** damage is dealt to an entity whose `StatsComponent.armor` is not in the registry
- **THEN** damage SHALL be applied unmodified (full damage, multiplier 1.0) and the lookup SHALL not crash

#### Scenario: Warhead data uses legacy positional array
- **WHEN** a warhead `.tres` serializes `armor_damage_multipliers` as a positional array (`PackedFloat32Array([...])`) instead of a keyed dictionary
- **THEN** the file fails to load with a parse error and `validate()` cannot run, so the serialized form is rejected before it reaches validation
