## MODIFIED Requirements

### Requirement: HitboxComponent size from EntityData
The system SHALL allow EntityData to specify a custom hitbox size via `hitbox_size: Vector3`. When non-zero, EntityFactory passes this size to the HitboxComponent. When zero, the default BoxShape3D size (2, 2, 2) is used. The system SHALL configure collision layers on the HitboxComponent based on entity type, and set the collision mask to include the projectile layer.

#### Scenario: Harvester truck-shaped hitbox
- **WHEN** a harvester EntityData has `hitbox_size = Vector3(1.5, 1.5, 3.0)`
- **THEN** the HitboxComponent BoxShape3D is 1.5 wide, 1.5 tall, 3.0 long (truck proportions)

#### Scenario: Ground unit hitbox collision layer
- **WHEN** an INFANTRY or VEHICLE entity is created with a HitboxComponent
- **THEN** the HitboxComponent collision_layer is `LAYER_HITBOX_GROUND` (1 << 1) and collision_mask includes `LAYER_PROJECTILE` (1 << 4)

#### Scenario: Air unit hitbox collision layer
- **WHEN** an AIRCRAFT entity is created with a HitboxComponent
- **THEN** the HitboxComponent collision_layer is `LAYER_HITBOX_AIR` (1 << 2) and collision_mask includes `LAYER_PROJECTILE` (1 << 4)

#### Scenario: Building hitbox collision layer
- **WHEN** a BUILDING entity is created with a HitboxComponent
- **THEN** the HitboxComponent collision_layer is `LAYER_HITBOX_BUILDING` (1 << 3) and collision_mask includes `LAYER_PROJECTILE` (1 << 4)

## ADDED Requirements

### Requirement: HitboxComponent damage detection
The HitboxComponent SHALL connect `area_entered` and `body_entered` signals in `_ready()`. When an entering node implements `get_damage_info() -> Dictionary` (keys: `"amount": int`, `"type": String`), the HitboxComponent SHALL forward the damage to its `health_component` via `take_damage(damage, damage_type)`.

#### Scenario: Projectile enters hitbox
- **WHEN** a node with `get_damage_info() -> {"amount": 50, "type": "bullet"}` enters the HitboxComponent area
- **THEN** `health_component.take_damage(50, "bullet")` is called and `received_damage(50, "bullet", source_node)` is emitted

#### Scenario: Non-damaging entity enters hitbox
- **WHEN** a node without `get_damage_info()` enters the HitboxComponent area
- **THEN** no damage is dealt and no signal is emitted

#### Scenario: No health component
- **WHEN** a node with `get_damage_info()` enters the HitboxComponent area but `health_component` is null
- **THEN** no damage is dealt and no signal is emitted

### Requirement: HealthComponent damage type parameter
The `take_damage()` method SHALL accept an optional `damage_type: String` parameter (default `""`). The `damage_taken` signal SHALL emit `(damage_amount: int, damage_type: String)`.

#### Scenario: Untyped damage
- **WHEN** `take_damage(30)` is called without a damage type
- **THEN** `damage_taken(30, "")` is emitted and health is reduced by 30

#### Scenario: Typed damage
- **WHEN** `take_damage(50, "explosive")` is called
- **THEN** `damage_taken(50, "explosive")` is emitted and health is reduced by 50

### Requirement: HitboxComponent collision layer constants
The HitboxComponent script SHALL define collision layer constants: `LAYER_HITBOX_GROUND = 1 << 1`, `LAYER_HITBOX_AIR = 1 << 2`, `LAYER_HITBOX_BUILDING = 1 << 3`, `LAYER_PROJECTILE = 1 << 4`.

#### Scenario: Constants are accessible
- **WHEN** `HitboxComponent.LAYER_HITBOX_GROUND` is referenced
- **THEN** the value is `2` (bit 1)
