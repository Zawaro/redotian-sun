## ADDED Requirements

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

> **Note — generalization gap (#275/#276):** these hide/freeze mechanics cover MultiMesh units only. Buildings use `entity.visible` (fog-rendering "Fog-driven building culling"); decorations, node-tree-fallback units, and unregistered entities are not covered — see fog-rendering "Fog-driven culling for all entity types".
