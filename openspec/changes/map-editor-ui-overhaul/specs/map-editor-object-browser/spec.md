## ADDED Requirements

### Requirement: Category selector
The left sidebar SHALL provide a category selector (OptionButton) with exactly: Aircraft, Buildings, Vehicles, Infantry, TerrainObjects, Overlay, Smudges. Aircraft/Buildings/Vehicles/Infantry list `EntityData` entries of the matching entity type; TerrainObjects lists TerrainCatalog objects; Overlay and Smudges list `EntityData` entries from the overlay and smudge entity directories.

#### Scenario: Categories present
- **WHEN** the map editor opens
- **THEN** the selector offers the seven categories in the order above with Buildings preselected

#### Scenario: Switching to TerrainObjects
- **WHEN** the player selects "TerrainObjects"
- **THEN** the object tree lists catalog terrain objects instead of entities

#### Scenario: Overlay and smudge categories
- **WHEN** the player selects "Overlay" or "Smudges"
- **THEN** the tree lists the overlay/smudge EntityData entries from `resources/entities/overlay/` and `resources/entities/smudge/`

### Requirement: Owner (house) dropdown
The sidebar SHALL provide an Owner dropdown with GDI, Nod, Neutral, and Special. The selection SHALL be the house assigned to newly placed entities; it SHALL NOT filter the object tree.

#### Scenario: Default owner
- **WHEN** the map editor opens
- **THEN** the owner dropdown selects GDI

#### Scenario: Placed entity receives owner
- **WHEN** an entity is placed while Nod is selected in the owner dropdown
- **THEN** the placed entity's tracked data records house_id "nod"

### Requirement: Faction-collapsible object tree
The object list SHALL render as a Tree with one collapsible root per faction derived from each entry's ownership (`EntityData.owner` for entities, catalog ownership for terrain objects), with member items nested under their faction. An entry owned by multiple factions SHALL appear under every owned faction. Unknown/neutral ownership SHALL group under Neutral.

#### Scenario: Faction groups
- **WHEN** the Buildings category is shown
- **THEN** the tree shows a GDI group and a Nod group (plus Neutral where applicable) and each group expands to its member entities

#### Scenario: Collapse and expand
- **WHEN** the player clicks a faction group header
- **THEN** the group toggles between collapsed and expanded

### Requirement: Search filter with Ctrl+F
The sidebar SHALL provide a search LineEdit. Typing SHALL filter the visible tree items case-insensitively by id or display name substring; clearing SHALL restore the full list. Pressing Ctrl+F anywhere in the editor SHALL focus the search field.

#### Scenario: Filter narrows the tree
- **WHEN** the player types "harv" into the search field
- **THEN** only entries whose id or display name contains "harv" remain visible (e.g. Nod Harvester)

#### Scenario: Ctrl+F focuses search
- **WHEN** the player presses Ctrl+F while not typing in another field
- **THEN** the search field gains keyboard focus

### Requirement: Selection binds the preview pane
Selecting an object tree item SHALL display that entity/terrain object in the preview pane (3D render via the standalone preview pane); clearing the selection SHALL return the pane to its empty placeholder state.

#### Scenario: Preview on selection
- **WHEN** the player selects "Nod Buggy" in the tree
- **THEN** the preview pane renders the Nod Buggy model

#### Scenario: Terrain object preview
- **WHEN** the player selects a TerrainObjects entry
- **THEN** the preview pane renders that object resolved for the active theater

#### Scenario: No selection shows placeholder
- **WHEN** no tree item is selected
- **THEN** the preview pane shows its empty placeholder
