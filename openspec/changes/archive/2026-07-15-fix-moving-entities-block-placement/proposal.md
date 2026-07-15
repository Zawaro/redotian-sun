## Why

Moving units don't block building placement. When a unit is in motion (non-IDLE state), `SpatialHash._blocked_cells` doesn't include it, so `BuildingManager._is_cell_free()` treats the cell as free. The player can place buildings on top of moving units, which is incorrect — the original Tiberian Sun blocks placement on any occupied cell.

## What Changes

- `BuildingManager._is_cell_free()` gains an additional check: queries `SpatialHash._grid` for any non-resource entity on the cell, regardless of movement state
- `SpatialHash` exposes a helper method to check if any entity (excluding resources) occupies a cell
- No changes to `_blocked_cells` or pathfinding behavior — units still pass through each other during movement
- New test for moving unit blocking building placement

## Capabilities

### New Capabilities
- `building-placement-blocking`: Building placement validates cell occupancy for all entities including moving units

### Modified Capabilities

## Impact

- `scripts/buildings/BuildingManager.gd` — `_is_cell_free()` gets new occupancy check
- `scripts/core/SpatialHash.gd` — new helper method `is_any_entity_on_cell()`
- `test/unit/test_building_manager.gd` — new test case for moving unit blocking
