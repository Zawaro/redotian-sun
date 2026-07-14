extends Node
class_name MapLoader

const OVERRIDE_KEYS: PackedStringArray = [
    "strength",
    "resource_type_id",
    "resource_regrowth_rate",
    "radius_cells",
    "node_count",
    "spawn_strength",
    "max_spawn_strength",
]


static func load_map_into(path: String, parent: Node) -> Array[Dictionary]:
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        push_error("MapLoader: Cannot open file: %s" % path)
        return []
    var text := file.get_as_text()
    file.close()
    var json := JSON.parse_string(text) as Dictionary
    if json == null:
        push_error("MapLoader: Invalid JSON: %s" % path)
        return []

    TerrainSystem.import_from_json(path)

    var grid_half: float = float(TerrainSystem.grid_cells) * Pathfinder.CELL_SIZE * 0.5
    var result: Array[Dictionary] = []
    var entities: Array = json.get("entities", [])
    for entry in entities:
        var entry_dict := entry as Dictionary
        if entry_dict == null:
            continue
        var entity_id: String = entry_dict.get("id", "")
        if entity_id.is_empty():
            continue
        var overrides: Dictionary = {}
        for key in OVERRIDE_KEYS:
            if entry_dict.has(key):
                overrides[key] = entry_dict[key]
        var entity := EntityFactory.create_entity(entity_id, overrides)
        if not entity:
            continue
        var cell_str: String = entry_dict.get("cell", "")
        if not cell_str.is_empty():
            var parts := cell_str.split(",")
            if parts.size() == 2:
                var cell := Vector2i(parts[0].to_int(), parts[1].to_int())
                var world_pos := Pathfinder.cell_to_world(cell) - Vector3(grid_half, 0.0, grid_half)
                var cell_data: Dictionary = TerrainSystem.get_cell(cell)
                if not cell_data.is_empty():
                    var h: int = cell_data.get("max_height", cell_data.get("height", 0))
                    world_pos.y = float(h) * TerrainSystem.HEIGHT_STEP
                entity.position = world_pos
        parent.add_child(entity)
        result.append({"key": cell_str, "node": entity, "data": entry_dict})
    return result
