## ADDED Requirements

### Requirement: ArtData emission fields
ArtData SHALL include emission_enabled, emission_color, and emission_energy_multiplier fields for material emission control.

#### Scenario: Default values
- **WHEN** an ArtData is created without setting emission fields
- **THEN** emission_enabled SHALL be false, emission_color SHALL be Color.BLACK, emission_energy_multiplier SHALL be 1.0

### Requirement: ArtData point light fields
ArtData SHALL include point_light_enabled, point_light_color, point_light_energy, point_light_range, and point_light_attenuation fields for OmniLight3D control.

#### Scenario: Default values
- **WHEN** an ArtData is created without setting point light fields
- **THEN** point_light_enabled SHALL be false and all other point light fields SHALL have sensible defaults

### Requirement: ArtComponent applies emission
ArtComponent SHALL apply ArtData emission fields to StandardMaterial3D when loading models or creating placeholders.

#### Scenario: Model with emission
- **WHEN** ArtComponent loads a model with emission_enabled true
- **THEN** the material SHALL have emission applied from ArtData fields

#### Scenario: Placeholder with emission
- **WHEN** ArtComponent creates a placeholder with emission_enabled true
- **THEN** the placeholder material SHALL have emission applied
