## Why

Input handling is scattered across multiple scripts with hardcoded key checks. Camera movement uses raw `KEY_W/A/S/D` in `CameraController.gd`, making it impossible to remap without editing source code. Edge scroll has no toggle. This change adds ConfigFile persistence, camera action remapping, and an edge scroll toggle — enabling the future settings UI.

## What Changes

- **New `InputSettings` autoload** — centralizes input configuration, loads/saves settings via `ConfigFile` (`user://settings.cfg`)
- **Add `camera_up/down/left/right` input actions** to `project.godot` with WASD defaults
- **Convert `CameraController.gd`** from raw `KEY_W/A/S/D` to input actions
- **Gate edge scroll** on `InputSettings.edge_scroll_enabled` in both `CameraController` (panning) and `MouseHandler` (cursor display)
- **ConfigFile persistence** — keybinds and edge scroll toggle survive restarts, editable manually

## Capabilities

### New Capabilities
- `input-settings`: Centralized input configuration — autoload, ConfigFile persistence, camera action remapping, edge scroll toggle

### Modified Capabilities

_(none — this change adds new behavior without altering existing spec requirements)_

## Impact

- **New file**: `scripts/core/InputSettings.gd` (autoload)
- **Modified**: `project.godot` — add 4 camera actions + InputSettings autoload registration
- **Modified**: `scripts/hud/CameraController.gd` — replace `KEY_W/A/S/D` with actions, gate border panning on edge scroll toggle
- **Modified**: `scripts/hud/MouseHandler.gd` — gate `_resolve_scroll_cursor()` on edge scroll toggle
- **No breaking changes** — existing input (selection, box select, right-click cancel, zoom, tab switching, deploy, escape) is untouched
- **No scene changes** — all changes are script-level; no `.tscn` files affected
