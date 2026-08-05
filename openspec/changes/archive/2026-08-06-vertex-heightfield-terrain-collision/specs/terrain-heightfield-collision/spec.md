# terrain-heightfield-collision Specification

## Purpose

Terrain collision derived from the vertex heightfield (`TerrainSystem._vertex_grid`), not from art meshes. Provides a pure-math segment intersection API for gameplay queries (ballistics, LOS), an opt-in `HeightMapShape3D` builder for physics-server consumers (knockback), and correct diamond-boundary behavior. All answer surfaces sample the same bilinear surface as `get_height_at_world_smooth`, guaranteeing collision always agrees with movement and picking.

## ADDED Requirements

### Requirement: Heightfield is the single collision authority
Terrain collision SHALL derive from the vertex heightfield `_vertex_grid` (integer heights `0..MAX_HEIGHT` scaled by `HEIGHT_STEP`), using the same bilinear surface as `get_height_at_world_smooth`. Collision SHALL NOT be derived from art meshes, GLB submeshes, or `TerrainObject.crease` folds. No per-cell `StaticBody3D` terrain bodies SHALL be created.

#### Scenario: Flat cell height query
- **WHEN** a cell has all four corner heights equal to 2
- **THEN** its terrain surface height is `2 * HEIGHT_STEP` everywhere within the cell

#### Scenario: No art dependency
- **WHEN** a map is loaded in any theater with no art resources present
- **THEN** terrain collision queries still return the same answers as with art loaded

### Requirement: Segment intersection query (pure math)
The system SHALL provide a segment intersection query (e.g. `intersect_heightfield_segment(from, to)`) against the bilinear heightfield surface, implemented with no physics-server involvement. It SHALL return the first terrain hit (world point + the containing cell) or a no-hit result when the segment does not cross terrain. The query SHALL be deterministic and usable headlessly.

#### Scenario: Vertical segment hits flat terrain
- **WHEN** a vertical segment descends from above onto a flat cell whose surface is at `2 * HEIGHT_STEP`
- **THEN** the query returns a hit whose Y equals `2 * HEIGHT_STEP` and whose cell is that cell

#### Scenario: Segment fully above terrain misses
- **WHEN** both endpoints of a segment lie above the maximum heightfield height along the segment's XZ path
- **THEN** the query returns no hit

#### Scenario: Segment crosses a sloped cell
- **WHEN** a segment passes through a cell whose four corner heights differ (a bilinear slope)
- **THEN** the query returns a hit at the bilinear surface point where the segment crosses the cell

#### Scenario: Segment starting below terrain
- **WHEN** a segment begins below the terrain surface
- **THEN** the query returns no hit (or the first up-crossing is not reported), matching the documented contract

### Requirement: No phantom collisions outside the playable diamond
Vertices outside the playable diamond (as defined by `CellUtil.is_in_diamond`) SHALL be treated as absent/uncollidable. Segments passing over map corners where the diamond has no cells SHALL return no hit.

#### Scenario: Segment over empty corner
- **WHEN** a segment passes through a region of the map's bounding box that lies outside the playable diamond
- **THEN** the query returns no hit for that region

### Requirement: HeightMapShape3D builder mirrors the heightfield
The system SHALL provide an opt-in builder (e.g. `build_heightfield_shape() -> HeightMapShape3D`) that fills `map_data` from `_vertex_grid` (`height * HEIGHT_STEP`) and sets `map_width`/`map_depth` to the square extent spanning the diamond. Vertices outside the playable diamond SHALL be written as `NAN` (holes). The builder SHALL NOT mount any node or body itself.

#### Scenario: Flat map produces flat shape
- **WHEN** a map with all-zero vertices is built into a shape
- **THEN** every in-diamond `map_data` value is `0.0` and out-of-diamond values are `NAN`

#### Scenario: Heights scaled into the shape
- **WHEN** a vertex with height 3 is built into the shape
- **THEN** its `map_data` value is `3 * HEIGHT_STEP`

#### Scenario: Diamond corners are holes
- **WHEN** a rectangular grid's diamond corners are built
- **THEN** the `map_data` entries for those corner vertices are `NAN`

#### Scenario: Builder creates no physics nodes
- **WHEN** the builder is invoked
- **THEN** no `StaticBody3D`, `CollisionShape3D`, or other node is added to any scene tree

### Requirement: Consistency across answer surfaces
Height queries, segment intersection, and the built `HeightMapShape3D` SHALL agree on the same terrain surface. A point that the height query reports as `h` at an XZ position SHALL be the same surface that segment intersection and the shape expose there.

#### Scenario: Query and shape agree on a slope
- **WHEN** a cell has distinct corner heights and both a segment intersection and a built shape are queried at the same XZ position
- **THEN** both report the same surface height

### Requirement: Runtime crease policy
Runtime collision SHALL treat each cell as a bilinear surface; authored `TerrainObject.crease` diagonal data SHALL NOT be consulted at runtime collision time. The rendered fold of a tile may therefore differ from the bilinear surface by up to half the height gradient within a cell; this is an accepted trade-off, not a defect.

#### Scenario: Crease data ignored at runtime
- **WHEN** an authored `TerrainObject` cell declares a crease fold
- **THEN** the runtime collision surface for that cell is still the bilinear interpolation of its corner heights
