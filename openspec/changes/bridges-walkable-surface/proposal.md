## Why

Bridges are data-only stubs today: `games/ts/entities/overlay/bridge.tres` and `rail_bridge.tres` are 15-line `EntityData` resources with no walkable surface, no pathing presence, and no collision — vehicles cannot cross water. The current change models only a single ground-level surface: one deck height per cell, no stacking, no under-deck traffic, and no level in cell identity. That is not the Tiberian Sun model. A TD/TS cell is **two places** (deck and the ground beneath) and bridges range from a surface-level low bridge, through a four-level high bridge with cliff ends, to arbitrarily stacked extra-high decks. This change rewrites the artifacts to that full model so it can be implemented. GDI1a's road/rail bridges and every water map are blocked on it, and it is the foundation for destruction (#250).

## What Changes

- **Cell surface stack**: a cell holds an ordered stack of surfaces — ground at level 0 plus one or more deck levels above it — bounded by `TerrainSystem.MAX_HEIGHT = 10`. Land type, walkable surface height, and occupancy become height-parameterized queries; level 0 defaults preserve every existing caller.
- **Deck as a parallel place-set**: a bridge deck occupies a second, independent set of places at its own level, mirroring the existing sub-slot "places" model (`CellSubPositions`, `shared_slots_per_cell`). Ground traffic under a deck is judged as open ground at level 0.
- **Height transitions (TS rules)**: level → allowed; ±1 → only across a ramp (the lower cell); ±N×4 → only across a spanned deck; anything else refused. A ≥2-level step is costed from the Road row, and a deck surface skips the terrain figure entirely (deck passability = road).
- **Bridge ends are TerrainObjects**: a cliff with a 3-cell road cut. A new runtime stamp-to-grid consumer applies a TerrainObject's per-cell `land` + `corners` to the grid and persists via the existing `cell_pins` map JSON (no new JSON section).
- **Low bridge** (deck ~0.5 step up, thickness upward, slope end pieces, normal pieces destructible / ends indestructible), **high bridge** (deck ~4 steps up on one authored flat span grade, thickness downward, all cells indestructible, own cliff/road-cut ends), and **rail bridges as high bridges only**.
- **N stacked decks** from the start (extra-high bridges), bounded by `MAX_HEIGHT`, forming multiple overlap levels at different Y over the same XZ.
- Level-aware pathfinding (A* nodes are `(cell, level)`, under-deck ground pathing), occupancy/reservation/spatial-hash, and mouse picking (a high-deck click selects the deck; the ground beneath stays selectable).
- Bridge kind (low/high/rail), deck grade/rise, and level fields on `EntityData`; factory attaches the deck component. Persistence rides the existing `entities` array (one entry per cell) plus `cell_pins` for stamped ends.
- Damage/repair (bridge strength, repair hut, whole-piece break via `piece_id`) is foundation-only here; actual destruction gameplay is #250.

## Capabilities

### New Capabilities

- `cell-surfaces`: the per-cell surface stack, height-parameterized surface/land/occupancy queries, parallel place-sets per level, the TS height-transition rules, stacked decks bounded by max height, and default-level-0 behavior.
- `bridges`: bridge span overlay entities (low/high/rail), deck levels and place-sets, deck-as-road passability with the terrain figure skipped, low/high geometry and destructibility split, extra-high stacked decks, terrain-object road-cut ends with stamp-to-grid + `cell_pins` persistence, and entity persistence.

### Modified Capabilities

- `pathfinder`: A* nodes become `(cell, level)`; pathing evaluates height transitions across the stack with the TS rules; a deck is costed from the Road row; ground beneath a high deck is pathable; the per-cell cost cache is keyed by `(cell, level)` and invalidated on bridge/level changes.
- `spatial-hash`: occupancy, blocked cells, and the bridge registry become level-aware (a deck does not block the ground level beneath it); reservations remain level-scoped.
- `cell-util`: cell identity for movement/occupancy carries a level, default 0.
- `cell-occupancy`: shared-cell capacity and sub-slot positioning are evaluated per level (each deck has its own places).
- `cell-reservation`: in-flight sub-slot claims are keyed by `(cell, level)`, default 0.
- `mouse-ground-picking`: a click that hits a high deck resolves to the deck level, and the ground level remains selectable beneath.
- `terrain-cell-pins`: a high-bridge end is a `TerrainObject` stamped to the grid; its land/corners are applied and its cells pinned, persisting through `cell_pins`.
- `terrain-object-catalog`: add the high-bridge end object (cliff with a 3-cell road cut) and its per-cell `land`/`corners`.
- `terrain-grade`: per-cell grade is reported per level surface beyond the terrain surface.
- `terrain-height-cache`: the height snapshot is extended to per-cell level surfaces beyond the terrain surface.
- `land-types`: register the `bridge`/deck surface and require ground locomotors to cross it at road cost.
- `locomotor`: ground locomotors declare a deck/`bridge` terrain speed (road multiplier); the deck surface is road-like.
- `entity-data`: bridge kind including rail, end-piece flag, deck grade/rise, and level fields.
- `entity-factory`: attach the bridge/deck component, including deck level and rail kind.

## Impact

- `scripts/core/TerrainSystem.gd` — surface stack + level-parameterized `get_land_type`/`get_cell_surface_height` + terrain-object stamping + `cell_pins`.
- `scripts/core/Pathfinder.gd` — `(cell, level)` nodes, height-transition rules, road-cost deck, level-keyed cost cache.
- `scripts/core/SpatialHash.gd` — level-aware registry and occupancy (replaces the single-surface `_bridge_cells`).
- `scripts/core/CellUtil.gd`, `scripts/core/CellSubPositions.gd` — level in cell identity / per-level places.
- `scripts/components/MovementController.gd` — level + Y + place-set resolution.
- `scripts/components/BridgeComponent.gd` — deck level, kind (low/high/rail), piece/end metadata.
- `scripts/entities/EntityFactory.gd` — component attach with level/kind.
- HUD/input ground picking, map JSON (`cell_pins`, `entities`), data resources (`games/ts/...`).
- Tests and existing single-surface bridge tests/specs are rewritten to the level model, not weakened.
- Depends on #228 for editor placement; ships API + tests only. Enables #250.
