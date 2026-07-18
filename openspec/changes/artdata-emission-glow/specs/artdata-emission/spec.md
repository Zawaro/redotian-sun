## ADDED Requirements

### Requirement: ArtData emission fields
ArtData SHALL include `emission_enabled: bool` (default false), `emission_color: Color` (default Color.BLACK), and `emission_energy_multiplier: float` (default 1.0) to control material emission properties.

#### Scenario: Emission disabled by default
- **WHEN** an ArtData resource is created without setting emission fields
- **THEN** `emission_enabled` is false, `emission_color` is Color.BLACK, `emission_energy_multiplier` is 1.0

#### Scenario: Emission enabled with custom color
- **WHEN** an ArtData has `emission_enabled = true`, `emission_color = Color(0.2, 0.8, 0.2)`, `emission_energy_multiplier = 3.0`
- **THEN** the material applied by ArtComponent SHALL have emission enabled with the specified color and energy

### Requirement: ArtComponent applies emission to materials
ArtComponent SHALL apply ArtData emission fields to StandardMaterial3D when loading models or creating placeholders.

#### Scenario: Model loading with emission
- **WHEN** ArtComponent loads a model and art_data has `emission_enabled = true`
- **THEN** the material's `emission_enabled`, `emission`, and `emission_energy_multiplier` SHALL be set from art_data

#### Scenario: Placeholder with emission
- **WHEN** ArtComponent creates a placeholder and art_data has `emission_enabled = true`
- **THEN** the placeholder material SHALL have emission applied

#### Scenario: No emission when disabled
- **WHEN** art_data has `emission_enabled = false`
- **THEN** the material SHALL NOT have emission enabled

### Requirement: ResourceComponent reads ArtData emission
ResourceComponent SHALL read emission fields from `data.art_data` via `configure()` and apply them to procedural materials in `_ensure_visual_nodes()`.

#### Scenario: Tiberium crystal with emission
- **WHEN** ResourceComponent configures with an EntityData that has art_data with `emission_enabled = true`
- **THEN** the procedural BoxMesh material SHALL have emission applied

#### Scenario: Tiberium crystal without art_data
- **WHEN** ResourceComponent configures with an EntityData that has no art_data
- **THEN** the material SHALL be created without emission (existing behavior)

#### Scenario: Material cache includes emission
- **WHEN** multiple crystals of the same resource_type_id share a cached material
- **THEN** the cached material SHALL reflect the emission settings from the first crystal's art_data
