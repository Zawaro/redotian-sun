## Purpose

UnitMeshRenderer bakes unit models into `ArrayMesh`es and draws them through per-region MultiMesh buckets, owning slot allocation and compaction, cross-region migration, per-instance fog hiding, post-destruction tombstones, and per-entity socket (turret) instances.
## Requirements
### Requirement: Model baking
The system SHALL bake each unit model's GLB subnodes into a single multi-surface `ArrayMesh` at first use, transforming subnode vertex positions (and normals/tangents) by the subnode's local transform relative to the model root and preserving each surface's material. Baked results SHALL be cached per model path.

#### Scenario: Bake preserves surface count
- **WHEN** a model with N `MeshInstance3D` subnodes is baked
- **THEN** the resulting `ArrayMesh` has all N subnode surfaces appended, with vertex arrays non-empty and a non-zero AABB

#### Scenario: Bake preserves materials
- **WHEN** a model with per-surface materials is baked
- **THEN** each resulting surface retains the source subnode's material

#### Scenario: Bake cache reuse
- **WHEN** a second unit of the same model is registered
- **THEN** no re-bake occurs and the cached mesh is reused

### Requirement: Entity registration lifecycle
The system SHALL register data-driven unit entities (EntityType INFANTRY, VEHICLE, or AIRCRAFT) with the renderer when their model finishes loading, and unregister them when the entity is removed from the tree. Registered entities SHALL have their GLB node tree hidden.

#### Scenario: Register on model load
- **WHEN** a unit entity's model finishes loading
- **THEN** the entity is registered with the renderer and its GLB node tree becomes invisible

#### Scenario: Unregister on removal
- **WHEN** a registered entity is freed or removed from the scene tree
- **THEN** the entity's renderer slot is released and its instance is no longer drawn

#### Scenario: Non-units unaffected
- **WHEN** a building, structure, or resource entity loads its model
- **THEN** it is not registered and continues rendering via its node tree

#### Scenario: Editor guarded
- **WHEN** the scene is opened or edited inside the Redot editor
- **THEN** no unit registration or GLB hiding occurs

### Requirement: Per-region MultiMesh buckets
The system SHALL render instanced units through fixed-size world regions, each region holding a `MultiMeshInstance3D` per model with a `custom_aabb` covering that region's box. Physics interpolation SHALL be disabled on every region node.

#### Scenario: Region culling
- **WHEN** the camera views a subset of the world
- **THEN** only region MultiMesh nodes intersecting the view frustum render

#### Scenario: Custom AABB set
- **WHEN** a region bucket is created
- **THEN** its `MultiMesh.custom_aabb` is set to the region box

#### Scenario: Interpolation off
- **WHEN** a region node is created
- **THEN** its `physics_interpolation_mode` is OFF

### Requirement: Per-frame transform sync
The system SHALL update each registered unit's instance transform every physics frame from the unit's world transform combined with the model root's local offset relative to the entity.

#### Scenario: Instance follows unit
- **WHEN** a unit moves or rotates (including terrain-normal tilt)
- **THEN** its MultiMesh instance transform matches `entity.global_transform` composed with the model-root offset

#### Scenario: Sync coalescing
- **WHEN** many units update in one frame
- **THEN** instance transforms are written via `set_instance_transform` and rendered in the same frame

### Requirement: Cross-region migration
The system SHALL move a unit's instance from its old region bucket to the new one when the unit crosses a region boundary.

#### Scenario: Moving between regions
- **WHEN** a unit's position crosses into a neighboring region
- **THEN** its instance is removed from the old region bucket and allocated in the new region bucket

### Requirement: Slot compaction
Removing an instance SHALL compact the region bucket: the last active instance moves into the freed slot and `visible_instance_count` decreases, keeping the remaining instances contiguous.

#### Scenario: Removal compacts slots
- **WHEN** a middle unit in a region is unregistered
- **THEN** the last unit moves into the freed slot and `visible_instance_count` decrements

#### Scenario: Visible count tracks active units
- **WHEN** units are registered and unregistered
- **THEN** `visible_instance_count` equals the number of active instances in the bucket

### Requirement: Per-instance fog hiding
The system SHALL support hiding a registered unit instance from rendering by parking its MultiMesh instance transform off-world while keeping its GLB node tree hidden, and SHALL support freezing a registered unit at its last-known position (fog ghost) by writing its transform once and then not syncing it. A hidden or frozen instance SHALL remain registered (its slot retained). A hidden instance SHALL resume normal transform syncing when unhidden, including re-migration if its region changed while hidden. A frozen instance SHALL NOT re-migrate while frozen, and SHALL snap to its current position and resume syncing when it becomes visible again. Hiding and freezing SHALL not alter slot compaction or visible_instance_count semantics beyond the parked or frozen transform.

#### Scenario: Hidden instance not drawn
- **WHEN** a registered unit is hidden
- **THEN** its MultiMesh instance transform is parked off-world and the unit is not rendered

#### Scenario: Unhidden instance resumes syncing
- **WHEN** a previously hidden unit is unhidden
- **THEN** its instance transform resumes tracking the unit's world transform on the next physics frame

#### Scenario: Region change while hidden
- **WHEN** a hidden unit crosses a region boundary and is then unhidden
- **THEN** its instance migrates to the new region's bucket on the next sync

#### Scenario: Frozen instance persists in fog
- **WHEN** a registered unit is frozen as a fog ghost
- **THEN** its MultiMesh instance transform stays at the position where it entered fog and does not follow the unit

#### Scenario: Frozen instance has no migration
- **WHEN** a frozen unit crosses a region boundary while still in fog
- **THEN** its instance does not migrate; it migrates only once the unit becomes visible again

### Requirement: Post-destruction tombstone ghosts
A unit whose MultiMesh instance is frozen as a fog ghost SHALL, when the unit is destroyed while still in fog, retain its frozen instance as a tombstone rather than releasing the slot. The tombstone SHALL be released when the unit's last-known cell becomes visible, reverts to shroud, or when fog is toggled off at runtime. Tombstone retention SHALL NOT alter slot compaction, `visible_instance_count`, or region bucket capacity for live instances beyond the reserved tombstone slot.

#### Scenario: Unit destroyed in fog leaves tombstone
- **WHEN** a frozen enemy unit is destroyed while its cell is in fog
- **THEN** its frozen MultiMesh instance persists at the last-known position

#### Scenario: Tombstone released on reveal
- **WHEN** the cell holding a tombstone becomes visible
- **THEN** the tombstone instance is released and its slot returns to normal bookkeeping

#### Scenario: Tombstone released on fog toggle-off
- **WHEN** fog_of_war is toggled off at runtime
- **THEN** all tombstones are released

### Requirement: Per-socket turret instances
The renderer SHALL support zero or more socket instances per registered entity alongside its body instance. A socket instance's transform SHALL be the entity world transform composed with the socket pivot and the current socket yaw (fixed sockets use the rest orientation). Socket instances SHALL share the body's lifecycle atomically: on registration they are allocated in the same region as the body; on unregister every socket slot is released together; on cross-region migration the body and all its sockets move as one group; and on fog the group is parked or frozen together and released together from tombstones. Slot ownership SHALL be resolved per bucket so that two sockets sharing a mesh key on one entity do not corrupt each other's slot index during compaction. Placeholder socket meshes SHALL be generated box meshes bucketed under a synthetic key until a real turret model is available.

#### Scenario: Sockets allocated with the body
- **WHEN** a unit with sockets registers
- **THEN** the body and one instance per socket are allocated in the same region

#### Scenario: Sockets follow body yaw and hold their own yaw
- **WHEN** a registered unit turns its body and its turret yaw changes
- **THEN** each socket instance transform reflects both the body transform and its own yaw

#### Scenario: Fixed socket uses rest orientation
- **WHEN** a unit with a fixed socket is rendered
- **THEN** that socket instance uses the socket pivot without yaw

#### Scenario: Group migrates atomically
- **WHEN** a unit with sockets crosses a region boundary
- **THEN** the body and every socket instance migrate to the new region together

#### Scenario: Group frozen and released in fog
- **WHEN** a unit with sockets is hidden or frozen by fog and later destroyed in fog
- **THEN** its sockets are parked or frozen with the body and released together when the ghost is released

#### Scenario: Twin sockets do not corrupt slots
- **WHEN** one entity has two sockets that share the same placeholder mesh key and a different entity is released
- **THEN** both of the first entity's socket slot indices remain correct after compaction

#### Scenario: Placeholder box rendered
- **WHEN** a socket has no turret model yet
- **THEN** a generated placeholder box mesh is rendered at the socket transform

