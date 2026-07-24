## Context

Cell coordinate math is scattered across 5+ files in `scripts/core/` with significant duplication:

- `CELL_SIZE = 2.0` defined 3 times (Pathfinder, SelectionManager, TerrainSystem)
- `_cell_key` implemented 5 times with 2 different signatures (int for Dictionary keys, string for terrain lookups)
- `_cell_origin_to_world` and `_get_max_height` are byte-for-byte identical between BuildingManager and DeployComponent
- Spiral cell search (nested for-loop pattern) copy-pasted 6 times with different max radii and filters
- `grid_half` formula repeated 10+ times: `float(TerrainSystem.grid_cells) * CELL_SIZE * 0.5`

Pathfinder currently serves dual duty as both A* pathfinder and cell utility library — 60+ callers import it solely for `world_to_cell` and `cell_to_world`.

## Goals / Non-Goals

**Goals:**
- Single canonical source for all cell coordinate math (`CellUtil`)
- Single source for foundation-related helpers (`FoundationUtil`)
- Single source for grid geometry (`TerrainSystem.get_grid_half_size()`)
- Eliminate 6 duplicate spiral search loops via higher-order function
- Slim Pathfinder to pure A* logic

**Non-Goals:**
- Moving `cell_to_world_with_height` or `get_terrain_height` out of Pathfinder (they have hidden TerrainSystem dependencies)
- Changing any public API signatures — all call sites keep the same method names, just point to a different class
- Refactoring the TerrainSystem domain methods (`get_cell_type`, `get_cell_at_world`, etc.)

## Decisions

### D1: CellUtil is pure static math — no autoload dependencies

**Choice**: CellUtil functions take all inputs as parameters. No hidden calls to TerrainSystem, SpatialHash, or any autoload.

**Why**: Keeps CellUtil testable in isolation, avoids circular dependencies, matches the "utility" pattern. The 2-3 functions that DO need TerrainSystem (`_cell_origin_to_world`, `_get_max_height`, `get_grid_half_size`) stay in their respective domain classes.

**Alternative considered**: Putting everything in CellUtil with runtime autoload lookups via `Engine.get_main_loop()`. Rejected — hidden dependencies make testing harder and the dependency graph less clear.

### D2: Two `_cell_key` signatures in CellUtil

**Choice**: Keep both `cell_key(Vector2i) -> int` (for Dictionary keys) and `cell_key_str(Vector2i) -> String` (for terrain lookups).

**Why**: The int version is faster for Dictionary lookups (used by Pathfinder, SpatialHash). The string version is used by TerrainSystem, TerrainCollision, TerrainRenderer for cell identification. Both are pure math. Merging them would force callers to change their dictionary key types, which is a larger refactor for no benefit.

### D3: Spiral search via Callable parameter

**Choice**: `spiral_first_free(center, max_radius, is_occupied: Callable)` — the filter is provided by the caller.

**Why**: The 6 spiral search sites all have different domain-specific filters (SpatialHash checks, terrain type checks, building cell checks). A Callable keeps CellUtil free of domain dependencies while eliminating the loop boilerplate.

**Alternative considered**: Generic `spiral_iterate(center, max_radius) -> Array[Vector2i]` that yields all cells, letting callers filter. Rejected — `spiral_first_free` short-circuits on first match, which is the common case and more efficient.

### D4: FoundationUtil in `scripts/core/`, not `scripts/components/`

**Choice**: `scripts/core/FoundationUtil.gd`

**Why**: Used by both BuildingManager (`scripts/buildings/`) and DeployComponent (`scripts/components/`). Placing it in `core` reflects its cross-domain nature. It has a minimal TerrainSystem dependency (only `get_cell_max_height`).

### D5: TerrainSystem.get_grid_half_size() over CellUtil

**Choice**: Add `get_grid_half_size()` to TerrainSystem as a static method.

**Why**: `grid_half` depends on `TerrainSystem.grid_cells` (runtime state). Putting it in CellUtil would require CellUtil to depend on TerrainSystem, breaking the pure-math constraint. TerrainSystem already owns `grid_cells`, so this is the natural home. The 10+ callers already import TerrainSystem.

### D6: Migration via delegation, not bulk find-replace

**Choice**: Phase 4 keeps Pathfinder methods as thin delegates to CellUtil. Phase 6 migrates callers file-by-file. Phase 8 removes the delegating methods.

**Why**: Validates CellUtil correctness before touching 70+ call sites. If CellUtil has a bug, it's caught in Phase 4 with zero blast radius. The delegation is 4 lines of code and temporary.

## Risks / Trade-offs

**[Risk] Spiral search Callable overhead** → The Callable call has slightly more overhead than a direct method call. For 6 call sites with max radius 4-8, this is negligible. If profiling shows it matters, the hot path can inline the loop later.

**[Risk] Merge conflicts with in-flight work** → This touches ~20 files. Mitigated by doing it on a dedicated branch with no parallel feature work on the same files.

**[Risk] Pathfinder delegation adds temporary indirection** → Acceptable for the migration window. Removed in Phase 8.

**[Trade-off] Two _cell_key signatures** → Slightly more API surface, but avoids changing dictionary key types across the codebase. Worth it.
