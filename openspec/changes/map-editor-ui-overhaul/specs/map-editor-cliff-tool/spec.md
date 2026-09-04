## ADDED Requirements

### Requirement: Vector cliff path drawing
The Cliff tool SHALL let the player drag a polyline through cell space; while drawing, a live preview line SHALL render along the path. Cancel (sub-bar button or right-click) SHALL discard the path without changing the map. Activating the tool SHALL reveal the CliffSubBar (Ramp toggle, Cancel, Accept).

#### Scenario: Path preview
- **WHEN** the player drags with the Cliff tool
- **THEN** a preview line follows the dragged path through cells

#### Scenario: Cancel discards
- **WHEN** the player clicks Cancel after drawing a path
- **THEN** the preview disappears and the map is unchanged

### Requirement: Cliff stamping on Accept
On Accept, the tool SHALL stamp cliff-family pieces along the path: for each covered cell it SHALL write the piece's baked corner heights into the vertex grid, set the piece's per-cell land types, and pin the cell to the piece's object id. Stamping SHALL clamp out-of-bounds paths and SHALL warn (not crash) when a cell is already pinned.

#### Scenario: Stamp writes geometry and pins
- **WHEN** the player accepts a 3-cell cliff path
- **THEN** those cells' vertices match the cliff pieces' corner heights, their land types match the pieces, and each cell is pinned to its piece's object id

#### Scenario: Accept over an existing pin
- **WHEN** an accepted path crosses an already-pinned cell
- **THEN** the editor warns and skips that cell (or repins it), never corrupting the grid

### Requirement: Ramp caps
When the Ramp toggle is enabled, the tool SHALL stamp a ramp piece as the path's end cap instead of a raw cliff end, mating the cliff wall to walkable ground via the piece's edge connection roles.

#### Scenario: Ramp end cap
- **WHEN** the player draws a path with Ramp enabled and accepts
- **THEN** the path's end cell resolves to the ramp piece for the path's end direction

### Requirement: Pinned cells lock height editing
Cells pinned by the cliff tool SHALL reject height mutations: raise, lower, flatten, and combined raise/lower SHALL skip pinned cells and the vertices they share. The cascade SHALL still re-slope unpinned neighbor cells around the cliff. LAT painting SHALL also skip pinned cells when "Only paint on clear" is enabled.

#### Scenario: Raise skips pinned cell
- **WHEN** the player raises ground on a region containing a pinned cell
- **THEN** the pinned cell's vertices are unchanged while unpinned neighbors rise

#### Scenario: Cascade still reaches neighbors
- **WHEN** a pinned cell's unpinned neighbor is raised repeatedly
- **THEN** the neighbor re-slopes toward the cliff without changing the cliff's vertices

### Requirement: Delete mode scope
The Delete tool SHALL remove, for each brushed cell: any entity (including tiberium resource entities), any terrain object or smudge/overlay entity, any waypoint, and any cell pin. Delete SHALL NOT modify land types or heights — surface editing stays with the LAT and height tools. Unpinned cells return to height-derived resolution.

#### Scenario: Unpin restores derived resolution
- **WHEN** the player deletes over a pinned cell
- **THEN** the pin is cleared and the cell's mesh resolves from its height data again

#### Scenario: Tiberium crystals are deleted
- **WHEN** the player deletes over a cell holding a placed tiberium resource entity
- **THEN** the resource entity is removed like any other entity

#### Scenario: Ground is untouched
- **WHEN** the player deletes over painted ground
- **THEN** the cell's land type and vertex heights are unchanged

### Requirement: Pins persist in map JSON
`TerrainSystem.export_to_json` SHALL write cell pins as `"cell_pins": {"<cell_key>": "<object_id>"}` and the loader SHALL restore them. Loading a map without `cell_pins` SHALL leave no pins.

#### Scenario: Round-trip pins
- **WHEN** a map with two pinned cells is exported and reloaded
- **THEN** both cells are pinned to the same object ids and render as cliffs again

#### Scenario: Old maps load clean
- **WHEN** a pre-existing map JSON without `cell_pins` is loaded
- **THEN** no cells are pinned and nothing errors
