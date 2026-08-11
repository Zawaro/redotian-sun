## Why

The greedy-first movement change (archived) cut pathing from 95ms to 3ms, but the remaining FPS dip on `perf/279-mass-infantry-move-fps-drop` is now the **per-unit movement sim itself**: a 50+ infantry move order sustains ~30ms frames (Process time 13.5ms) for the duration of the move. The profile shows 186 moving units paying ~56µs each every 60Hz physics tick to re-read the *unchanged world* — the same ~3 bilinear terrain height samples (`get_height_at_world_smooth`), the same Catmull-Rom spline segments, the same autoload lookups (`Pathfinder._get_terrain_system` walks `Engine.get_main_loop()` 74× per order drain). Every unit re-pays for facts that change ~never.

## What Changes

- **World-lifetime terrain height snapshot (new `TerrainSystem` cache):** cache per-cell corner-vertex heights in a `cell_key → [h_nw, h_ne, h_sw, h_se]` dictionary, populated lazily, invalidated by the existing `cell_changed` signal (every vertex-mutation path already emits it) plus `grid_initialized` resets. All four height consumers — `get_height_at_world_smooth` (movement), `get_cell_max_height` (shroud LOS, buildings, deploy), `Pathfinder._cell_height` (climb checks), slope/height reads — read the snapshot instead of N bounds-checked Array lookups. **Land type stays batch-lifetime** (as today in `PathCostCache`): `set_land_type` emits no `cell_changed` and the SpatialHash resource registry mutates on harvest/growth, so caching land world-lifetime would serve silently stale speed multipliers.
- **Frame-scoped height memo in `MovementController`:** the ~3 `get_height_at_world_smooth` reads per unit per tick (`_snap_to_terrain`, `_slope_coefficient`'s height_ahead/height_now pair, arrival snap) route through a frame-scoped memo (cleared on process-frame change, keyed by quantized cell). Terrain is static within a frame, so 186×3 samples collapse to ~unique-cells. Unit-independent data only — nothing order-dependent (avoidance stays per-unit live).
- **Spline path baking:** precompute per-segment positions, tangents, and lengths into arrays at `set_target_position` time; `_get_spline_pos`/`_get_spline_tangent` become array indexing instead of ~6 Catmull-Rom evals per unit per tick. Same spline math, same output.
- **Batch autoload hoist:** resolve the `TerrainSystem` node once per SelectionManager move-batch (and once per `try_greedy_step` call-site) and thread it through `try_greedy_step`/`_cell_cost`/`find_path` as a parameter, replacing the per-step `Engine.get_main_loop().get_node_or_null()` walk (74× per order drain = the 5ms dispatch spike). `PathCostCache` reads heights from the shared world snapshot.
- No breaking changes: steering, snap, climb, LOS, and fog results are preserved byte-for-byte.

## Capabilities

### New Capabilities
- `terrain-height-cache`: world-lifetime per-cell corner-vertex snapshot served to all terrain-height consumers, invalidated by terrain mutation via `cell_changed`/`grid_initialized`, kept coherent with the live heightfield.

### Modified Capabilities
- `pathfinder`: per-cell terrain cost cache now sources its height entry from the world-lifetime `TerrainSystem` height snapshot (land/bib remain batch-lifetime); `try_greedy_step`/`_cell_cost`/`find_path` accept a terrain-node reference instead of resolving the autoload per step.
- `selection-manager`: move dispatch resolves the `TerrainSystem` node once per move-order batch and threads it (with the shared height snapshot) into per-unit path resolution instead of re-resolving per unit.

## Impact

- `scripts/core/TerrainSystem.gd` — add the height snapshot cache + invalidation wiring (reads `cell_changed`/`grid_initialized`), reroute `get_cell_max_height`/`_sample_heightfield_at`/`get_height_at_world_smooth` through it.
- `scripts/core/Pathfinder.gd` — thread `terrain` through `_cell_cost`/`try_greedy_step`/`find_path`; `_cell_height` reads the snapshot; hoist `_get_terrain_system()` out of the greedy step loop.
- `scripts/components/MovementController.gd` — frame-scoped height memo; spline path baking in `set_target_position`; pass terrain ref where applicable.
- `scripts/core/SelectionManager.gd` — resolve terrain once per batch, pass into dispatch.
- `scripts/core/SpatialHash.gd` — no change expected (land stays batch-lifetime).
- Tests: new `terrain-height-cache` unit tests (snapshot coherence, invalidation on height edit/map load, identical float output), updated `pathfinder`/`selection-manager` cost-cache tests, spline-bake equivalence tests, height-memo equivalence tests. Full suite stays green (4640+).
- No scene, resource, or data changes; no autoload registration changes.
