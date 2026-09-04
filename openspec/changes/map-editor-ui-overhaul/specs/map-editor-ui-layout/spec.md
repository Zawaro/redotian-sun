## ADDED Requirements

### Requirement: Four-region editor layout
The map editor UI SHALL be laid out as four regions under a full-rect root control in the existing `EditorUI` CanvasLayer: a left sidebar spanning the full viewport height (~340px wide), a top tool bar occupying the remaining width above the viewport, a bottom LAT-group bar occupying the remaining width below the viewport, and a top-right column overlay (minimap, info box, EntityProperties). The 3D viewport SHALL remain interactive in the area not covered by UI.

#### Scenario: Layout on editor open
- **WHEN** the map editor scene opens
- **THEN** the left sidebar, top bar, bottom bar, and top-right column are all visible, and the world viewport receives mouse input only where no Control is hovered

#### Scenario: GUI blocks world input
- **WHEN** the cursor hovers any editor UI control
- **THEN** world input handlers (tool dispatch, selection) do not receive the event

### Requirement: Preview pane region and toggle
The left sidebar SHALL reserve a bottom strip (~220px) as the preview pane. The pane SHALL be open by default and toggleable from the View menu; toggling hides the strip and returns the space to the object tree.

#### Scenario: Open by default
- **WHEN** the map editor opens
- **THEN** the preview pane is visible at the bottom of the sidebar

#### Scenario: Toggle closed
- **WHEN** the player toggles the preview pane off in the View menu
- **THEN** the pane is hidden and the object tree expands into the reclaimed space

#### Scenario: Toggle reopens
- **WHEN** the player toggles the preview pane back on
- **THEN** the pane is visible again at the bottom of the sidebar

### Requirement: Editor info box
The editor SHALL display an info box in the top-right column beneath the minimap that shows the hovered cell's coordinates, base height, land type, and any object id on that cell. Values SHALL update while the cursor moves over the world.

#### Scenario: Hovering a cell
- **WHEN** the cursor hovers a cell inside the playable diamond
- **THEN** the info box shows that cell's coordinates, height, land type, and object id (or an empty-object indicator)

#### Scenario: Cursor outside the map
- **WHEN** the cursor leaves the playable diamond
- **THEN** the info box shows empty/placeholder values rather than stale data

### Requirement: EntityProperties docking
The floating EntityProperties panel SHALL be re-docked into the top-right column directly below the info box, keeping its current selection-driven behavior.

#### Scenario: Properties panel placement
- **WHEN** the map editor opens
- **THEN** EntityProperties renders inside the top-right column below the info box instead of floating at a hardcoded position
