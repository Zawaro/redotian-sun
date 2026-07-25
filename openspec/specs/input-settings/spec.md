## ADDED Requirements

### Requirement: InputSettings autoload loads settings on startup
The `InputSettings` autoload SHALL load `user://settings.cfg` on `_ready()`. If the file does not exist or fails to load, all settings SHALL fall back to defaults. The autoload MUST be registered in `project.godot` before scene-loading autoloads to ensure it initializes before any node reads `Input.is_action_pressed()`.

#### Scenario: Fresh install with no config file
- **WHEN** the game starts and `user://settings.cfg` does not exist
- **THEN** `edge_scroll_enabled` defaults to `true` and camera actions use WASD defaults from `project.godot`

#### Scenario: Config file exists with valid settings
- **WHEN** the game starts and `user://settings.cfg` contains `[camera] edge_scroll_enabled=false`
- **THEN** `InputSettings.edge_scroll_enabled` is `false`

#### Scenario: Config file is malformed
- **WHEN** the game starts and `user://settings.cfg` contains invalid INI syntax
- **THEN** the autoload loads defaults, logs a warning, and rewrites the config file with valid defaults

### Requirement: InputSettings persists settings to ConfigFile
The `InputSettings` autoload SHALL save all settings to `user://settings.cfg` in INI format whenever a setting changes. The file SHALL be human-readable and manually editable. The config file SHALL include a comment explaining physical layout behavior for non-QWERTY users.

#### Scenario: Save creates config file
- **WHEN** `InputSettings._save()` is called and `user://settings.cfg` does not exist
- **THEN** the file is created with the current settings

### Requirement: Camera actions are remappable via ConfigFile
The `InputSettings` autoload SHALL read key names from the `[keybinds]` section of `user://settings.cfg` and apply them to `InputMap` actions (`camera_up`, `camera_down`, `camera_left`, `camera_right`). Key names SHALL use `OS.get_keycode_string()` format (e.g., `"W"`, `"Space"`, `"F1"`). `remap_action()` SHALL erase all existing events for the action before adding the new event — previous bindings do not fire after remap.

#### Scenario: Default camera bindings
- **WHEN** no `[keybinds]` section exists in the config file
- **THEN** camera actions use defaults from `project.godot` (W=up, A=left, S=down, D=right)

#### Scenario: Remapped camera key persists
- **WHEN** the config file contains `camera_up=Numpad8` and the game restarts
- **THEN** pressing Numpad 8 triggers the `camera_up` action and W no longer triggers it

#### Scenario: Invalid key name falls back to default
- **WHEN** the config file contains `camera_up=InvalidKey`
- **THEN** the action retains its default binding from `project.godot`

### Requirement: Edge scroll toggle persists and takes effect immediately
The `InputSettings` autoload SHALL expose `edge_scroll_enabled` (default: `true`) loaded from the `[camera]` section of `user://settings.cfg`. Changes SHALL take effect immediately at runtime and persist when `_save()` is called.

#### Scenario: Edge scroll disabled via config
- **WHEN** `user://settings.cfg` contains `edge_scroll_enabled=false` and the game starts
- **THEN** `InputSettings.edge_scroll_enabled` is `false`

#### Scenario: Edge scroll enabled by default
- **WHEN** no `[camera]` section exists in the config file
- **THEN** `InputSettings.edge_scroll_enabled` is `true`

#### Scenario: Runtime toggle takes effect immediately
- **WHEN** `InputSettings.edge_scroll_enabled` is changed at runtime and `_save()` is called
- **THEN** edge scroll behavior updates immediately without restart and persists to disk

### Requirement: Edge scroll toggle gates panning and cursor
When `InputSettings.edge_scroll_enabled` is `false`, `CameraController.handle_border_panning()` SHALL return early and `MouseHandler._resolve_scroll_cursor()` SHALL not return scroll cursor types. Other cursor modes (sell, repair) are unaffected.

#### Scenario: Edge scroll enabled
- **WHEN** `InputSettings.edge_scroll_enabled` is `true` and the mouse is near the screen edge
- **THEN** the scroll cursor is displayed and the camera pans

#### Scenario: Edge scroll disabled
- **WHEN** `InputSettings.edge_scroll_enabled` is `false` and the mouse is near the screen edge
- **THEN** no scroll cursor is shown and the camera does not pan

### Requirement: Camera panning responds to configurable key bindings
Camera panning SHALL respond to configurable key bindings via `InputMap` actions. Default bindings are WASD. Ctrl+D SHALL block camera movement regardless of bindings.

#### Scenario: Default WASD panning
- **WHEN** the player presses W while no modifier is held
- **THEN** the camera moves forward

#### Scenario: Ctrl blocks camera movement
- **WHEN** the player holds Ctrl and presses W
- **THEN** the camera does not move

#### Scenario: Remapped key triggers panning
- **WHEN** `camera_up` is remapped to Numpad8
- **THEN** pressing Numpad8 moves the camera forward

### Requirement: Existing input is unaffected
All existing input actions and raw key checks remain unchanged.

#### Scenario: Selection input unchanged
- **WHEN** the player single left-clicks an entity
- **THEN** the entity is selected
