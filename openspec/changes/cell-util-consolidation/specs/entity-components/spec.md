## MODIFIED Requirements

### Requirement: MovementController spiral search
MovementController SHALL use `CellUtil.spiral_first_free()` for `_find_nearest_free_cell()` and `CellUtil.spiral_first_free()` for `_scatter_blockers()` instead of inline spiral loops.

#### Scenario: Spiral search consolidated
- **WHEN** `_find_nearest_free_cell()` is called with an occupied cell
- **THEN** it delegates to `CellUtil.spiral_first_free()` with the same max radius and filter logic as before

### Requirement: FreeUnitComponent spiral search
FreeUnitComponent SHALL use `CellUtil.spiral_first_free()` for `_find_adjacent_free_cell()` instead of an inline spiral loop.

#### Scenario: Spiral search consolidated
- **WHEN** `_find_adjacent_free_cell()` is called
- **THEN** it delegates to `CellUtil.spiral_first_free()` with max radius 6

### Requirement: DockHostComponent spiral search
DockHostComponent SHALL use `CellUtil.spiral_first_free()` for `find_wait_cell()` instead of an inline spiral loop.

#### Scenario: Spiral search consolidated
- **WHEN** `find_wait_cell()` is called
- **THEN** it delegates to `CellUtil.spiral_first_free()` with the configured max radius
