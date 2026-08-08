## Context

Fog of war is the last completely unimplemented system. `GlobalRules.fog_of_war` (`scripts/data/GlobalRules.gd:129`) and `EntityData.sight` (default `1`) exist with no consumers. The grid primitives are all present: `TerrainSystem.grid_cells` / `get_cell_max_height` / `HEIGHT_STEP` / `MAX_HEIGHT`, `CellUtil.world_to_cell` / `is_in_diamond`, `BoundsSystem.is_in_play_area` (the blue visible-bounds diamond, an autoload), `SpatialHash.get_building_cells` (string-keyed; needs a per-cell helper), and `PlayerManager.get_players_by_team` / `is_enemy`.

This change ships the **authoritative simulation layer** plus **fog-gated interaction**. Visual rendering (fog plane, `VisionComponent`, entity culling) is a follow-up issue (#198).

## Goals / Non-Goals

**Goals:**
- Authoritative per-player shroud grid with shroud/fog/visible resolution.
- Height-aware shadowcasting via per-cell Bresenham LOS (cliffs and building walls block).
- Correct ref-counted revealer registration (register/unregister/move).
- Blue visible-bounds reveal limiter — nothing is ever revealed beyond it.
- Allied sharing via query-time team union.
- Circular `explore_area` / `reveal_area` for the mission/trigger layer.
- Optional shroud growth (1 cell per interval, visible cells protected).
- Fog-gated interaction: shrouded targets are not attackable, hoverable, or selectable (incl. resources and force-fire); move orders still work into shroud.
- Incremental dirty-cell resolution; no work when nothing changed.
- Fully headless-testable; inert when `fog_of_war == false`.

**Non-Goals:**
- No visual shroud/fog rendering (follow-up #198).
- No `VisionComponent` / unit-driven revealer wiring (follow-up #198).
- No frozen-actor "last seen" snapshots for fogged buildings (follow-up).
- No per-player desync-hash / netcode (structure stays deterministic for future lockstep).
- No minimap fog overlay (separate issue).

## Decisions

### 1. Per-cell Bresenham LOS with height-delta blocking
Each revealer casts a line from its center cell to every candidate within radius (square-bounded, diamond-clamped). A candidate is revealed iff no *intermediate* cell blocks it. A cell blocks when its `get_cell_max_height` exceeds the viewer height by more than `MAX_HEIGHT_DELTA` (constant, default `HEIGHT_STEP * 0.75` so a full cliff step blocks but cascade-smoothed micro-rises don't) or when it is a building cell. Viewer height and `blocks_terrain` come in at registration; air revealers skip all blocking.

Rationale: cliffs in this engine are pure heightfield steps, so the height rule captures vertical walls with no geometry raycasting. **Alternative considered:** a pure height-delta filter (reveal a cell iff its own height is low enough, no occlusion chains) — simpler and cheaper, but ridges don't cast shadows and cliffs feel flat. **Alternative considered:** recursive symmetric shadowcasting — robust corner handling but does not extend naturally to per-cell heights. Bresenham is the direct reading of the requirement and is testable. Known artifact: a line clipping a tall cell's corner can leak a thin sight wedge; acceptable at these radii.

### 2. Query-time allied union (not replicated grids)
`is_visible` / `is_explored` fold in `PlayerManager.get_players_by_team(query_player)` at read time. Revealers stamp only their own player's grid; allied grids are never mutated. Rendering later bakes an effective (allied-union) array for the local player.

Rationale: deterministic under lockstep (all grids exist on every machine; union is a pure read fold), less state, no per-ally churn on every revealer update. The replicated alternative doubles state and only buys per-player sync-hash, which can be added independently by hashing each player's own grid. Future-proof for lockstep multiplayer.

### 3. Per-player grid with dirty-tick resolution
Per player: `explored: PackedByteArray`, `visible_count: PackedInt32Array`, `resolved: PackedByteArray` (0 shroud / 1 fog / 2 visible), `touched: PackedByteArray`. A fixed resolve tick processes only `touched` cells and short-circuits when nothing changed. Shadowcasting runs only on register/unregister/cell-crossing. `resolved` caches the derived state; `get_effective_state(local_player)` returns the allied-union resolved array for the renderer later.

### 4. Revealer stamp/unstamp with deterministic recompute
`register_revealer(player_id, center, radius, viewer_height, blocks_terrain)` returns a key; the system stamps the revealed set into `visible_count` and `explored`. `unregister_revealer` recomputes the same deterministic set to decrement — no per-source cell lists stored. Registering at a new cell = unregister + register. Overlaps stack via counts.

### 5. Blue visible-bounds reveal limiter
Every reveal path (shadowcast candidate set, `explore_area`, `reveal_area`, `explore_all`) is gated on `BoundsSystem.is_in_play_area(cell)`. `get_explored_percentage` uses the play-area cell count as denominator. Cells outside play bounds are permanently shroud.

### 6. Shroud growth
Ticker on `shroud_growth_interval` gameplay seconds, gated on `GlobalRules.shroud_grows`. Each tick, for each player, explored-and-not-visible cells adjacent to a shroud cell revert to shroud (clear `explored`). Visible cells are protected because their revealers re-stamp. Play-area clamp is intrinsic (outside cells already shroud).

### 7. Interaction filter at the order funnel + hover + selection
One rule: a target is interactable iff its cell is visible to the local player (allied union), gated on `fog_of_war`. Guard points:
- `OrderSystem.get_cursor` / `get_orders` null the target when its cell isn't visible — covers every generator and both cursor/order paths in one place.
- `MouseHandler._handle_hover_preview` skips shrouded targets (this path bypasses `OrderSystem`).
- `SelectionManager` skips shrouded entities for click and box selection.

A null target falls through to the existing move path, so "move into shroud" works for free. Force-fire at shrouded cells is gated too (falls through to move). When `fog_of_war` is false the filter is a no-op.

## Risks / Trade-offs

- [Bresenham corner-clipping artifacts] → Acceptable at vision radii; `get_cell_max_height` uses the tallest of four corners so blocking is conservative.
- [Shadowcast cost O(r³) per revealer] → Only recomputed on register/unregister/cell-cross, radii ≤ ~12 cells, so amortized trivial; dirty-tick resolution keeps steady-state work at O(changed cells).
- [Query-time union cost per cell query] → Teams are tiny (≤ a few players); union iterates teammates per query. Fine for target filtering; rendering uses a single precomputed effective array.
- [Growth re-stamp churn on the frontier] → Growth ticks are slow (interval ≥ seconds); only frontier cells are touched.
- [Interaction filter touches core input paths] → Guard is centralized in `OrderSystem` plus two single-line checks; behavior is a no-op when fog is off, preserving existing maps/skirmish.

## Migration Plan

All changes additive: new autoload, new fields defaulting to off, new `is_building_cell` helper, and a filter that is inert unless `fog_of_war == true`. No existing scene or resource changes required. Rollback = revert the branch.

## Open Questions

- Exact `MAX_HEIGHT_DELTA` value (default `HEIGHT_STEP * 0.75`) — tune after in-game cliffs exist.
- Whether `reveal_area` should accept a non-air (blocker-honoring) variant for future triggers — deferred until a trigger needs it.
