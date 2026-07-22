## Why

Debugging RTS gameplay requires constantly toggling between the game and external tools. There's no way to inspect entity state, adjust lighting, visualize spatial systems, or bypass gameplay constraints from within the game. This blocks rapid iteration on combat, economy, and entity behavior.

## What Changes

- Add a debug/developer panel toggled with the backtick key
- Panel provides 4 sections: Overlays, Lighting, Cheats, Entity Inspection
- Debug overlays: pathfinding lines, spatial hash grid, entity bounds, health bars, entity IDs
- Lighting controls: sun elevation/rotation/intensity/color, shadow, ambient, fog, sky rotation, glow
- Cheat toggles: no prerequisites, no build time, no cost, place anywhere (non-building entities)
- Action buttons: clear all paths, add 100k credits
- Entity inspection: click any entity to see all component data dynamically
- Inline lighting properties on LightingControls (no separate resource class)

## Capabilities

### New Capabilities
- `debug-menu`: In-game debug/developer panel with overlays, lighting controls, cheats, and entity inspection

### Modified Capabilities
- `economy-core`: Add add_credits() method and cheat-mode bypass for deduct()
- `entity-components`: PrerequisiteSystem and ProductionManager cheat-mode bypass hooks

## Impact

- New files: LightingControls.gd, DebugMenu.gd, DebugMenu.tscn
- Modified files: project.godot, MapBase01.tscn, Sidebar.gd, ProductionManager.gd, PrerequisiteSystem.gd, EconomyManager.gd, MouseHandler.gd
- DebugMenu is a scene instance (not autoload) accessed via group reference
- Input map: new `toggle_debug` action (KEY_QUOTELEFT)
