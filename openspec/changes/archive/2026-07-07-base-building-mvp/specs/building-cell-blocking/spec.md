## ADDED Requirements

### Requirement: Buildings register footprint cells in SpatialHash
When a building is placed, BuildingManager SHALL register all cells in its footprint with SpatialHash via `register_building_cells()`. These cells persist until the building is destroyed or removed.

#### Scenario: Building cells are registered on placement
- **WHEN** a 2×2 building is placed at origin cell (3, 4)
- **THEN** cells (3,4), (4,4), (3,5), (4,5) are added to SpatialHash._building_cells

#### Scenario: Building cells persist across SpatialHash rebuilds
- **WHEN** SpatialHash.rebuild() runs after a building is placed
- **THEN** the building's cells remain in _building_cells (not cleared by rebuild)

### Requirement: get_blocked_cells merges building and unit cells
SpatialHash.get_blocked_cells() SHALL return a dictionary containing both `_blocked_cells` (dynamic unit occupancy) and `_building_cells` (permanent building occupancy).

#### Scenario: Blocked cells include buildings
- **WHEN** a building occupies cells (3,4) and (4,4)
- **AND** no idle units are present
- **THEN** get_blocked_cells() contains keys "3,4" and "4,4"

#### Scenario: Blocked cells include both buildings and units
- **WHEN** a building occupies cell (3,4)
- **AND** an idle unit occupies cell (5,6)
- **THEN** get_blocked_cells() contains keys "3,4" and "5,6"

### Requirement: Pathfinder avoids building cells
Pathfinder.find_path() SHALL treat building cells as impassable, same as idle unit cells. Units SHALL path around placed buildings automatically.

#### Scenario: Path avoids building footprint
- **WHEN** a unit paths from (0,0) to (10,10)
- **AND** a 3×3 building occupies cells (4,4) through (6,6)
- **THEN** the returned path does not include any cell within the building footprint

#### Scenario: Path reroutes around buildings
- **WHEN** a unit has a pre-existing path that intersects a newly placed building
- **THEN** the unit's next pathfinding call produces a path that avoids the building

### Requirement: MovementController handles building cells correctly
MovementController._build_blocked_cells() SHALL include building cells in its blocked set without code changes. The existing merge of SpatialHash.get_blocked_cells() + reserved cells naturally includes buildings.

#### Scenario: Moving unit avoids building cells
- **WHEN** a unit is moving toward a target
- **AND** a building is placed in its path
- **THEN** the unit's pathfinding produces a new path around the building

#### Scenario: Scatter logic ignores building cells
- **WHEN** _scatter_blockers() runs near a building
- **THEN** no attempt is made to scatter buildings (get_entries returns empty for building-only cells)
