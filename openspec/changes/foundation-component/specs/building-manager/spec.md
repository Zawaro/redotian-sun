## MODIFIED Requirements

### Requirement: Placement validation
`can_place(building_type, origin_cell)` SHALL check every foundation cell for map bounds and play-area bounds, SHALL delegate cell availability and terrain height variation to `FoundationComponent.footprint_buildable(building_type.foundation, origin_cell)`, and SHALL enforce the adjacency requirement `building_type.adjacent`. Under debug place-anywhere mode only the map-bounds check applies.

#### Scenario: Valid placement
- **WHEN** all foundation cells are free, in bounds, height variation is within limit, and any adjacency requirement is satisfied
- **THEN** `can_place()` returns true

#### Scenario: Cell occupied by building
- **WHEN** any foundation cell overlaps an existing building's footprint
- **THEN** `can_place()` returns false

#### Scenario: Cell has resource
- **WHEN** any foundation cell contains a resource entity
- **THEN** `can_place()` returns false

#### Scenario: Height variation too steep
- **WHEN** max height - min height across foundation cells exceeds `TerrainSystem.HEIGHT_STEP`
- **THEN** `can_place()` returns false

#### Scenario: Adjacency requirement unmet
- **WHEN** `building_type.adjacent > 0` and no friendly building has an occupied cell within Chebyshev distance `adjacent` of any footprint cell
- **THEN** `can_place()` returns false

#### Scenario: Adjacency requirement met
- **WHEN** `building_type.adjacent > 0` and a friendly building has an occupied cell within Chebyshev distance `adjacent` of a footprint cell
- **THEN** the adjacency check passes

#### Scenario: No adjacency requirement
- **WHEN** `building_type.adjacent <= 0`
- **THEN** the adjacency check always passes

#### Scenario: Debug place-anywhere mode
- **WHEN** `debug_menu.place_anywhere == true`
- **THEN** only bounds check is enforced, cell/height/adjacency checks are skipped

### Requirement: Building placement
`place_building(building_type, origin_cell)` SHALL validate placement, deduct cost (unless `_skip_next_deduction` is set), create the entity via EntityFactory, register its occupied cells (foundation minus bib) in SpatialHash, register any bib cells, flatten terrain under the footprint via `TerrainSystem.flatten_footprint`, register the building in PrerequisiteSystem, and emit `building_placed`.

#### Scenario: Place building with deduction
- **WHEN** `place_building()` is called without skip flag
- **THEN** cost is deducted from player credits via EconomyManager

#### Scenario: Place building with skip deduction
- **WHEN** `set_skip_next_deduction()` was called before `place_building()`
- **THEN** cost is NOT deducted (already paid via production queue)

#### Scenario: Place building registers cells
- **WHEN** a 2×2 building is placed at cell (5, 3)
- **THEN** cells (5,3), (6,3), (5,4), (6,4) are registered in SpatialHash

#### Scenario: Place building registers bib cells
- **WHEN** a building with bib cells is placed
- **THEN** bib cells are registered separately in SpatialHash and are excluded from the occupied building cells

#### Scenario: Place building flattens terrain
- **WHEN** a building is placed over a footprint with a one-step height variation
- **THEN** the footprint region is levelled to its maximum height

#### Scenario: Place building resumes production
- **WHEN** a building from the production queue is placed
- **THEN** `ProductionManager.clear_waiting_for_placement()` is called

### Requirement: Cell availability check
`_is_cell_free(cell)` SHALL delegate to `FoundationComponent.is_cell_buildable(cell)`, returning false if the cell is a building cell, blocked, has an entity with MovementController, a bib cell, has a resource, or terrain type is not "" or "clear".

#### Scenario: Free cell
- **WHEN** a cell has no buildings, entities, resources, and is "clear" terrain
- **THEN** `_is_cell_free()` returns true

#### Scenario: Occupied cell
- **WHEN** a cell has a building footprint
- **THEN** `_is_cell_free()` returns false
