## Context

`SpatialHash.rebuild()` runs every physics frame and populates two dictionaries:
- `_grid`: ALL entities (units, buildings, resources) — used for lookups
- `_blocked_cells`: ONLY entities with `MovementController.State.IDLE` — used for pathfinding

`BuildingManager._is_cell_free()` calls `is_cell_blocked()` which only checks `_blocked_cells`. Moving units (non-IDLE) are in `_grid` but not in `_blocked_cells`, so the cell appears free.

Pathfinding uses `_blocked_cells` via `get_blocked_cells()` → `MovementController._build_blocked_cells()`. If we added moving units to `_blocked_cells`, other units couldn't path through cells where a unit is currently moving — changing core movement behavior.

## Goals / Non-Goals

**Goals:**
- Building placement blocks on moving units (same as original Tiberian Sun)
- No change to pathfinding behavior — units still pass through each other during movement
- Minimal code change — only `_is_cell_free()` and a new SpatialHash helper

**Non-Goals:**
- Changing `_blocked_cells` composition (affects pathfinding)
- Adding `BlockedByActor`-style context-dependent checks (over-engineered for current needs)
- Making units scatter when building is placed on them (future enhancement)

## Decisions

### Decision: Check `_grid` directly in `_is_cell_free()` instead of modifying `_blocked_cells`

**Why**: `_blocked_cells` feeds into pathfinding. Adding moving units there would make them obstacles to other units' pathfinding — changing movement behavior. Building placement needs a stricter check than pathfinding.

**Alternative considered**: Add all entities to `_blocked_cells` — rejected because it breaks unit pathfinding flow.

### Decision: New `is_any_entity_on_cell()` helper on SpatialHash

**Why**: Encapsulates the `_grid` lookup logic. Avoids exposing `_grid` internals to BuildingManager. Keeps the check self-contained and testable.

**Alternative**: Inline the `_grid` check in `_is_cell_free()` — rejected because it couples BuildingManager to SpatialHash internals.

### Decision: Skip resource entities in the new check

**Why**: Resources are already checked by `_has_resource_on_cell()`. Adding them to the entity check would be redundant. Resource pods should not block building placement (units walk through them, buildings check them separately via the resource system).

## Risks / Trade-offs

- **Performance**: `_grid` lookup per cell per foundation tile during preview. `_grid` is a Dictionary with integer keys — O(1) per lookup. Foundation tiles are small (1-4 cells). Negligible impact.
- **Race condition**: Entity moves between `_grid` rebuild and `_is_cell_free()` check. `_grid` is rebuilt every physics frame; building preview updates every frame. Worst case: 1-frame delay before red/green updates. Acceptable.
