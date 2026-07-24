## Why

SpatialHash uses a 1-entity-per-cell model where any idle unit blocks the cell for everyone. This prevents infantry from grouping naturally (3 per cell in Tiberian Sun) and means vehicles cannot crush enemy infantry — a core TS mechanic. The `crusher`/`crushable` properties exist on EntityData but nothing consumes them at runtime.

## What Changes

- Infantry cells hold up to 3 units with deterministic sub-slot positioning
- Infantry movement skips the ROTATING state and faces movement direction directly
- Infantry groups overlap freely during movement (no repulsion between friendly infantry)
- Crusher vehicles kill enemy crushable infantry on cell entry (movement-based, not combat)
- Pathfinder routes infantry through cells with < 3 infantry
- Group move commands pre-assign infantry to cells near target
- StatsComponent gains `crusher` and `crushable` fields from EntityData
- 47 `.tres` resource files updated with correct crush/crushable flags per original rules.ini

## Capabilities

### New Capabilities
- `infantry-occupancy`: 3-per-cell infantry occupancy with sub-slot positioning, infantry-aware pathfinding, and group move pre-assignment
- `vehicle-crush`: Crusher vehicles kill enemy crushable infantry on cell entry during movement

### Modified Capabilities
- `entity-components`: StatsComponent gains `crusher: bool` and `crushable: bool` fields

## Impact

- **Scripts changed**: StatsComponent, SpatialHash, MovementController, SelectionManager, ProductionManager
- **New scripts**: CellSubPositions (static utility)
- **Data files**: 47 infantry/vehicle `.tres` files updated with crush flags
- **Tests**: New tests for CellSubPositions, MovementController infantry behavior, SpatialHash infantry occupancy; existing SpatialHash and SelectionManager tests updated
- **Scenes**: No scene changes (all script-level)
- **Breaking**: None — existing behavior unchanged for non-infantry entities
