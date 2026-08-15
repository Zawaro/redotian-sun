## MODIFIED Requirements

### Requirement: Fog-driven culling for all entity types
The visual fog/shroud gates SHALL extend beyond MultiMesh units and buildings to every entity type rendered in the world: enemy decorations (TERRAIN/OVERLAY — Tiberium, trees, rubble), node-tree-fallback units (region bucket full), and any entity not registered with `UnitMeshRenderer` or `FogRenderer` SHALL be visually hidden when their cell is unexplored (shroud) and SHALL keep a last-known visual when explored but not visible (fog). The fog freeze SHALL capture the entity's last-known transform (for moving entities) and its current visual state (harvest stage, animation, damage) at the moment its cell enters fog, and SHALL be visual-only (simulation and combat unaffected). Killable overlays (Tiberium harvest-stage visuals, trees, rubble) SHALL freeze their current visual state in fog gated by cell exploration, regardless of player ownership. Friendly entities SHALL never be hidden or frozen. The raised opaque shroud sheet (`PLANE_OFFSET`) SHALL depth-occlude ground entities in shrouded cells as the primary mechanism; per-instance visibility gates SHALL cover entities that rise above the sheet.

> **STATUS — OPEN GAP (#276 hide-in-shroud).** Freeze-in-fog for all entity types and post-destruction ghosts are implemented (#275); decorations and fallback-rendered units still leak through shroud pending #276.

#### Scenario: Decoration hidden in shroud
- **WHEN** an enemy Tiberium/tree/rubble decoration's cell is unexplored by the local player
- **THEN** it is not rendered

#### Scenario: Decoration keeps last-known visual in fog
- **WHEN** a decoration's cell is explored but not visible by the local player
- **THEN** it is rendered at its last-known position (static decorations persist naturally)

#### Scenario: Tiberium harvest stage frozen in fog
- **WHEN** a Tiberium field's cell becomes fog while a harvester is depleting it
- **THEN** its harvest-stage visual stays at the stage it had when the cell left view and does not shrink while fogged

#### Scenario: Building frozen in fog
- **WHEN** an enemy building's cell is explored but not visible
- **THEN** it renders at its footprint with its fog-entry appearance (no door, construction, or damage changes while fogged)

#### Scenario: Fallback-rendered unit hidden in shroud
- **WHEN** an enemy unit rendered through the node-tree fallback (region bucket full) sits in a shrouded cell
- **THEN** it is hidden, not shown unconditionally

#### Scenario: Fallback-rendered unit frozen in fog
- **WHEN** an enemy unit rendered through the node-tree fallback sits in a fog cell
- **THEN** it is frozen at its last-known position instead of following the live simulation

#### Scenario: Reveal un-freezes at real position
- **WHEN** a frozen entity's cell becomes visible
- **THEN** the frozen visual is replaced by the live entity rendered at its current simulated position

#### Scenario: Entity with no assigned player always visible
- **WHEN** a neutral entity with no player_id is in a shrouded cell
- **THEN** it remains rendered

#### Scenario: Reveal restores culled entities
- **WHEN** a shrouded cell containing culled decorations or fallback units becomes visible
- **THEN** all of them render again

## ADDED Requirements

### Requirement: Post-destruction fog ghosts
An entity destroyed, sold, or otherwise removed while its cell is in fog SHALL leave a static "last-known" ghost visual at its last position until the cell is revealed or reverts to shroud. The ghost SHALL be visual-only: no collision, no selection, no targeting, and no effect on simulation. The ghost SHALL be released when the cell becomes visible (revealing the entity's true absence), when the cell reverts to shroud (shroud growth or cover_shroud), when fog is toggled off at runtime, on grid reinit, and on map teardown. A living entity subsequently occupying the same cell SHALL supersede any ghost there. Ghost existence SHALL be derived from cell state and entity liveness, never stored as a sticky flag.

#### Scenario: Building destroyed in fog leaves ghost
- **WHEN** an enemy building is destroyed while its cell is in fog
- **THEN** a static ghost of the building remains at its last position

#### Scenario: Tiberium killed in fog leaves ghost
- **WHEN** a Tiberium crystal is destroyed while its cell is in fog
- **THEN** its last-known visual remains until the cell reveals

#### Scenario: Reveal removes the ghost
- **WHEN** a cell containing a post-destruction ghost becomes visible
- **THEN** the ghost is released and the cell shows the entity is gone

#### Scenario: Shroud revert removes the ghost
- **WHEN** a cell containing a post-destruction ghost reverts to shroud (growth or cover_shroud)
- **THEN** the ghost is released

#### Scenario: Fog toggle-off removes all ghosts
- **WHEN** fog_of_war is toggled off at runtime
- **THEN** every ghost is released and no entity is frozen

#### Scenario: Ghost is not interactive
- **WHEN** a post-destruction ghost overlaps a cursor or order
- **THEN** it is never selected, targeted, or ordered
