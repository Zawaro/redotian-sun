## Context

`VisionComponent` stamps a `ShroudSystem` revealer for every player-owned entity that has `sight > 0`. The revealer's position comes from `_center_cell()`:

```gdscript
var pos := _parent.global_position
if _foundation != Vector2i(1, 1):
    pos += Vector3(_foundation.x * CELL_SIZE * 0.5, 0.0, _foundation.y * CELL_SIZE * 0.5)
return CellUtil.world_to_cell(pos)
```

But `CellUtil.cell_origin_to_world(origin, footprint)` returns the **footprint center** (`origin + footprint * 0.5`), and that is what `BuildingManager.place_building` and `MapLoader` assign to the entity's position. So `global_position` is already the center and the added half-foundation is a second offset. The `_foundation != Vector2i(1, 1)` guard makes the error zero for units and proportional to footprint size for buildings.

Concrete: a 4×3 refinery (sight 4) at origin `(60,60)` registers at `(66,64)`; its far footprint corner `(60,60)` is 7.2 cells away — outside the radius, so the building's own corner stays shrouded and the revealed area is lopsided toward +X/+Z.

Registration itself is correct: `place_building` sets `StatsComponent.player_id` before `add_child`, `_configure_components` sets `_sight`, and `_physics_process` registers on the first physics frame for the owner and then disables polling (buildings require no per-frame tracking). Both sidebar placement and construction-yard production route through `place_building`.

## Goals / Non-Goals

**Goals:**
- Reveal a placed building's full sight radius symmetrically around its own footprint.
- Keep the fix in one place so every path that sets an entity's position to the footprint center (placement, production, map load) is covered.
- Leave a regression test that fails on the offset.

**Non-Goals:**
- Changing `blocks_terrain` for building revealers (separate decision; produces extra reveal, not this defect).
- Changing `ShroudSystem` revealer registration, movement, or ref-count semantics.
- Changing building data, scenes, or public APIs.

## Decisions

**Decide the center cell from `global_position` alone.** Replace the body of `_center_cell()` with `return CellUtil.world_to_cell(_parent.global_position)` and delete the foundation-offset branch. `global_position` is the footprint center by construction, so no footprint arithmetic is needed; `_foundation` remains used for nothing in this method.

- Alternative considered: `CellUtil.world_to_cell_origin(global_position, _foundation) + _foundation / 2` (integer division). Mathematically equivalent placement of the center cell for the same position, but it re-introduces footprint arithmetic and depends on `world_to_cell_origin`'s rounding. Rejected as more code for the same outcome.
- For even-sized footprints the geometric center lies on a cell boundary; `world_to_cell` floors to one of the footprint cells (e.g. 2×2 → the far cell of the four). That is inside the footprint and a valid, symmetric-enough center; there is no integer "true" center for even footprints.

**Keep the one-shot registration for buildings.** Buildings register once and call `set_physics_process(false)`; the center is fixed at placement and the building does not move. No change needed.

**Test the behavior, not the implementation.** Add a unit case that places a multi-cell building with a small sight radius and asserts a cell one step diagonally outside the footprint on the `-X,-Z` side is visible. On the current offset that cell is beyond the radius (dark), so the test fails for the intended reason before the fix and passes after.

## Risks / Trade-offs

- [Even-footprint center is one of the central four cells, not a true geometric center] → Inherent to integer cells; the reveal stays within the footprint and symmetric within one cell. Acceptable; matches how buildings are positioned elsewhere.
- [Existing building vision tests assert cells ~4.2 cells away at `sight = 6`, so they pass under the bug] → The new regression case uses a small radius and a cell adjacent to the footprint, which the offset cannot mask.
- [The `-X,-Z` side is direction-dependent if the building were rotated] → Placement rotation is not applied to building positions/revealers today; the center cell is orientation-independent.

## Open Questions

- Should a building revealer be blocked by terrain height (a building in a valley not seeing behind a ridge)? The code sets `blocks_terrain = false`, contradicting `VisionComponent`'s own comment; the fog-of-war spec only states buildings do not *block* others' line of sight. Out of scope here; needs a separate decision and its own spec delta.
