# terrain-cell-pins Specification

## Purpose

Cliff geometry must stay fixed while neighboring terrain is graded. A cell pin records an explicit `TerrainObject` id for a cell and locks that cell's vertices against height edits, so the editor can stamp a cliff and later raise or flatten terrain around it without the cliff deforming. The sparse overlay round-trips through map JSON alongside the other terrain keys.

## Requirements

### Requirement: Cell pin API
`TerrainSystem` SHALL store a sparse `_cell_pins` overlay mapping a cell to a `TerrainObject` id. It SHALL expose `pin_cell(cell, object_id)`, `unpin_cell(cell)`, `get_pin(cell) -> String`, and `is_cell_pinned(cell)`. Pinning SHALL be rejected for cells outside the playable diamond. Pinning or unpinning a tracked cell SHALL emit `cell_changed` so the renderer re-resolves it. `clear()` SHALL reset the overlay.

#### Scenario: Pin and read back
- **WHEN** an in-diamond cell is pinned to `"cliff01_n"`
- **THEN** `get_pin(cell)` returns `"cliff01_n"` and `is_cell_pinned(cell)` is true

#### Scenario: Unpin
- **WHEN** a pinned cell is unpinned
- **THEN** `get_pin(cell)` returns `""`, `is_cell_pinned(cell)` is false, and a second unpin reports no pin

#### Scenario: Outside the diamond rejected
- **WHEN** `pin_cell` is called for a cell outside the playable diamond
- **THEN** it returns false and no pin is recorded

### Requirement: Pinned cells lock height edits
A pinned cell SHALL reject direct height mutations: `raise_cell` and `lower_cell` SHALL be no-ops on a pinned cell. At vertex granularity, any vertex shared by a pinned cell SHALL be non-editable, so `set_vertex` and `flatten_footprint` SHALL skip it. The slope cascade SHALL stop at locked vertices while still re-sloping editable neighbors, keeping the stamped cliff geometry constant.

#### Scenario: Raise and lower on a pinned cell
- **WHEN** `raise_cell` or `lower_cell` is applied repeatedly to a pinned cell
- **THEN** its four corner heights are unchanged

#### Scenario: Editing beside a pinned cell
- **WHEN** a cell sharing two corners with a pinned cell is raised
- **THEN** the two shared corners keep their values and only the free corners rise

#### Scenario: Flatten skips pinned vertices
- **WHEN** a footprint overlapping a pinned cell is flattened
- **THEN** the pinned cell's corners keep their values while editable vertices in the region level

#### Scenario: Cascade stays legal around a pin
- **WHEN** terrain next to a pinned cliff is raised
- **THEN** the locked cliff corners keep their height and neighbors stay at or below the cliff top

### Requirement: Pin persistence in map JSON
`TerrainSystem.export_to_json` SHALL write the `_cell_pins` overlay as a `"cell_pins"` object, omitting the key when the overlay is empty. `import_from_json` SHALL restore pins for cells inside the diamond. A map without a `"cell_pins"` key SHALL load with no pins.

#### Scenario: Round-trip
- **WHEN** a map with two pinned cells is exported and re-imported
- **THEN** both pins and their vertices are restored

#### Scenario: Absent key loads clean
- **WHEN** a map exported with no pins is imported
- **THEN** no cells are pinned

### Requirement: Stamp-to-grid consumer applies a TerrainObject
The system SHALL provide a runtime consumer that stamps a `TerrainObject` to the terrain grid: for each of the object's `cells` it SHALL apply the cell's `land` type and its four absolute `corners` (`[nw, ne, se, sw]`) to the grid and renderer. The object SHALL be placed at a cell origin with an orientation, and its object-local `"x,z"` cell keys SHALL map onto absolute grid cells. Stamping a bridge end SHALL produce the authored cliff with a road cut through three cells.

#### Scenario: Stamping writes land and corners
- **WHEN** a `TerrainObject` is stamped at a placement
- **THEN** each covered cell's land type and corner heights equal the object's authored values

#### Scenario: Object-local cells map to absolute cells
- **WHEN** an object with cells keyed `"0,0"`, `"1,0"`, `"2,0"` is stamped at origin `(x, z)`
- **THEN** the three cells land at `(x, z)`, `(x+1, z)`, `(x+2, z)`

#### Scenario: Road cut spans three cells
- **WHEN** a high-bridge end object is stamped
- **THEN** its road cut occupies three cells at road grade

### Requirement: Stamped cells are pinned via cell_pins
Stamping SHALL pin every affected cell using the existing `TerrainSystem.pin_cell(cell, object_id)` overlay so later height edits do not deform the stamped geometry. Pinned cells SHALL reject `raise_cell`/`lower_cell` and vertex edits, matching the existing pin semantics. The pin SHALL record the stamped object id.

#### Scenario: Stamped cells pinned
- **WHEN** a `TerrainObject` is stamped
- **THEN** each affected cell is pinned to that object's id

#### Scenario: Later edits do not deform the stamp
- **WHEN** terrain next to a stamped bridge end is raised
- **THEN** the stamped cells' corners keep their authored values

#### Scenario: Object id recorded
- **WHEN** `get_pin(cell)` is called on a stamped cell
- **THEN** it returns the stamped object's id

### Requirement: Stamp persistence through cell_pins
Stamped bridge ends SHALL persist through the existing `cell_pins` map JSON without a new JSON section. `TerrainSystem.export_to_json` SHALL continue to write the `_cell_pins` overlay as `"cell_pins"`, and `import_from_json` SHALL restore the pins, re-resolving the stamped object's `land` and `corners` so the bridge end is rebuilt on load. A map without a `"cell_pins"` key SHALL load with no stamped ends.

#### Scenario: Stamp round-trips
- **WHEN** a map with a stamped bridge end is exported and re-imported
- **THEN** the end cells and their geometry are restored from the pins

#### Scenario: No new JSON section
- **WHEN** a map with stamped bridge ends is exported
- **THEN** the ends appear under `"cell_pins"` and no new bridge-ends key is written

#### Scenario: Absent key loads clean
- **WHEN** a map exported with no pins is imported
- **THEN** no cells are pinned or stamped
