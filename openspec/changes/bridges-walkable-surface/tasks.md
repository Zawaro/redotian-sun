# Bridges — Full Walkable-Surface Model

> Note: The previous single-surface bridge implementation and its tests/specs are
> **rewritten** to the level model described in `design.md` (see the "Supersedes"
> decision), not weakened or deleted. Every new parameter defaults to level 0, so
> earlier phases keep existing callers green until they are migrated.

## 1. Core surface stack and level-aware queries

- [x] 1.1 Add a per-cell surface stack to `scripts/core/TerrainSystem.gd`: ground at level 0 plus deck levels, bounded by `MAX_HEIGHT`; store without overwriting ground land or heights
- [x] 1.2 Level-parameterize `get_land_type(cell, level = 0)` and `get_cell_surface_height(cell, level = 0)`; a level with no surface reports none
- [x] 1.3 Add `CellUtil.cell_level_key(cell, level)` and route movement/occupancy identity through it; level 0 stays consistent with `cell_key`
- [x] 1.4 Make `SpatialHash` occupancy/blocked/entry queries level-scoped (`level` default 0) and update the bridge registry from a single scalar cell map to `(cell, level)` metadata (kind, end, piece, surface height, stacked entries)
- [x] 1.4a Level-scope pathfinding blocking (gap in 1.4): key `_blocked_cells` by `CellUtil.cell_level_key(cell, level)`, add `get_blocked_cells(level = 0)`/`is_cell_blocked(cell, level = 0)`, make `is_any_entity_on_cell(cell, level = -1)` level-aware (`-1` = any, back-compat), and have `MovementController._build_blocked_cells` request the unit's `_surface_level` so a deck occupant never blocks the ground (and vice versa). Tests in `test/unit/test_spatial_hash.gd`.
- [x] 1.5 Make `SpatialHash` cell reservation level-scoped (`reserve_cell`/`release_cell`/`force_reserve` with default level 0)
- [x] 1.6 Make `CellSubPositions.get_sub_positions`/`get_sub_position` and `CellReservation` claims level-scoped (default 0)
- [x] 1.7 Level-parameterize `TerrainSystem.get_cell_grade_steps(cell, level = 0)` and the world-lifetime height snapshot for level surfaces, with deck-change invalidation
- [x] 1.8 Unit tests: stack composition, default level 0 parity for `get_land_type`/`get_cell_surface_height`/occupancy/reservation, stacked entries coexist, ground under a deck keeps its land, `MAX_HEIGHT` bound

## 2. Level-aware pathfinding and height rules

- [x] 2.1 Change `scripts/core/Pathfinder.gd` search nodes to `(cell, level)`, with optional start/goal levels defaulting to 0 and level-carrying waypoints
- [x] 2.2 Implement the surface-stack height transition rules in neighbor expansion: same level OK; ±1 ramp only (lower cell); ±N×4 spanned deck only; else refuse
- [x] 2.3 Cost a step of two or more levels from the Road row and skip the destination terrain figure on decks
- [x] 2.4 Key the per-cell cost cache by `(cell, level)` and bump its generation on bridge/level changes
- [x] 2.5 Verify ground beneath a high deck remains pathable (deck does not block level 0)
- [x] 2.6 Unit tests: path across a deck not water, no-bridge routes around water, four-level climb from ground rejected / from matching end allowed, ±1 ramp rules, road-cost deck, under-deck ground path, `(cell, level)` cache isolation and invalidation

## 3. Mover level, Y, place-sets, and picking

- [x] 3.1 Track the unit's current surface level in `MovementController` and resolve its place-set at that level
- [x] 3.2 Sample Y from the walkable surface of the unit's level (`get_cell_surface_height(cell, level)`); ground Y unchanged beneath a deck
- [x] 3.3 Make sharing/capacity/repulsion level-scoped so deck and ground traffic use independent places
- [x] 3.4 Disambiguate ground picking by level: a deck hit resolves to the deck level; the ground beneath stays selectable with both candidates reported
- [x] 3.5 Unit/integration tests: mover Y on a deck vs ground, simultaneous deck and under-deck occupancy, picking on a deck vs beneath it

## 4. Low bridge rework

- [ ] 4.1 Set the low-bridge deck to ~0.5 height step up with upward thickness; author slope end pieces — deck height + end-piece data done; slope art is a placeholder (no mesh), deferred
- [x] 4.2 Keep low-bridge road-passability with the terrain figure skipped; slope ends admit ground traffic
- [x] 4.3 Split destructibility: normal low-bridge pieces destructible, end pieces indestructible (destruction deferred to #250)
- [x] 4.4 Update the low-bridge overlay resources (`games/ts/entities/overlay/bridge*.tres`) for kind/level/end/rise
- [x] 4.5 Tests: low deck height, drive across via slope ends, end excluded from destruction, normal piece destructible

## 5. High bridge, terrain-object ends, stamping, rail

- [x] 5.1 Set the high-bridge deck to ~4 steps up with downward thickness, authored on one flat span grade; all cells indestructible
- [x] 5.2 Add bridge-end `TerrainObject`s (cliff + 3-cell road cut) to `games/ts/terrain_objects/`, including a rail variant, with per-cell `land`/`corners`
- [x] 5.3 Add the runtime stamp-to-grid consumer that applies a `TerrainObject`'s `land`/`corners` and pins its cells via `pin_cell`
- [x] 5.4 Persist stamped ends through the existing `cell_pins` JSON (no new section) and rebuild them on import
- [x] 5.5 Author rail bridges as high-bridge variants only
- [x] 5.6 Tests: high deck height, entry only at a matching-grade end, all cells indestructible, road-cut stamp applies land/corners, pinned cells reject edits, `cell_pins` round-trip, rail is high-only

## 6. Stacked extra-high decks

- [x] 6.1 Support N deck levels over the same XZ bounded by `MAX_HEIGHT`, each an independent surface and place-set
- [x] 6.2 Apply the height rules and pathing across stacked levels; each level resolves its own Y and places
- [x] 6.3 Integration test: two stacked decks traversed independently, and ground traffic driving under the decks on level 0
- [x] 6.4 Test: a deck at or above `MAX_HEIGHT` is refused

## 7. Docs, test rewrite, and integration

- [x] 7.1 Add GLOSSARY entries: surface stack, deck level, place-set, low bridge, high bridge, rail bridge, extra-high bridge, height transition, road cut, walkable surface height; update the existing bridge entries
- [x] 7.2 Rewrite the existing single-surface bridge tests to the level model (assert on `(cell, level)`, not a scalar surface)
- [x] 7.3 Integration: a vehicle drives across a bridge at deck level and stops on the far shore at deck Y
- [x] 7.4 Integration: a vehicle drives under a high deck on the ground while another crosses on the deck
- [x] 7.5 Integration: a map with stacked decks and stamped ends round-trips through map JSON
- [x] 7.6 Run `redot --headless -s test/run_tests.gd`, then `gdlint` + `gdformat --check`; check for tab introduction
- [x] 7.7 Run `openspec validate bridges-walkable-surface` and mark this change's tasks complete
