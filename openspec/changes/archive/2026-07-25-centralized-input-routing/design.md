## Context

`CameraController.gd` uses raw `KEY_W/A/S/D` for camera panning (lines 30-42). This is the only non-modifier raw key usage in the gameplay codebase. All other input (selection, harvest, deploy, tab switching) already uses `InputMap` actions defined in `project.godot`. Edge scroll is always on with no toggle. No settings persist across restarts.

The existing action system (`project.godot` `[input]` section) already defines 10 actions (`move_map`, `zoom_in`, `zoom_out`, `select_entity`, `deselect_entity`, `tab_*`, `deploy`, `toggle_debug`). Adding 4 camera actions follows the same pattern.

## Goals / Non-Goals

**Goals:**
- WASD camera panning uses remappable input actions
- Edge scroll can be toggled on/off, persists across restarts
- Settings stored in human-editable `ConfigFile` (`user://settings.cfg`)
- InputSettings is an autoload accessible to all scripts

**Non-Goals:**
- Settings UI / remap buttons (follow-up issue)
- Gamepad input support
- Modifier key remapping (Shift, Ctrl, Alt stay raw)
- Standard/inverted scroll modes
- Camera bookmarks

## Decisions

### 1. ConfigFile stores key names, not InputEvent objects

**Choice**: Store `"camera_up=W"` (string key name) instead of serialized InputEvent objects.

**Rationale**: ConfigFile serializes InputEvent natively, but the output is a 500+ character object string — unreadable for manual editing. Key names (`"W"`, `"Space"`, `"F1"`) are human-readable and match the manual-edit requirement.

Round-trip: `OS.get_keycode_string(keycode)` saves `"W"`, `OS.find_keycode_from_string("W")` loads it back as a keycode for `physical_keycode`.

**Alternatives considered**:
- Native InputEvent serialization: rejected — not human-editable
- Physical keycode integers: rejected — not human-readable

### 2. Physical keycodes for camera actions

**Choice**: Use `physical_keycode` (US QWERTY layout position) for camera actions, matching `project.godot` convention.

**Rationale**: Camera panning is a spatial action. Physical keycodes match the US QWERTY layout position. Non-QWERTY users remap via the config file.

### 3. Ctrl guard stays raw

**Choice**: Keep `not Input.is_key_pressed(KEY_CTRL)` as a raw modifier check in `CameraController._process()`.

**Rationale**: This is a universal "don't move camera during deploy hotkey" guard, not a remappable keybind. It degrades gracefully — blocks camera during Ctrl+D regardless of what camera_up is bound to. Making it an action would add complexity for zero benefit.

### 4. Edge scroll toggle gates both panning and cursor

**Choice**: When `edge_scroll_enabled=false`, skip both `handle_border_panning()` and `_resolve_scroll_cursor()`.

**Rationale**: Showing a scroll cursor without scroll behavior is confusing. Disable both the action and the visual indicator.

## Risks / Trade-offs

- **Non-QWERTY layouts**: Physical keycodes match US QWERTY positions. On AZERTY, WASD in the config file maps to physical key positions, not characters. Mitigation: config file includes a comment: `# Physical layout (W = top-left letter row, remap for non-QWERTY)`.

- **Config file corruption**: If `user://settings.cfg` is malformed, `ConfigFile.load()` returns an error. Mitigation: fall back to defaults, log a warning, rewrite config with valid defaults.

- **Action creation timing**: `InputSettings._ready()` must run before any scene node reads `Input.is_action_pressed("camera_up")`. Since all autoloads finish before scene `_ready()`, this is guaranteed by autoload ordering. Project.godot must list InputSettings before scene-loading autoloads.
