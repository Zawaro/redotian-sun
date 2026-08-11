# movement-frame-cache Specification

## Purpose

A per-cell frame-scoped cache inside `MovementController` that serves the per-unit hot path from shared, unit-independent inputs: land type for the terrain speed factor, the 3×3 avoidance-hood entry lists with an empty-cell guard, and the 4 corner heights for the facing normal. Terrain and occupancy are static within a physics frame, so units sharing a cell pay the dictionary/property reads once per cell per frame instead of once per unit per tick.

## ADDED Requirements

### Requirement: Frame-scoped per-cell cache
`MovementController` SHALL maintain a frame-scoped cache, keyed by `CellUtil.cell_key(cell)` and invalidated when the engine process frame advances or when the `TerrainSystem` height-snapshot generation changes. The cache SHALL store, per unique cell touched by the movement hot path within a frame: the 3×3 avoidance-hood entry lists (9 arrays) and the resolved land type. A unit whose cell is already in the cache SHALL reuse the cached values instead of re-querying `SpatialHash.get_entries` or `TerrainSystem.get_land_type`.

#### Scenario: Units sharing a cell share the fetch
- **WHEN** two moving infantry occupy the same cell in the same physics frame
- **THEN** the 3×3 hood and land type for that cell are fetched once and both units read the cached values

#### Scenario: Cache cleared on frame advance
- **WHEN** the engine process frame advances (or the terrain height-snapshot generation changes)
- **THEN** the cache is cleared and the next query re-reads live `SpatialHash`/`TerrainSystem` data

### Requirement: Empty-cell guard in the avoidance hood
The cached 3×3 avoidance hood SHALL record empty cells (cells with no grid entries) so a unit's per-tick 3×3 scan answers empty cells without a repeated `SpatialHash.get_entries` dictionary lookup for each unit sharing that cell. A cell cached as empty SHALL yield an empty entry list on every reuse within the frame.

#### Scenario: Empty neighbor answered from cache
- **WHEN** the avoidance scan of a unit reaches a neighbor cell with no entries that was previously fetched this frame
- **THEN** the scan uses the cached empty list without a further `SpatialHash.get_entries` call for that cell

### Requirement: Land type frame memo
`_terrain_speed_factor` SHALL resolve the unit's cell land type through the frame cache (falling back to `TerrainSystem.get_land_type` on a cache miss) so the terrain speed multiplier is computed from a single per-cell land-type read per frame rather than per unit per tick. A land-type change mid-frame (resource harvest/growth registry flip) MAY be reflected at the next frame boundary.

#### Scenario: Speed factor reads memoized land type
- **WHEN** two units on the same cell compute their terrain speed factor in the same frame
- **THEN** both use the land type cached for that cell, and `TerrainSystem.get_land_type` is not re-queried for the second unit

### Requirement: Facing normal from corner snapshot
`_apply_facing` SHALL compute the terrain normal from the cell's 4 corner heights obtained via `TerrainSystem.get_cell_snapshot_corners_raw` (reusing the corner fetch already performed by the height memo where the same cell), instead of issuing 4 separate raw `get_vertex` reads. The computed normal SHALL be bit-identical to `TerrainSystem.get_normal_at_world` output for the same position (same 4 raw corner ints, same cross-product edge order, same `HEIGHT_STEP` scaling).

#### Scenario: Normal parity on a slope cell
- **WHEN** `_apply_facing` computes a terrain normal for a unit on a slope cell
- **THEN** the result equals `TerrainSystem.get_normal_at_world` for the same position to the last bit

#### Scenario: Normal reused from height-memo cell
- **WHEN** a unit's `_snap_to_terrain` and `_apply_facing` run in the same frame on the same cell
- **THEN** both consume the single cached corner array for that cell
