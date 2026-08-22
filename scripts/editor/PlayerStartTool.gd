extends Node

## MapEditor tool for player start locations. Follows the HeightPainter /
## ResourcePainter node pattern: created by MapEditor, receives input via the
## editor's dispatch, and owns its world-space marker rendering.

const _FALLBACK_COLORS: Array[Color] = [
    Color(0.3, 0.6, 0.9),
    Color(0.9, 0.3, 0.3),
    Color(0.3, 0.9, 0.3),
    Color(0.9, 0.9, 0.3),
    Color(0.9, 0.4, 0.2),
    Color(0.6, 0.3, 0.9),
    Color(0.3, 0.9, 0.9),
    Color(0.8, 0.8, 0.8),
]

## Player id -> assigned cell. Absent player uses BoundsSystem.default_start_cell.
var _overrides: Dictionary = {}
var _player_count: int = 2
var _marker: MeshInstance3D


func setup(marker_parent: Node3D) -> void:
    _marker = MeshInstance3D.new()
    _marker.name = "PlayerStartMarkers"
    _marker.top_level = true
    marker_parent.add_child(_marker)
    rebuild()


func cleanup() -> void:
    if _marker and is_instance_valid(_marker):
        _marker.queue_free()
        _marker = null


func set_player_count(count: int) -> void:
    _player_count = maxi(count, 1)
    rebuild()


func assign(player_id: int, cell: Vector2i) -> void:
    _overrides[player_id] = cell
    rebuild()


func reset(player_id: int) -> void:
    _overrides.erase(player_id)
    rebuild()


func clear() -> void:
    _overrides.clear()
    rebuild()


func has_override(player_id: int) -> bool:
    return _overrides.has(player_id)


func effective_cell(player_id: int) -> Vector2i:
    if _overrides.has(player_id):
        return _overrides[player_id] as Vector2i
    return BoundsSystem.default_start_cell(player_id)


func save_data() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for player_id in _overrides:
        (
            result
            . append(
                {
                    "player_id": player_id,
                    "cell": CellUtil.cell_key_str(_overrides[player_id] as Vector2i),
                }
            )
        )
    return result


func load_data(data: Array) -> void:
    _overrides.clear()
    for item in data:
        var entry := item as Dictionary
        if entry == null:
            continue
        var player_id: int = int(entry.get("player_id", -1))
        if player_id < 0:
            continue
        var cell_str: String = entry.get("cell", "")
        var parts := cell_str.split(",")
        if parts.size() == 2:
            _overrides[player_id] = Vector2i(parts[0].to_int(), parts[1].to_int())
    rebuild()


func _player_color(player_id: int) -> Color:
    if player_id >= 0 and player_id < _FALLBACK_COLORS.size():
        return _FALLBACK_COLORS[player_id]
    return Color.WHITE


func rebuild() -> void:
    if not _marker or not is_instance_valid(_marker):
        return
    var mesh := ImmediateMesh.new()
    for player_id in range(_player_count):
        var cell: Vector2i = effective_cell(player_id)
        var world_pos := CellUtil.cell_to_world(cell)
        var terrain_y: float = TerrainSystem.get_height_at_world_smooth(world_pos)
        var y: float = terrain_y + 0.25
        var color: Color = _player_color(player_id)
        var half: float = CellUtil.CELL_SIZE * 0.4
        mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _marker_material(color))
        mesh.surface_add_vertex(Vector3(world_pos.x - half, y, world_pos.z - half))
        mesh.surface_add_vertex(Vector3(world_pos.x + half, y, world_pos.z - half))
        mesh.surface_add_vertex(Vector3(world_pos.x + half, y, world_pos.z + half))
        mesh.surface_add_vertex(Vector3(world_pos.x - half, y, world_pos.z - half))
        mesh.surface_add_vertex(Vector3(world_pos.x + half, y, world_pos.z + half))
        mesh.surface_add_vertex(Vector3(world_pos.x - half, y, world_pos.z + half))
        mesh.surface_end()
    _marker.mesh = mesh


func _marker_material(color: Color) -> ORMMaterial3D:
    var mat := ORMMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = color
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.render_priority = 1
    return mat
