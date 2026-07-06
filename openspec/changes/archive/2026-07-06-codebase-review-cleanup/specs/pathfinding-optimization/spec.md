## ADDED Requirements

### Requirement: Pathfinder heap operations use cached keys
The A* binary heap SHALL avoid repeated `_cell_key()` string concatenation and dictionary lookups during push/pop operations.

#### Scenario: Pathfinding produces correct result
- **WHEN** `Pathfinder.find_path()` is called with valid start and end positions
- **THEN** the returned path connects start to end through walkable cells

#### Scenario: Heap operations do not crash
- **WHEN** the pathfinding algorithm pushes and pops cells from the open set
- **THEN** no null reference or key mismatch errors occur

### Requirement: Catmull-rom spline functions are extracted to SplineUtil
Spline interpolation functions SHALL live in a dedicated `scripts/core/SplineUtil.gd` static utility, not inline in MovementController.

#### Scenario: MovementController uses SplineUtil for interpolation
- **WHEN** a unit is moving along a path
- **THEN** `SplineUtil.evaluate()` and `SplineUtil.tangent()` are called (not local `_catmull_rom` methods)

#### Scenario: SplineUtil is independently testable
- **WHEN** `SplineUtil.evaluate()` is called with 4 control points and t=0.5
- **THEN** it returns a valid Vector3 position on the spline
