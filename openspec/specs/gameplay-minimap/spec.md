# gameplay-minimap Specification

## Purpose

Give players a persistent top-down view of the battlefield from the gameplay HUD: a baked terrain image composed with the local player's fog state, resource and entity overlays, and the camera viewport outline. The displayed area is cropped to the revealable play diamond — the map diamond inset by the visible-bounds insets — and oriented to match the gameplay camera, so the minimap reads the same way as the world. Left-clicks route through the normal order funnel, issuing the same orders as a world click and otherwise snap-panning the camera.

## Requirements

### Requirement: Minimap surface in the gameplay HUD

The gameplay HUD SHALL display a minimap during normal gameplay: a top-down rendering of the playable area (the map diamond inset by the visible-bounds insets) that is centered in the right-hand HUD column, below the credit display and above the Sidebar build panel. The minimap SHALL be at most 200 pixels along its longer axis. It SHALL render, in order from bottom to top: terrain color, the player's fog state (shroud/fog/visible), resource and overlay objects, entities, and the gameplay camera view rectangle. The minimap SHALL NOT be created or rendered while the runtime MapEditor scene is active.

#### Scenario: Minimap appears during gameplay

- **WHEN** a normal gameplay map is loaded
- **THEN** a minimap no larger than 200x200 pixels is visible in the right-hand HUD column, below the credit display and above the Sidebar build panel

#### Scenario: Minimap reflects the playable area

- **WHEN** the terrain grid is initialized with a `grid_cells` size and visible-bounds insets
- **THEN** the minimap's rendered area covers the revealable play area (the map diamond inset by those insets) and the permanently-shrouded rim outside it is not rendered

#### Scenario: Minimap absent in the map editor

- **WHEN** the runtime MapEditor scene is active
- **THEN** no gameplay minimap is present in its HUD

### Requirement: Minimap orientation and aspect

The minimap SHALL be oriented to match the gameplay view: the playable area SHALL be rendered as an axis-aligned rectangle, not as a rotated diamond. The minimap's width:height SHALL equal the play-area diagonal ratio `(2W - left - right):(2H - top - bottom)`, and its display size SHALL be derived from that aspect within a fixed maximum. Click mapping and the camera view rectangle SHALL use the same orientation and aspect transform as the rendered map.

#### Scenario: Play diamond renders axis-aligned

- **WHEN** the terrain grid is initialized
- **THEN** the playable area is drawn as an axis-aligned rectangle whose edges follow the control's horizontal and vertical axes

#### Scenario: Aspect matches the play area

- **WHEN** the map `grid_cells` is not square (for example 100x50) and the visible-bounds insets are zero
- **THEN** the minimap control's width:height is 2:1, matching the play area

#### Scenario: Shrouded rim is cropped

- **WHEN** the visible-bounds insets are non-zero
- **THEN** the inset play area (not the full map diamond) fills the minimap, with no permanent-shroud margin

#### Scenario: Clicks use the orientation transform

- **WHEN** the player left-clicks the centre of a minimap texel
- **THEN** the resolved cell is the cell rendered at that texel

### Requirement: Terrain color bake

The minimap SHALL bake terrain colors once when the terrain grid initializes, producing one color per in-diamond cell. A cell's color SHALL be resolved from the terrain color pipeline: the cell's terrain art via `TerrainCatalog.get_cell_art`, combined with the cell's painted land type via `TerrainArtData.minimap_color`, then shaded by the cell's normalized height ratio across the active theater's low/high radar brightness via `TerrainArtData.shade_map_color`. The land type used for terrain color SHALL be the painted land type only; the resource-derived land type SHALL NOT color terrain, because resources are rendered as overlay objects instead. Cells whose resolved color is null SHALL be transparent. The terrain bake SHALL be rebuilt when a new terrain grid initializes.

#### Scenario: Painted land type colors terrain

- **WHEN** a cell has a painted land type (for example road or rough) and no authored terrain art color
- **THEN** the minimap texel for that cell uses the painted land type's color

#### Scenario: Authored terrain art color wins over land type

- **WHEN** a cell's terrain art defines a minimap color
- **THEN** the minimap texel for that cell uses the authored art color instead of the land type color

#### Scenario: Resource cells are not terrain-colored

- **WHEN** a cell resolves to the resource-derived land type
- **THEN** the terrain bake does NOT use the resource land type color for that cell

#### Scenario: Height shades terrain color

- **WHEN** two cells share a base color but differ in height ratio
- **THEN** the higher cell's minimap texel is brighter, interpolated between the active theater's low and high radar brightness

#### Scenario: Rebake on new grid

- **WHEN** a new map's terrain grid initializes
- **THEN** the minimap terrain bake is regenerated for the new grid dimensions and cell colors

### Requirement: Overlay and fog bake at low frequency

The minimap SHALL refresh its entities, overlay objects, and fog state at a fixed low frequency, reusing the terrain bake as the base layer. On each refresh the minimap SHALL compose, for every in-diamond cell, the terrain color multiplied by the local player's fog factor from `ShroudSystem`: shroud cells SHALL be black, explored-but-not-visible cells SHALL be dimmed, and visible cells SHALL be shown at full terrain brightness. Entities in the `entities` group and resource/overlay objects carrying a `ResourceComponent` SHALL be drawn as dots colored by their minimap color: `ArtData.minimap_color` for entities with art, falling back to the resource type's color for resource overlays that carry no art (tiberium crystals). Each dot SHALL be sized by the entity's footprint: an entity with a `FoundationComponent` SHALL cover one texel per foundation cell, and all other entities SHALL cover a single texel. An entity or overlay object SHALL be omitted when its cell is shrouded, dimmed when its cell is in fog, and drawn at full color when its cell is visible. The refresh SHALL honor the `shroud_enabled` and `fog_of_war` rules toggles consistently with the world fog rendering.

#### Scenario: Shrouded cells are black

- **WHEN** a cell has never been explored by the local player
- **THEN** its minimap texel is black on the next refresh

#### Scenario: Explored cells are dimmed, visible cells are bright

- **WHEN** a cell has been explored but is not currently visible, and an adjacent cell is currently visible
- **THEN** the explored cell is dimmed and the visible cell is drawn at full terrain brightness

#### Scenario: Entities are fog-gated

- **WHEN** an entity's cell is shrouded for the local player
- **THEN** the entity is not drawn on the minimap; when its cell is in fog it is drawn dimmed, and when visible it is drawn at full color

#### Scenario: Overlay objects are included

- **WHEN** a resource or overlay object with a `ResourceComponent` is revealed to the local player
- **THEN** it is drawn on the minimap using its minimap color (`ArtData.minimap_color`, or the resource type color when the overlay carries no art)

#### Scenario: Footprint sizes the dot

- **WHEN** a building with a multi-cell foundation is revealed to the local player
- **THEN** its minimap dot covers one texel per foundation cell, while a unit covers a single texel

#### Scenario: Fog toggles are honored

- **WHEN** `shroud_enabled` is false, or `fog_of_war` is false
- **THEN** the minimap's fog composition matches the world fog rendering for those toggle states

### Requirement: Minimap view rectangle

The minimap SHALL draw the gameplay camera's current ground footprint as a rectangle overlay, updated every frame as the camera moves, so the player can see which part of the map is on screen. Each edge SHALL be clipped to the minimap's rectangle and only its visible segments drawn, so a view footprint larger than the minimap shows only the parts of its own edges that are inside, without drawing edges along the minimap border.

#### Scenario: View rectangle tracks the camera

- **WHEN** the gameplay camera pans to a new position
- **THEN** the view rectangle drawn on the minimap moves to the corresponding minimap position

#### Scenario: View rectangle reflects zoom

- **WHEN** the gameplay camera zooms in or out
- **THEN** the size of the view rectangle on the minimap changes to match the camera's covered ground area

#### Scenario: View rectangle is clipped

- **WHEN** the camera view footprint extends beyond the minimap bounds
- **THEN** only the portion of the view rectangle inside the minimap rectangle is drawn

### Requirement: Minimap click commands and navigation

A left-click on the minimap SHALL map the click position to a play-area cell and then: if the current selection produces at least one valid order for the targeted cell or entity, the minimap SHALL issue the same orders that the same click would issue in the gameplay area, including order-confirmation voice playback and active modifiers (queue, force-attack, force-move); otherwise the minimap SHALL snap-pan the gameplay camera to the clicked cell. The target cell's entity, if any, SHALL be resolved only from entities revealed to the local player. Entities SHALL NOT be selectable from the minimap. Build and placing modes SHALL NOT apply to minimap clicks: a minimap click SHALL NOT place a building or unit. Right-click on the minimap SHALL NOT be handled by the minimap.

#### Scenario: Click issues a move order when units are selected

- **WHEN** a player has units selected and left-clicks a revealed empty cell on the minimap
- **THEN** the selection is issued the same move order it would receive from clicking that location in the gameplay area

#### Scenario: Click issues an attack order on a revealed enemy

- **WHEN** a player has combat units selected and left-clicks a revealed enemy entity's minimap dot
- **THEN** the selection is issued the same attack order it would receive from clicking that entity in the gameplay area

#### Scenario: Snap-pan when no order applies

- **WHEN** a player has nothing selected, or no valid order is produced, and left-clicks the minimap
- **THEN** the gameplay camera centers on the clicked cell

#### Scenario: Entities are not selectable from the minimap

- **WHEN** a player left-clicks a friendly entity's minimap dot with nothing selected
- **THEN** that entity is not selected

#### Scenario: Build mode does not place from the minimap

- **WHEN** the player is in building placement mode and left-clicks the minimap
- **THEN** no building is placed and the click behaves as a navigation click

#### Scenario: Shrouded targets cannot be ordered

- **WHEN** a player left-clicks a minimap dot whose cell is shrouded for the local player
- **THEN** no entity-target order is issued for that dot

### Requirement: Minimap input ownership

While the pointer is over the minimap, gameplay world input handlers SHALL NOT process mouse clicks, so a minimap click does not also select, order, or place in the world. This SHALL cover the selection/order handler, the building placement handler, and the free-placement handler.

#### Scenario: World selection is suppressed over the minimap

- **WHEN** the player left-clicks while the pointer is over the minimap
- **THEN** the world selection/order handler does not process that click

#### Scenario: World placement is suppressed over the minimap

- **WHEN** the player left-clicks the minimap while in building placement mode
- **THEN** the building placement handler does not process that click
