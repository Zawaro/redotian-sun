# fog-rendering Specification

## Purpose

Visual shroud/fog/visible overlay (world-aligned plane + incremental grid texture) and fog-driven entity culling, driven by the ShroudSystem fog grid.

## Requirements

### Requirement: VisionComponent revealer wiring
The system SHALL attach a `VisionComponent` to every player-owned entity (EntityType INFANTRY, VEHICLE, AIRCRAFT, or BUILDING) with `sight > 0`. The component SHALL register a revealer with ShroudSystem (`register_revealer`) for its owner, and SHALL unregister it (`unregister_revealer`) when the entity leaves the scene tree. Revealer radius SHALL be the entity's `sight` value. `blocks_terrain` SHALL be false for AIRCRAFT and BUILDING and true otherwise. Viewer height SHALL be the entity's world-space position height plus an eye offset, so a unit's own plateau does not block its own sight.

#### Scenario: Unit registers a revealer on spawn
- **WHEN** a unit with `sight > 0` and an assigned player spawns
- **THEN** a revealer of radius `sight` is registered for that player at the unit's cell, and cells within radius resolve to visible

#### Scenario: Unit unregisters on death
- **WHEN** a registered unit is freed or removed from the scene tree
- **THEN** its revealer is unregistered and the cells it covered revert to fog (never shroud, if explored)

#### Scenario: Building registers permanently
- **WHEN** a building with `sight > 0` spawns
- **THEN** it registers exactly once and does not re-stamp while it remains in the tree

#### Scenario: Terrain and overlay entities are not revealers
- **WHEN** a TERRAIN or OVERLAY entity spawns with the default `sight = 1`
- **THEN** no revealer is registered for it

### Requirement: Revealer re-stamps on cell crossing
A registered dynamic unit SHALL poll its cell each physics frame and re-register its revealer (unregister at the old cell, register at the new) only when it crosses a cell boundary. A stationary unit SHALL NOT re-stamp. Registration SHALL be deferred until the entity has an assigned player (never register with `player_id` unset).

#### Scenario: Unit crosses a cell boundary
- **WHEN** a registered unit moves from cell A to cell B
- **THEN** its revealer is re-registered at cell B, cell A loses its visibility contribution, and cell B gains it with no leaked counts

#### Scenario: Stationary unit does not re-stamp
- **WHEN** a registered unit remains in the same cell for multiple physics frames
- **THEN** no re-registration occurs

#### Scenario: Deferred registration until owner assigned
- **WHEN** an entity is added to the tree before its player is assigned
- **THEN** it does not register until the first physics frame where a valid player id is present

### Requirement: Fog overlay plane
The system SHALL render a world-aligned `MeshInstance3D` plane spanning the terrain grid, positioned just above the maximum terrain height, with a spatial shader material that samples a grid-resolution `ImageTexture` built from `ShroudSystem.get_effective_state(local_player)`. Cells resolving to visible SHALL render fully transparent (fragment discarded); fog cells SHALL render dimmed (dark translucent); shroud cells SHALL render opaque black. Out-of-play cells SHALL render opaque black. L8 state bytes (0/1/2) SHALL be scaled back to their byte values when sampled in the shader so the 0.5/1.5 thresholds classify correctly.

#### Scenario: Visible cells transparent
- **WHEN** a cell resolves to visible
- **THEN** the plane fragment over that cell is discarded, leaving terrain and units fully visible

#### Scenario: Fog cells dimmed
- **WHEN** a cell resolves to fog (explored, not visible)
- **THEN** the plane draws dark translucent black over that cell

#### Scenario: Shroud cells opaque
- **WHEN** a cell resolves to shroud (unexplored)
- **THEN** the plane draws opaque black over that cell

#### Scenario: Texture rebuilt only on change
- **WHEN** ShroudSystem emits `state_changed` and the local player's effective state buffer differs from the previously built buffer
- **THEN** the texture is rebuilt; when the buffer is unchanged (e.g. only an enemy player's cells resolved), no rebuild occurs

### Requirement: Fog-driven unit culling
Enemy units SHALL be hidden, ghosted, or drawn based on their cell's state relative to the local player: cells not visible to the local player SHALL hide the unit when unexplored (shroud), SHALL freeze it at its last-known rendered position when explored (fog) so a ghost persists where it was last seen, and SHALL draw it normally when visible. Culling SHALL be visual-only (the unit's renderer instance is parked or frozen; simulation and combat remain active). Friendly units and units with no assigned player SHALL never be hidden or frozen. Culling SHALL be inert only when both `shroud_enabled` and `fog_of_war` are false; with shroud off and fog on, an unexplored-cell unit SHALL draw normally, and with shroud on and fog off, an explored-but-not-visible-cell unit SHALL draw normally.

#### Scenario: Enemy unit hidden in shroud
- **WHEN** an enemy unit's cell is unexplored (shroud) by the local player
- **THEN** its rendered instance is parked off-world and not drawn

#### Scenario: Enemy unit ghosted in fog
- **WHEN** an enemy unit's cell is explored but not currently visible (fog) by the local player
- **THEN** its rendered instance is frozen at the last-known position rather than parked or hidden

#### Scenario: Ghost persists while fogged
- **WHEN** an enemy unit moves within fog of war
- **THEN** its rendered instance stays frozen at the position where it entered fog (no transform sync, no region migration)

#### Scenario: Enemy unit reappears when visible
- **WHEN** an enemy unit's cell becomes visible to the local player
- **THEN** its rendered instance snaps to its current position and resumes per-frame sync

#### Scenario: Friendly unit never hidden
- **WHEN** a friendly unit's cell is shrouded
- **THEN** its rendered instance remains drawn

#### Scenario: Culling inert only when both toggles off
- **WHEN** `shroud_enabled` and `fog_of_war` are both false
- **THEN** no unit is hidden or frozen by culling

#### Scenario: Fog off shows explored-cell units
- **WHEN** `shroud_enabled` is true and `fog_of_war` is false, and an enemy unit's cell is explored but not visible
- **THEN** the unit draws normally (no ghost) because only the shroud layer is active

### Requirement: Fog-driven building culling
Enemy buildings SHALL be shown once their cell is explored, and SHALL remain shown while the cell stays explored even when no revealer currently covers it. Enemy buildings in unexplored (shroud) cells SHALL be visually hidden. Friendly buildings SHALL never be hidden.

#### Scenario: Building persists in fog
- **WHEN** an enemy building's cell is explored but a revealing unit has since left the area
- **THEN** the building remains visible (dimmed by the fog overlay)

#### Scenario: Building hidden before explored
- **WHEN** an enemy building's cell has never been explored
- **THEN** the building is visually hidden

#### Scenario: Friendly building always visible
- **WHEN** a friendly building's cell is unexplored
- **THEN** the building remains visible

### Requirement: Fog-driven culling for all entity types
The visual fog/shroud gates SHALL extend beyond MultiMesh units and buildings to every entity type rendered in the world: enemy decorations (TERRAIN/OVERLAY — Tiberium, trees, rubble), node-tree-fallback units (region bucket full), and any entity not registered with `UnitMeshRenderer` or `FogRenderer` SHALL be visually hidden when their cell is unexplored (shroud) and SHALL keep a last-known visual when explored but not visible (fog). Friendly entities and entities with no assigned player SHALL never be hidden or frozen. Culling SHALL be visual-only (simulation unaffected). The raised opaque shroud sheet (`PLANE_OFFSET`) SHALL depth-occlude ground entities in shrouded cells as the primary mechanism; per-instance visibility gates SHALL cover entities that rise above the sheet.

> **STATUS — OPEN GAP (#276 hide-in-shroud, #275 freeze-in-fog).** Buildings and MultiMesh units are covered today; decorations and fallback-rendered units leak through shroud, and the freeze treatment is not generalized.

#### Scenario: Decoration hidden in shroud
- **WHEN** an enemy Tiberium/tree/rubble decoration's cell is unexplored by the local player
- **THEN** it is not rendered

#### Scenario: Decoration keeps last-known visual in fog
- **WHEN** a decoration's cell is explored but not visible by the local player
- **THEN** it is rendered at its last-known position (static decorations persist naturally)

#### Scenario: Fallback-rendered unit hidden in shroud
- **WHEN** an enemy unit rendered through the node-tree fallback (region bucket full) sits in a shrouded cell
- **THEN** it is hidden, not shown unconditionally

#### Scenario: Entity with no assigned player always visible
- **WHEN** a neutral entity with no player_id is in a shrouded cell
- **THEN** it remains rendered

#### Scenario: Reveal restores culled entities
- **WHEN** a shrouded cell containing culled decorations or fallback units becomes visible
- **THEN** all of them render again

### Requirement: Independent shroud and fog toggles
The system SHALL expose two independent master toggles via `GlobalRules`: `shroud_enabled` (default `true`) and `fog_of_war` (default `false`). Shroud governs the opaque-black unexplored layer and the hiding of entities in unexplored cells; fog of war governs the translucent dim layer over explored-but-not-visible cells and unit ghosting. When shroud is disabled, unexplored cells and their entities render normally. When fog of war is disabled, explored-but-not-visible cells and their entities render normally (no dim, no ghost). When both are disabled the fog plane is hidden and no entity culling or freezing occurs. Toggling either flag at runtime SHALL take effect immediately on the plane and on entity culling.

#### Scenario: Shroud on, fog off (defaults)
- **WHEN** `shroud_enabled` is true and `fog_of_war` is false
- **THEN** unexplored cells render opaque black and hide their entities, while explored cells and their entities render normally

#### Scenario: Shroud off, fog on
- **WHEN** `shroud_enabled` is false and `fog_of_war` is true
- **THEN** unexplored cells render normally, while explored-but-not-visible cells render dimmed and ghost their units

#### Scenario: Both disabled
- **WHEN** both toggles are false
- **THEN** the fog plane is hidden, every cell renders normally, and no entity is hidden or frozen

#### Scenario: Runtime toggle takes effect
- **WHEN** a toggle changes while the game is running
- **THEN** the plane and entity culling reflect the new configuration immediately

### Requirement: Soft-edged shroud and fog borders
The fog overlay SHALL soften the transitions between shroud, fog, and visible cells: a shroud cell SHALL be fully opaque black across its entire footprint, and a fog cell SHALL be fully dimmed at `fog_darkness` across its entire footprint, while the border between regions SHALL ramp smoothly over a tunable width (in cells) rather than a hard step — from the covered region's full intensity at its cell edge to fully transparent `*_falloff` cells out into the visible area, where visible cells within the ramp are dimmed toward the adjacent region's intensity instead of discarded. The L8 state texture SHALL keep nearest filtering so classification stays crisp. Fragments outside the map square (the rim mesh, UVs outside `[0,1]`) SHALL render opaque shroud regardless.

> **STATUS — OPEN GAP (#274).** The initial signed-distance-field implementation (Decision 9, tasks 9.1–9.6) and a later boundary-ribbon mesh were both reverted for look/perf; hard cell edges are the current shipped behavior. The re-implementation must stay single-draw with no per-frame CPU bake.

#### Scenario: Shroud cell fully covered
- **WHEN** a shroud cell resolves to shroud
- **THEN** the plane draws it opaque black across its entire footprint, with no partial transparency inside the cell

#### Scenario: Shroud border halo
- **WHEN** an explored or visible cell is within `shroud_falloff` cells of a shroud cell's edge
- **THEN** it is dimmed from full opacity at the shroud cell's edge, via an S-curve ramp, to fully transparent at `shroud_falloff` cells out

#### Scenario: Fog cell fully dim
- **WHEN** a fog cell resolves to fog
- **THEN** the plane dims it at `fog_darkness` across its entire footprint

#### Scenario: Fog trail halo
- **WHEN** a visible cell is within `fog_falloff` cells of a fog cell's edge — a unit's receding vision edge
- **THEN** it is dimmed from full dim at the fog cell's edge, via an S-curve ramp, to fully transparent at `fog_falloff` cells out

#### Scenario: Deep visible cells clean
- **WHEN** a visible cell carries no shroud or fog halo
- **THEN** the plane draws nothing over it (fully transparent)

#### Scenario: Rim stays opaque shroud
- **WHEN** a fragment lies outside the map square, where the textures hold no state
- **THEN** the plane draws opaque shroud regardless of the distance texture

### Requirement: Debug menu fog and shroud controls
The debug menu SHALL provide a dedicated section with a shroud checkbox (checked by default), a fog-of-war checkbox (unchecked by default), a reveal-shroud button, and a cover-shroud button. The checkboxes SHALL flip `GlobalRules.shroud_enabled` / `GlobalRules.fog_of_war` at runtime. The reveal button SHALL mark every in-play-area cell explored (`explore_all` for the local player, clamped to `BoundsSystem.is_in_play_area`). The cover button SHALL revert every cell of the local player and its allies to unexplored except cells currently within an active allied/own revealer's radius (`cover_shroud`), which stay explored (and visible).

#### Scenario: Reveal shroud button
- **WHEN** the reveal-shroud button is pressed
- **THEN** all in-play-area cells become explored for the local player

#### Scenario: Cover shroud button
- **WHEN** the cover-shroud button is pressed with an active revealer at cell C
- **THEN** cells in C's radius remain explored, and previously explored cells outside any active revealer revert to unexplored

#### Scenario: Checkbox initial state
- **WHEN** the debug menu opens on a fresh scene
- **THEN** the shroud checkbox is checked and the fog-of-war checkbox is unchecked
