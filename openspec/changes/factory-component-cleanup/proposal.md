## Why

FactoryComponent is dead code — ProductionManager bypasses it entirely and reads EntityData directly through BuildingManager. This creates a fragile architecture where the building has no say in its own production behavior. The production exit system also lacks proper component support: exit points, rally points, and door animations are either hardcoded or missing entirely.

## What Changes

- **Delete dead code** from FactoryComponent: `free_unit` field, `can_produce()` method
- **Refactor FactoryComponent** into the building-level production interface with `produces: Array[String]` and `is_primary: bool`
- **Create ExitComponent** — defines exit points for units leaving buildings (production, dock release, repair completion)
- **Create RallyPointComponent** — manages rally paths for units after they exit
- **Wire ProductionManager** to query FactoryComponent via `"factories"` group instead of iterating BuildingManager
- **Add primary building toggle** — player can set which factory units exit from, FactoryComponent clears same-type siblings
- **Wire ArtComponent** to play door animations from ArtData fields on production completion
- **Add exit fields to EntityData** — `exit_cell_offset`, `spawn_cell_offset`, `exit_facing`, `has_rally_point`
- **Update .tres files** — add exit fields to GDI/Nod Barracks and War Factories

## Capabilities

### New Capabilities

- `production-exit`: ExitComponent and RallyPointComponent — defines where units spawn and exit from buildings, rally path management, door animation triggers
- `primary-building`: Primary building selection — player toggles which factory of same type is primary, affects production exit routing

### Modified Capabilities

- `factory-component`: FactoryComponent refactored from dead code to active production interface — produces field, primary toggle, exit orchestration, group-based discovery

## Impact

- **Scripts**: FactoryComponent.gd, ProductionManager.gd, EntityFactory.gd, EntityData.gd, ArtComponent.gd
- **New scripts**: ExitComponent.gd, RallyPointComponent.gd
- **Scenes**: No new scenes — components attached dynamically by EntityFactory
- **Data**: 4 .tres files updated (GDI/Nod Barracks, War Factories)
- **Dependencies**: Depends on existing ProductionManager, DockHostComponent, ArtData
- **Breaking**: None — FactoryComponent was dead code, no existing consumers
