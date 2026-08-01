## ADDED Requirements

### Requirement: Configurable jumpjet target height
The `Locomotor` resource SHALL provide a `jumpjet_target_height: float` field expressed in terrain height units (each unit = `TerrainSystem.HEIGHT_STEP` world units), defaulting to `5.0`. `MovementController` SHALL use `jumpjet_target_height * HEIGHT_STEP` as the jumpjet's flight altitude, independent of `GlobalRules.hover_height` and `hover_height_override`.

#### Scenario: Default target height
- **WHEN** a Jumpjet Locomotor resource is created without overriding `jumpjet_target_height`
- **THEN** the jumpjet's flight altitude SHALL be `5.0 * HEIGHT_STEP` world units above terrain

#### Scenario: Configurable target height
- **WHEN** a Jumpjet Locomotor resource sets `jumpjet_target_height = 3.0`
- **THEN** the jumpjet's flight altitude SHALL be `3.0 * HEIGHT_STEP` world units above terrain

### Requirement: Vertical state machine
`MovementController` SHALL maintain a vertical state for jumpjet units from the set `{GROUND, ASCENDING, AIR, DESCENDING}`. The unit's Y position SHALL move toward the target altitude (terrain for GROUND/DESCENDING, terrain + flight altitude for AIR/ASCENDING) at `move_speed` per second, not snap. ASCENDING SHALL transition to AIR, and DESCENDING SHALL transition to GROUND, on reaching the target altitude.

#### Scenario: Ascending from ground
- **WHEN** a grounded jumpjet is ordered to fly
- **THEN** it enters ASCENDING and its Y increases by `move_speed * delta` per frame until it reaches the flight altitude, then enters AIR

#### Scenario: Descending to ground
- **WHEN** an airborne jumpjet is ordered to walk
- **THEN** it enters DESCENDING and its Y decreases by `move_speed * delta` per frame until it reaches terrain height, then enters GROUND

#### Scenario: No snapping on transition
- **WHEN** a jumpjet transitions between GROUND and AIR
- **THEN** its Y never changes by more than `move_speed * delta` in a single frame

### Requirement: Zone retention on attack
When `MovementController.set_target_position(target, unblock_buildings, keep_zone)` is called with `keep_zone = true` on a jumpjet, the unit SHALL attack from its current zone: grounded units walk to the target and attack on land, airborne units fly to the target and attack in the air. A unit in ASCENDING or DESCENDING SHALL ascend to the flight altitude before attacking. `CombatComponent._move_toward_target()` SHALL pass `keep_zone = true`.

#### Scenario: Grounded jumpjet attacks on land
- **WHEN** a grounded jumpjet is issued an attack order and moves to approach
- **THEN** it takes the walk path and attacks from the ground

#### Scenario: Airborne jumpjet attacks in air
- **WHEN** an airborne jumpjet is issued an attack order and moves to approach
- **THEN** it takes the fly path and attacks from the air at its flight altitude

#### Scenario: Mid-transition attack ascends first
- **WHEN** a jumpjet in ASCENDING or DESCENDING is issued an attack order
- **THEN** it completes the ascent to the flight altitude before attacking

### Requirement: Hover on fly-order arrival
A jumpjet completing a fly order SHALL remain hovering at its flight altitude above the destination. Only a walk order SHALL trigger descent to the ground.

#### Scenario: Fly order arrives and hovers
- **WHEN** a jumpjet completes a fly (distant or unreachable) move order
- **THEN** it stays at the flight altitude (AIR) instead of landing

#### Scenario: Walk order arrives and lands
- **WHEN** a jumpjet completes a walk move order
- **THEN** it descends to and stands on the ground

### Requirement: New order while descending ascends back
If a jumpjet receives any new order while in the DESCENDING state, it SHALL interrupt the descent and ascend back to the air zone before processing the new order's movement.

#### Scenario: Descending interrupt
- **WHEN** a descending jumpjet is issued a new move order
- **THEN** it switches to ASCENDING and returns to the flight altitude

### Requirement: Airborne terrain speed exemption
`MovementController._terrain_speed_factor()` SHALL return `1.0` for a jumpjet that is not on the ground, so terrain type does not slow an airborne unit.

#### Scenario: Flying over rough terrain
- **WHEN** an airborne jumpjet passes over a rough cell that would slow its walking speed
- **THEN** its movement speed is unaffected by the terrain multiplier
