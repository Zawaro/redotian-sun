## Why

`FoundationComponent` stores a building's footprint size, height, and bib cells but owns no placement logic. Footprint math (which cells a building occupies, whether they are buildable, terrain height variation) is duplicated inline inside `BuildingManager`, and two requested placement rules — terrain flattening under a footprint and adjacency requirements — do not exist yet. Making `FoundationComponent` the single source of truth for footprint queries removes the duplication and gives every system (placement, docking, debug, future AI) one canonical API.

## What Changes

- `FoundationComponent` gains canonical footprint queries: `get_occupied_cells(origin)` (foundation cells minus bib cells) and `is_buildable(origin)` (all footprint cells free + clear terrain + acceptable height delta).
- The single-cell buildability predicate (occupancy + terrain-type check) becomes one shared static on `FoundationComponent`, reused by `BuildingManager`'s validation and preview rendering instead of being reimplemented.
- `BuildingManager.can_place` delegates footprint free/height checks to `FoundationComponent`, keeps its own bounds/play-area/debug rules, and adds an adjacency requirement driven by `EntityData.adjacent`.
- `BuildingManager.place_building` registers occupied cells via the canonical footprint query and flattens terrain under the footprint after placement.
- `TerrainSystem` gains `flatten_footprint(origin_cell, size)` to level a footprint region to its maximum height.

## Capabilities

### New Capabilities
- `foundation-component`: Canonical footprint queries on `FoundationComponent` — occupied cells, per-footprint buildability, and the shared single-cell buildability predicate.

### Modified Capabilities
- `building-manager`: Placement validation delegates footprint checks to `FoundationComponent`, enforces adjacency via `EntityData.adjacent`, and flattens terrain under a placed footprint.

## Impact

- `scripts/components/FoundationComponent.gd` — new footprint query methods and shared static predicate.
- `scripts/buildings/BuildingManager.gd` — `can_place`, `_is_cell_free`, `place_building` refactored to reuse `FoundationComponent`; adjacency check added.
- `scripts/core/TerrainSystem.gd` — new `flatten_footprint` API (uses existing vertex/cascade logic).
- Tests under `test/unit/` and `test/integration/`.
- No `.tscn` changes; component instantiation via `EntityFactory` is unchanged. Adjacency is inert for existing data (`adjacent` defaults to 0). Building destruction cell-release is out of scope — no health-based building death path exists yet.
