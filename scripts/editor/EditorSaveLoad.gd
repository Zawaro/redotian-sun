extends Node

var editor: Node3D = null

var _save_dialog: FileDialog
var _load_dialog: FileDialog


func setup(ui: CanvasLayer) -> void:
    _save_dialog = FileDialog.new()
    _save_dialog.name = "SaveDialog"
    _save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    _save_dialog.access = FileDialog.ACCESS_FILESYSTEM
    _save_dialog.filters = PackedStringArray(["*.json ; JSON Files"])
    _save_dialog.file_selected.connect(_on_save_file_selected)
    ui.add_child(_save_dialog)
    _load_dialog = FileDialog.new()
    _load_dialog.name = "LoadDialog"
    _load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    _load_dialog.access = FileDialog.ACCESS_FILESYSTEM
    _load_dialog.filters = PackedStringArray(["*.json ; JSON Files"])
    _load_dialog.file_selected.connect(_on_load_file_selected)
    ui.add_child(_load_dialog)


func on_save_pressed() -> void:
    _save_dialog.popup_centered(Vector2i(400, 300))


func on_load_pressed() -> void:
    _load_dialog.popup_centered(Vector2i(400, 300))


func _on_save_file_selected(path: String) -> void:
    var entities_array: Array[Dictionary] = []
    for cell_key in editor._painted_entities:
        var entry: Dictionary = editor._painted_entities[cell_key]
        var data: Dictionary = entry.get("data", {})
        var entity_entry: Dictionary = {
            "id": data.get("id", ""),
            "cell": cell_key,
        }
        if data.has("player_id"):
            entity_entry["player_id"] = data["player_id"]
        for key in MapLoader.OVERRIDE_KEYS:
            if data.has(key):
                entity_entry[key] = data[key]
        entities_array.append(entity_entry)
    if not entities_array.is_empty():
        TerrainSystem.export_to_json(path, {"entities": entities_array})


func _on_load_file_selected(path: String) -> void:
    for key in editor._painted_entities:
        var node := editor._painted_entities[key].get("node") as Node3D
        if is_instance_valid(node):
            node.queue_free()
    editor._painted_entities.clear()
    var loaded := MapLoader.load_map_into(path, editor)
    for entry in loaded:
        var key: String = entry.get("key", "")
        if not key.is_empty():
            editor._painted_entities[key] = {"node": entry.get("node"), "data": entry.get("data")}
