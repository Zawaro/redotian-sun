# turrets Specification

## Purpose
TBD - created by archiving change turret-system. Update Purpose after archive.
## Requirements
### Requirement: Socket data model
`ArtData` SHALL expose `sockets: Array[SocketData]` (default empty). `SocketData` SHALL be a `Resource` with `id: String`, `pivot: Transform3D` (a 3D position and rest orientation local to the entity origin), `yaw_free: bool` (default `true`), `barrel_length: float` (default `0.0`), `placeholder_size: Vector3`, and `model_path: String` (default `""`, reserved for a future turret model). Socket ids SHALL be unique within one `ArtData`. `ArtData.get_socket(id)` SHALL return the matching socket or `null`.

#### Scenario: 3D pivot preserved
- **WHEN** a `SocketData` is authored with a pivot that has a non-zero Y component
- **THEN** the loaded resource reports that exact 3D pivot

#### Scenario: Unknown socket id
- **WHEN** `get_socket("left")` is called on an `ArtData` with only a socket `id = "main"`
- **THEN** it returns `null`

#### Scenario: Empty socket list default
- **WHEN** an `ArtData` does not set `sockets`
- **THEN** `sockets` is empty and the entity is treated as having no turrets

### Requirement: Per-unit weapon mount groups
`EntityData` SHALL expose `weapon_mount_groups: Array[WeaponMountGroupData]` (default empty). Each group SHALL reference one `weapon_index`, a non-empty `socket_ids: PackedStringArray`, a `fire_mode: FireMode` (default `SALVO`), and `fire_delay: float` seconds (default `0.0`). Multiple socket ids MAY reference the same weapon so one weapon fires from several turrets. A weapon referenced by no group SHALL be body-mounted. Mount groups SHALL be ordered; `STAGGER` fire order SHALL follow the order of `socket_ids`.

#### Scenario: Two turrets share one weapon
- **WHEN** a group has `weapon_index = 0` and `socket_ids = ["rocket_l", "rocket_r"]`
- **THEN** the single weapon fires from both sockets

#### Scenario: Unmounted weapon is body-mounted
- **WHEN** an entity has one weapon and an empty `weapon_mount_groups`
- **THEN** that weapon is body-mounted and subject to whole-body facing

#### Scenario: Fire order follows socket order
- **WHEN** a `STAGGER` group lists sockets `["a", "b", "c"]`
- **THEN** socket `a` fires first, `b` after `fire_delay`, then `c`

### Requirement: Single-socket default binding
When an entity's `ArtData` declares exactly one socket and `EntityData.weapon_mount_groups` is empty, every weapon SHALL bind to that socket by default. When the `ArtData` declares no sockets, every weapon SHALL be body-mounted.

#### Scenario: Lone turret is used by default
- **WHEN** an entity has two weapons, one `yaw_free` socket, and no mount groups
- **THEN** both weapons fire from that socket

#### Scenario: No sockets means body-mounted
- **WHEN** an entity has weapons and its `ArtData.sockets` is empty
- **THEN** every weapon is body-mounted

### Requirement: TurretComponent per-socket yaw
`EntityFactory` SHALL attach a `TurretComponent` when an entity's `ArtData` declares at least one socket. `TurretComponent` SHALL own an independent yaw per socket and SHALL expose `slew(socket_id: String, target_pos: Vector3, delta: float) -> bool`, which advances the socket yaw toward the target bearing by at most `rotation_speed * delta` and returns `true` only once the socket is within the angle threshold. It SHALL expose `get_yaw(socket_id: String) -> float` and `get_socket_world_transform(socket_id: String) -> Transform3D`. Sockets with `yaw_free = false` SHALL NOT yaw. `TurretComponent` SHALL NOT modify the entity body transform, and SHALL NOT touch MovementController state.

#### Scenario: Yaw-free socket slews at rotation speed
- **WHEN** `slew` is called on a `yaw_free` socket 90 degrees off target with `rotation_speed = 180.0` and `delta = 0.25`
- **THEN** the socket yaw advances by 45 degrees and the call returns `false`, and repeated calls converge and return `true`

#### Scenario: Fixed socket does not yaw
- **WHEN** `slew` is called on a socket with `yaw_free = false`
- **THEN** its yaw stays at the rest orientation and the call returns `true`

#### Scenario: Independent sockets
- **WHEN** two sockets on one entity are slewed toward different targets
- **THEN** each develops its own yaw without affecting the other or the body

### Requirement: Firing gate per weapon mount
`CombatComponent` SHALL evaluate each mount group with its own cooldown and range. When a group is ready and in range: a group whose sockets are `yaw_free` SHALL gate fire on turret alignment via `TurretComponent.slew` and MAY fire while the body is moving; a group that is body-mounted, or whose socket has `yaw_free = false`, SHALL retain the whole-body facing gate via `face_toward`. A target within `CellUtil.CELL_SIZE` SHALL fire regardless of alignment.

#### Scenario: Rotatable turret fires while body moves
- **WHEN** a tank with a `yaw_free` mount drives forward and its target is in range but off the body heading
- **THEN** the turret yaws to the target and the weapon fires without the body stopping

#### Scenario: Fixed socket forces body facing
- **WHEN** a `yaw_free = false` socket's weapon has an in-range target off the body heading
- **THEN** the weapon holds fire until the body faces the target

#### Scenario: Close target ignores alignment
- **WHEN** the target is within `CellUtil.CELL_SIZE` on the XZ plane
- **THEN** the group fires subject to cooldown without requiring body or turret alignment

### Requirement: Fire discipline
When a mount group becomes ready, its sockets SHALL fire according to `fire_mode`. `SALVO` SHALL fire every socket on the same tick after an optional `fire_delay` wind-up (`0.0` = immediate). `STAGGER` SHALL fire sockets in listed order, each `fire_delay` seconds after the previous. The rearm cooldown SHALL be shared by the group and set to `weapon.rate_of_fire / 30.0` seconds.

#### Scenario: Salvo fires together
- **WHEN** a `SALVO` group with `fire_delay = 0.0` becomes ready
- **THEN** all its sockets fire on the same physics tick

#### Scenario: Stagger spaces the shots
- **WHEN** a `STAGGER` group with `fire_delay = 0.3` has three sockets and becomes ready at `t`
- **THEN** the shots occur at `t`, `t + 0.3`, and `t + 0.6`

#### Scenario: Group rearm cooldown
- **WHEN** a group with `weapon.rate_of_fire = 20` fires
- **THEN** the next group shot is delayed by `0.667` seconds

### Requirement: Socket muzzle spawn
A dispatched projectile SHALL be spawned at the firing socket's world transform composed with its yaw and extended by `barrel_length` along the socket's forward axis, not at the unit center. A body-mounted weapon SHALL spawn from the entity transform offset by `WeaponData.fire_offset`.

#### Scenario: Turret muzzle is offset and yawed
- **WHEN** a projectile fires from a socket whose pivot is right of center and whose yaw points at the target
- **THEN** the projectile's initial position is offset to the socket and rotated with its yaw

#### Scenario: Body mount spawns near center
- **WHEN** a body-mounted weapon fires
- **THEN** the projectile spawns from the entity transform, not from any socket

### Requirement: Instanced turret rendering
For `INFANTRY`, `VEHICLE`, and `AIRCRAFT` entities, `UnitMeshRenderer` SHALL render each socket as its own instance whose transform is the entity transform composed with the socket pivot and the current socket yaw. A fixed socket SHALL use its rest orientation. Until a real turret model exists, a generated placeholder box mesh SHALL be rendered for the socket.

#### Scenario: Turret instance follows the unit
- **WHEN** a registered unit moves or rotates
- **THEN** its socket instances follow `entity.global_transform` and keep their own yaw

#### Scenario: Fixed socket holds rest orientation
- **WHEN** a unit with a `yaw_free = false` socket is rendered
- **THEN** that socket instance uses the pivot rest orientation with no yaw

### Requirement: Structure turret rendering
Entities that are not instanced (buildings, including the deployed Tick Tank) SHALL render each socket through a node-tree child mesh yawed by the socket yaw, with visibility following the entity's fog state. The deployed Tick Tank SHALL declare a `yaw_free` socket whose weapon can track a target while the deployed structure is stationary.

#### Scenario: Deployed structure turret tracks
- **WHEN** the deployed Tick Tank has an in-range target off its facing
- **THEN** its turret child yaws toward the target and fires

### Requirement: Turret schema validation
Validation SHALL reject an `ArtData` with duplicate socket ids, and an `EntityData` whose mount group references an unknown socket id or an out-of-range weapon index. Errors SHALL name the offending entity/art id.

#### Scenario: Duplicate socket id
- **WHEN** an `ArtData` declares two sockets with `id = "main"`
- **THEN** validation returns an error naming the art id

#### Scenario: Unknown socket in a group
- **WHEN** an `EntityData` mount group references a socket id absent from its `ArtData`
- **THEN** validation returns an error naming the entity id

#### Scenario: Out-of-range weapon index
- **WHEN** a mount group references a `weapon_index` outside `weapons`
- **THEN** validation returns an error naming the entity id

### Requirement: Continuous turret aim
A `yaw_free` socket SHALL continuously face the entity's current order target. While the entity has a live combat target, the socket SHALL slew toward that target every physics tick regardless of whether the target is inside weapon range (so a turret tracks during the chase). While the entity has no combat target and its `MovementController` sibling `is_moving()`, the socket SHALL slew toward `MovementController.get_target_position()`. When the entity has no combat target and is not moving, the socket SHALL realign to its rest orientation (`yaw` toward `0.0`, the chassis forward). Fixed sockets (`yaw_free = false`) and entities without a `MovementController` SHALL be unaffected. Combat aim SHALL take precedence over movement/idle aim within a tick, and no socket SHALL advance its yaw more than once per tick.

#### Scenario: Target tracked during the chase
- **WHEN** a `yaw_free` mount has a live target outside weapon range and the body is driving toward it
- **THEN** the turret yaws toward the target that tick (it does not stay frozen until the target is in range)

#### Scenario: Movement destination tracked
- **WHEN** a `yaw_free` mount has no combat target and the entity is moving
- **THEN** the turret yaws toward the movement destination

#### Scenario: Attack target wins over movement
- **WHEN** an entity with a `yaw_free` mount is moving and also has a live combat target in a different direction
- **THEN** the turret faces the combat target, not the movement destination

#### Scenario: Idle realigns to chassis forward
- **WHEN** a `yaw_free` mount has no combat target and the entity is not moving
- **THEN** the turret yaws back toward its rest orientation

#### Scenario: Fixed socket does not move
- **WHEN** the entity moves or has a target and its socket has `yaw_free = false`
- **THEN** the socket yaw stays at its rest orientation

