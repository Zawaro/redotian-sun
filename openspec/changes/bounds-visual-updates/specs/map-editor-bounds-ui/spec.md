## ADDED Requirements

### Requirement: Default map size
MapEditor SHALL initialize with `map_size = Vector2(128, 128)` when opened.

#### Scenario: Default grid on editor open
- **WHEN** the MapEditor opens for the first time
- **THEN** `TerrainSystem.grid_cells` is initialized to `128` and BoundsSystem outer bounds reflect a 128×128 grid

### Requirement: Toolbar offset SpinBox fields
The MapEditor toolbar SHALL display two SpinBox fields: "X Offset" and "Z Offset" in cell units (step=1), controlling the visible bounds offset from the outer bounds. A VSeparator SHALL separate the offset fields from the existing tool buttons.

#### Scenario: SpinBox fields visible in toolbar
- **WHEN** the MapEditor opens
- **THEN** the toolbar shows `[X Offset] [Z Offset]` SpinBox fields after a VSeparator

#### Scenario: Default offset values
- **WHEN** the MapEditor loads
- **THEN** X Offset shows `10` and Z Offset shows `8`

### Requirement: Offset SpinBox clamping
Offset SpinBox values SHALL be clamped to `[0, grid_cells - 4]`. SpinBox max_value SHALL update dynamically when `grid_cells` changes via `TerrainSystem.grid_initialized` signal.

#### Scenario: Maximum offset
- **WHEN** the user sets X Offset to `30` on a 32×32 grid
- **THEN** the value is clamped to `28` (grid_cells - 4)

#### Scenario: Minimum offset
- **WHEN** the user sets Z Offset to `-1`
- **THEN** the value is clamped to `0`

#### Scenario: SpinBox max updates on grid change
- **WHEN** `grid_cells` changes from `32` to `46`
- **THEN** SpinBox max_value updates from `28` to `42`

### Requirement: SpinBox value change updates BoundsSystem
When an offset SpinBox value changes, the corresponding BoundsSystem export SHALL be updated, triggering a mesh redraw.

#### Scenario: X offset change updates visible bounds
- **WHEN** the user changes X Offset from `10` to `15`
- **THEN** `BoundsSystem.visible_offset_x` becomes `15` and the visible bounds mesh redraws

#### Scenario: Z offset change updates visible bounds
- **WHEN** the user changes Z Offset from `8` to `5`
- **THEN** `BoundsSystem.visible_offset_z` becomes `5` and the visible bounds mesh redraws
