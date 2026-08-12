## ADDED Requirements

### Requirement: ProjectileData resource class
The system SHALL provide a single `ProjectileData.gd` resource class defining the visual and
behavioral properties of an in-flight projectile. Every field SHALL have a sensible default
(`""`, `false`, `0`, `0.0`, or opaque white) so unused properties can be ignored. The class SHALL
cover identity (`id`, `display_name`), trajectory (`is_invisible`, `is_high_arc`,
`is_very_high_arc`, `is_arcing`, `is_floater`, `is_bouncy`), targeting (`targets_air`,
`targets_ground`, `has_proximity_fuse`, `is_guided`, `is_ranged`), behavior (`homing_turn_rate`,
`arm_delay`, `sub_projectile_count`, `speed_override`), and visuals (`casts_shadow`, `graphic_name`,
`rotates_to_face`, `tint_color`).

#### Scenario: Create an invisible hitscan projectile
- **WHEN** a `ProjectileData` is created with `id = "Invisible"` and `is_invisible = true`
- **THEN** the resource carries defaults for every other field (e.g. `targets_ground = true`,
  `is_guided = false`, `rotates_to_face = false`, `is_ranged = false`,
  `tint_color = Color(1, 1, 1, 1)`)

#### Scenario: Create a guided missile projectile
- **WHEN** a `ProjectileData` is created with `id = "HeatSeeker"`, `is_guided = true`,
  `rotates_to_face = true`, and `homing_turn_rate = 20`
- **THEN** the resource exposes all three values alongside defaults for unused fields

#### Scenario: New sprite-rotation, range, and tint fields default to no-op
- **WHEN** a `ProjectileData` is created without setting `rotates_to_face`, `is_ranged`, or `tint_color`
- **THEN** `rotates_to_face` is `false`, `is_ranged` is `false`, and `tint_color` is opaque white

### Requirement: ProjectileData validation
`ProjectileData` SHALL expose a `validate()` method returning a `PackedStringArray` of error
messages, and SHALL report an error when `id` is empty.

#### Scenario: Empty id fails validation
- **WHEN** `validate()` is called on a `ProjectileData` whose `id` is `""`
- **THEN** the returned array is non-empty and names the empty id

#### Scenario: Populated projectile passes validation
- **WHEN** `validate()` is called on a `ProjectileData` whose `id` is set
- **THEN** the returned array is empty

### Requirement: Projectile definition files
The system SHALL provide projectile `.tres` files under `resources/projectiles/`, each backed by
the `ProjectileData` script, covering the core projectiles used by weapons (at minimum Invisible,
Cannon, HeatSeeker, AAHeatSeeker, a lobbed/artillery projectile, and a grenade/flux projectile)
plus the remaining projectiles referenced by weapon data.

#### Scenario: All projectile files load and validate
- **WHEN** every `.tres` under `resources/projectiles/` is loaded
- **THEN** each loads as a `ProjectileData` with a non-empty `id` and passes `validate()`

#### Scenario: Weapon projectile references resolve
- **WHEN** a weapon `.tres` under `resources/weapons/` sets a non-empty `projectile` id
- **THEN** a projectile `.tres` with that `id` exists under `resources/projectiles/`
