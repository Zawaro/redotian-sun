extends Node

## Centralized input settings — loads/saves user config, manages camera keybinds.

const CONFIG_PATH: String = "user://settings.cfg"
const CAMERA_ACTIONS: Array = ["camera_up", "camera_down", "camera_left", "camera_right"]

## Edge scroll toggle — controls both border panning and scroll cursor display.
var edge_scroll_enabled: bool = true


func _ready() -> void:
    _load()


## Erase all existing events for action, add new binding from key name. Persists to disk.
func remap_action(action: String, key_name: String) -> void:
    var keycode := OS.find_keycode_from_string(key_name)
    if keycode == KEY_NONE:
        push_error("[InputSettings] Invalid key name: %s" % key_name)
        return
    _apply_binding(action, keycode)
    _save()


## Returns human-readable key name for the first event bound to action.
func get_key_text(action: String) -> String:
    var events := InputMap.action_get_events(action)
    if events.is_empty():
        return ""
    var event := events[0]
    if event is InputEventKey:
        var keycode := DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
        return OS.get_keycode_string(keycode)
    return ""


func _load() -> void:
    var cfg := ConfigFile.new()
    var err := cfg.load(CONFIG_PATH)
    if err != OK:
        push_warning("[InputSettings] Could not load %s, using defaults" % CONFIG_PATH)
        return

    edge_scroll_enabled = cfg.get_value("camera", "edge_scroll_enabled", true)

    for action in CAMERA_ACTIONS:
        if not cfg.has_section_key("keybinds", action):
            continue
        var key_name: String = cfg.get_value("keybinds", action, "")
        if key_name.is_empty():
            continue
        var keycode := OS.find_keycode_from_string(key_name)
        if keycode == KEY_NONE:
            push_warning("[InputSettings] Invalid key name for %s: %s" % [action, key_name])
            continue
        _apply_binding(action, keycode)


func _apply_binding(action: String, keycode: int) -> void:
    InputMap.action_erase_events(action)
    var event := InputEventKey.new()
    event.physical_keycode = keycode as Key
    InputMap.action_add_event(action, event)


func _save() -> void:
    var cfg := ConfigFile.new()
    # Physical layout (W = top-left letter row, remap for non-QWERTY)
    cfg.set_value("camera", "edge_scroll_enabled", edge_scroll_enabled)
    for action in CAMERA_ACTIONS:
        var key_text := get_key_text(action)
        if not key_text.is_empty():
            cfg.set_value("keybinds", action, key_text)
    var err := cfg.save(CONFIG_PATH)
    if err != OK:
        push_warning("[InputSettings] Failed to save config: %s" % CONFIG_PATH)
