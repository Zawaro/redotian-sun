## ADDED Requirements

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
