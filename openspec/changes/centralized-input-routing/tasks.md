## 1. InputSettings Autoload

- [x] 1.1 Create `scripts/core/InputSettings.gd` — autoload with `edge_scroll_enabled` property, `_ready()` loads config, `_save()` writes config
- [x] 1.2 Implement `remap_action(action: String, key_name: String)` — erases all existing events for the action, converts key name to `InputEventKey` with `physical_keycode`, adds to `InputMap`. Returns `void`, logs `push_error()` on invalid key name
- [x] 1.3 Implement `get_key_text(action: String) -> String` — returns human-readable key name for a given action
- [x] 1.4 Implement config file load/save with `ConfigFile` — `[camera]` section, `[keybinds]` section, AZERTY layout comment
- [x] 1.5 Handle malformed config — fall back to defaults, log warning, rewrite config with valid defaults

## 2. Project Configuration

- [x] 2.1 Add `camera_up`, `camera_down`, `camera_left`, `camera_right` input actions to `project.godot` with WASD defaults (physical_keycode)
- [x] 2.2 Register `InputSettings` autoload in `project.godot` `[autoload]` section — must appear before scene-loading autoloads

## 3. CameraController Conversion

- [x] 3.1 Replace `Input.is_key_pressed(KEY_W/A/S/D)` with `Input.is_action_pressed("camera_up/down/left/right")` in `CameraController._process()`
- [x] 3.2 Keep `not Input.is_key_pressed(KEY_CTRL)` guard as-is (raw modifier check)

## 4. Edge Scroll Gating

- [x] 4.1 Gate `CameraController.handle_border_panning()` on `InputSettings.edge_scroll_enabled` — return early when disabled
- [x] 4.2 Gate `MouseHandler._resolve_scroll_cursor()` on `InputSettings.edge_scroll_enabled` — return no scroll cursor types when disabled

## 5. Verification

- [x] 5.1 Unit tests: config load defaults when no file exists, load saved settings from config file, `remap_action` applies binding to InputMap
- [ ] 5.2 Manual test: WASD moves camera, edge scroll toggle on/off, remap camera key in config file persists after restart
