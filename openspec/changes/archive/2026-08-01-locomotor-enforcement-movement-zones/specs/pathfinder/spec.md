## ADDED Requirements

### Requirement: Per-locomotor terrain passability filtering
`Pathfinder.find_path()` SHALL accept an optional `locomotor: Locomotor` parameter. When provided, a neighbor cell SHALL be impassable if the unit's `terrain_speeds` for that cell's land type is `0.0` or the land type id is absent from `terrain_speeds`. A water cell occupied by an intact ice entity SHALL be passable to ground locomotors (see ice-drowning). When `locomotor` is null, all cells remain passable (preserving current behavior).

#### Scenario: Wheeled blocked by water
- **WHEN** a wheeled unit with `terrain_speeds = {"clear": 1.0, "water": 0.0}` pathfinds across a water cell
- **THEN** the water cell is excluded and the path routes around it

#### Scenario: Hover crosses water
- **WHEN** a hover unit with `terrain_speeds = {"clear": 1.0, "water": 1.0}` pathfinds across the same water cell
- **THEN** the water cell is included and the path crosses it

#### Scenario: Ice provides footing on water
- **WHEN** a wheeled unit pathfinds onto a water cell that holds an intact ice entity
- **THEN** the cell is treated as passable

#### Scenario: No locomotor preserves behavior
- **WHEN** `find_path()` is called without a locomotor
- **THEN** terrain type does not affect passability

### Requirement: Terrain speed pathing cost
Pathfinder SHALL weight neighbor transitions by the inverse of the unit's terrain speed multiplier for the target cell (`cost = base_cost / multiplier`). Faster surfaces (roads) yield cheaper paths than slow ones (rough).

#### Scenario: Road preferred over rough
- **WHEN** a wheeled unit (`rough = 0.5`, `road = 1.25`) has equal-length routes over rough and road
- **THEN** the road route has lower total cost and is preferred

#### Scenario: Water with zero speed is blocked
- **WHEN** a unit's terrain speed multiplier for a cell is `0.0`
- **THEN** the cell is treated as impassable regardless of pathing cost

### Requirement: Per-locomotor climb tolerance
Pathfinder SHALL treat a neighbor transition as impassable when the absolute height difference between the current and neighbor cell exceeds `climb_tolerance × HEIGHT_STEP` for the unit's locomotor. Fly and Jumpjet locomotors SHALL ignore this check. The existing soft height cost penalty SHALL remain for passable transitions.

#### Scenario: Cliff blocks foot
- **WHEN** a foot unit (`climb_tolerance = 1`) is adjacent to a cell 3 height levels higher
- **THEN** that cell is excluded from the path

#### Scenario: Fly ignores cliffs
- **WHEN** a fly unit pathfinds across a 3-level height step
- **THEN** the transition is allowed

#### Scenario: No locomotor keeps soft penalty only
- **WHEN** `find_path()` is called without a locomotor across a 3-level height step
- **THEN** the transition is allowed with the existing height cost penalty
