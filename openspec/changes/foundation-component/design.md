## Context

Building placement lives in `BuildingManager` (autoload). `can_place` iterates a building type's foundation cells inline for bounds, play-area, per-cell availability, and terrain height variation; `place_building` re-iterates them to build the cell list it registers in `SpatialHash`; `_update_preview_mesh` and `_add_grid_and_indicators` call `_is_cell_free(cell)` per cell for coloring. `FoundationComponent` (attached only to entities whose `foundation != 1×1`) holds `foundation`, `height`, `bib_cells` and exposes `get_foundation_cells` / `get_bib_cells`, but no availability or occupancy logic.

Two placement rules named in the issue are absent: flattening terrain under a placed footprint, and adjacency (`EntityData.adjacent` — the field exists but has no consumer).

Key constraint: the preview/validation flow runs from an `EntityData` (`current_building_type`) every frame, *before* the entity (and its `FoundationComponent`) exists. So footprint logic must be callable from raw footprint data, not only from a live component instance.

## Goals / Non-Goals

**Goals:**
- One canonical implementation of footprint math (occupied cells, per-cell buildability, per-footprint buildability), reused by validation, preview rendering, and placed-entity queries.
- `FoundationComponent.get_occupied_cells(origin)` and `FoundationComponent.is_buildable(origin)` as the public entity-side API.
- Terrain flattening under a footprint after placement.
- Adjacency enforcement from `EntityData.adjacent`.

**Non-Goals:**
- Building destruction / death cell-release — no health-driven building death path exists in the codebase yet; sell already releases cells.
- Changing bib semantics, preview visuals, or the economy/prerequisite flow.
- Restoring (un-flattening) terrain when a building is sold.

## Decisions

**1. Footprint math as static functions on `FoundationComponent`, with thin instance wrappers.**
Because validation runs from `EntityData` before any component exists, the shared logic is exposed as `static` functions taking raw footprint data:
- `is_cell_buildable(cell)` — single cell: not a building/bib cell, not blocked, no entity with a `MovementController`, no resource, terrain type `""`/`"clear"`. This is exactly today's `BuildingManager._is_cell_free`, relocated so both `FoundationComponent.is_buildable` and `BuildingManager`'s preview code share one copy.
- `footprint_buildable(foundation, origin)` — every foundation cell is `is_cell_buildable` AND max−min cell height ≤ `TerrainSystem.HEIGHT_STEP`.
- `occupied_cells(foundation, bib_cells, origin)` — foundation cells minus bib cells (the cells registered as solid in `SpatialHash`).

Instance methods `is_buildable(origin)`, `get_occupied_cells(origin)`, `get_foundation_cells(origin)` delegate to the statics using the component's own fields. *Alternative considered:* a persistent scratch `FoundationComponent` in `BuildingManager` configured per type — rejected as needless state; statics are simpler and allocation-free in the per-frame preview path.

**2. `BuildingManager` keeps the composite policy it alone can evaluate.**
`can_place` still owns map-bounds, play-area, and debug place-anywhere (which need `BoundsSystem` / debug menu), plus the new adjacency check (which needs the building registry). The footprint free/height portion delegates to `FoundationComponent.footprint_buildable`. `_is_cell_free` becomes a one-line delegate to `FoundationComponent.is_cell_buildable` so preview code is untouched.

**3. Adjacency lives in `BuildingManager`.**
Adjacency needs the set of existing friendly buildings, which only `BuildingManager` tracks (`_buildings`). If `EntityData.adjacent <= 0` the check is a no-op (all current data). Otherwise placement is allowed only when some footprint cell is within Chebyshev distance `adjacent` of a friendly building's occupied cell. Skipped under debug place-anywhere.

**4. Flattening lives in `TerrainSystem`.**
Flattening mutates vertices and must run the existing cascade + `cell_changed` emission, all of which `TerrainSystem` owns. New `flatten_footprint(origin_cell, size)` computes the max vertex level over the footprint region and sets every bounding vertex to it via the existing `set_vertex`. `place_building` calls it after cell registration. Placement already rejects footprints with height delta > one step, so flattening only levels a near-flat pad; keeping it in `TerrainSystem` avoids `FoundationComponent` reaching into terrain internals.

## Risks / Trade-offs

- [Flatten permanently edits terrain with no sell-time restore] → Matches genre behavior (build pads stay flat); documented as a deliberate non-goal. Revisit if rubble/restore is added.
- [`flatten_footprint` calls `set_vertex` per vertex, each running a full cascade] → Placement is an infrequent, user-driven event; cost is negligible. Batch cascade is a later optimization if profiling shows it.
- [Relocating `_is_cell_free` could change preview coloring behavior] → It is moved verbatim as `is_cell_buildable` and `_is_cell_free` delegates to it, so behavior is identical; covered by existing `BuildingManager` tests.
- [Adjacency inert today] → Intentional; schema-first, exercised by unit tests using synthetic `adjacent > 0` data.
