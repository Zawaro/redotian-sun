## ADDED Requirements

### Requirement: Tiberium crystal material emits its resource-type color
The crystal material built by `ResourceComponent` SHALL enable emission tinted to the resource type's `color`, driven bright enough to cross the world environment's bloom threshold, while keeping its albedo color unchanged.

#### Scenario: Emission matches resource color
- **WHEN** the crystal material for a resource type is built from its `ResourceType.color`
- **THEN** the material has emission enabled, `emission` equal to that color, and `albedo_color` equal to that color

#### Scenario: Emission energy crosses bloom threshold
- **WHEN** the crystal material is built
- **THEN** `emission_energy_multiplier` is set high enough (>= 3.0) that the brightest emission channel exceeds the environment `glow_hdr_threshold`

#### Scenario: Different types glow different hues
- **WHEN** materials are built for green (`0.2, 0.8, 0.2`) and red (`1.0, 0.2, 0.2`) resource types
- **THEN** each material's `emission` equals its own resource color, with no shared or hard-coded hue

### Requirement: Crystal glow reuses the shared cached material
Enabling emission SHALL NOT add per-crystal cost: all cubes of a resource type continue to share one cached material instance, and no per-entity light nodes are created.

#### Scenario: Material is cached per resource type
- **WHEN** many crystals of the same resource type are drawn
- **THEN** they all reference the single cached material for that `resource_type_id`

### Requirement: World environment bloom is tuned to reveal emissive crystals
The `DefaultWorldEnvironment01` environment SHALL configure glow so emissive crystals produce a visible halo: glow enabled, `glow_intensity` >= 0.8, `glow_hdr_threshold` <= 0.9, and `glow_bloom` > 0.

#### Scenario: Glow settings produce visible bloom
- **WHEN** the world environment loads
- **THEN** `glow_enabled` is true, `glow_intensity` is at least 0.8, `glow_hdr_threshold` is at most 0.9, and `glow_bloom` is greater than 0

### Requirement: Tiberium trees remain non-emissive
The glow treatment SHALL apply only to tiberium crystal entities; TiberiumTree placeholders remain unchanged.

#### Scenario: Tree placeholder unchanged
- **WHEN** a TiberiumTree placeholder is rendered
- **THEN** its material has no emission added by this change
