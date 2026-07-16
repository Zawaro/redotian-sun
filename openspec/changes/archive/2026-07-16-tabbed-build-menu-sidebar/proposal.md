## Why

The current sidebar is a flat GridContainer showing only buildings — no tabs, no unit production, no prerequisites. This blocks core RTS gameplay: players can't build infantry, vehicles, or aircraft from the sidebar. The Vinifera-proven 4-tab layout (Buildings, Infantry, Vehicles, Special) is the standard for Tiberian Sun UIs.

## What Changes

- Replace flat GridContainer with tabbed sidebar (4 tabs: Buildings, Infantry, Vehicles, Special)
- Add ProductionManager autoload for queue management, timers, and unit spawning
- Add PrerequisiteSystem autoload to track player-owned buildings and gate entity availability
- Add `build_time` and `build_limit` fields to EntityData
- Implement angular progress shader on cameo buttons (radial wipe, 12 o'clock → clockwise)
- Scrollable 5×3 grid with row-step scrolling and middle mouse scroll handling
- Tab hotkeys (F1-F4) and visual feedback for active tab
- Unit spawning at factory exit point with scatter logic when blocked
- Production speed bonus from multiple factories of same type

## Capabilities

### New Capabilities

- `prerequisite-system`: Track player-owned buildings, check prerequisites (OR/AND logic), enforce build limits, emit signals when prerequisites change
- `production-queue`: Per-player per-factory-type production queues, timer management, cost deduction/refund, pause/resume/cancel, production speed bonuses, unit spawning on completion
- `sidebar-ui`: Tabbed build menu with 4 categories, scrollable 5×3 cameo grid, angular progress shader, tab switching, hotkey bindings, middle mouse scroll consumption
- `angular-progress`: Canvas shader for radial wipe progress indicator on cameo buttons

### Modified Capabilities

_(none — this is new functionality)_

## Impact

- **New files**: `scripts/production/ProductionManager.gd`, `scripts/production/ProductionQueue.gd`, `scripts/production/PrerequisiteSystem.gd`, `shaders/angular_progress.gdshader`
- **Modified files**: `scripts/data/EntityData.gd` (add build_time, build_limit), `scripts/ui/Sidebar.gd` (full rewrite), `scenes/ui/Sidebar.tscn` (full rewrite), `scripts/buildings/BuildingManager.gd` (emit signals for prerequisite registration), `project.godot` (register new autoloads)
- **All existing `.tres` entity files**: add build_time values
- **Dependencies**: EconomyManager (cost deduction/refund), EntityFactory (entity creation), SpatialHash (cell queries), Pathfinder (cell/world conversion), MovementController (scatter)
