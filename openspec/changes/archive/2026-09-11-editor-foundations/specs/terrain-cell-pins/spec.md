## ADDED Requirements

### Requirement: Cell pin API
`TerrainSystem` SHALL store a sparse `_cell_pins` overlay mapping a cell to a
`TerrainObject` id. It SHALL expose `pin_cell(cell, object_id)`,
`unpin_cell(cell)`, `get_pin(cell) -> String`, and `is_cell_pinned(cell)`.
Pinning SHALL be rejected for cells outside the playable diamond. Pinning or
unpinning a tracked cell SHALL emit `cell_changed` so the renderer re-resolves
it. `clear()` SHALL reset the overlay.

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
A pinned cell SHALL reject direct height mutations: `raise_cell` and
`lower_cell` SHALL be no-ops on a pinned cell. At vertex granularity, any vertex
shared by a pinned cell SHALL be non-editable, so `set_vertex` and
`flatten_footprint` SHALL skip it. The slope cascade SHALL stop at locked
vertices while still re-sloping editable neighbors, keeping the stamped cliff
geometry constant.

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
`TerrainSystem.export_to_json` SHALL write the `_cell_pins` overlay as a
`"cell_pins"` object, omitting the key when the overlay is empty.
`import_from_json` SHALL restore pins for cells inside the diamond. A map
without a `"cell_pins"` key SHALL load with no pins.

#### Scenario: Round-trip
- **WHEN** a map with two pinned cells is exported and re-imported
- **THEN** both pins and their vertices are restored

#### Scenario: Absent key loads clean
- **WHEN** a map exported with no pins is imported
- **THEN** no cells are pinned
