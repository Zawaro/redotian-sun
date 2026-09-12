## ADDED Requirements

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
