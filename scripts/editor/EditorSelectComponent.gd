@tool
class_name EditorSelectComponent extends Area3D

## Editor-specific selection component for MapEditor entities.
## Handles collision detection (raycast), selection visual (wireframe box),
## and optional health bar. Replaces gameplay SelectComponent for editor use.

const HEALTH_BAR_CUBE_SIZE: float = 0.33333333

var cell_key: String = ""
var entry_data: Dictionary = {}
var is_selected: bool = false

var _selection_box: MeshInstance3D
var _health_bar: MeshInstance3D
var _box_shape: BoxShape3D
var _outline_shape: BoxShape3D
var _has_health: bool = false


func configure(entity_data: EntityData, p_cell_key: String, p_entry: Dictionary) -> void:
    cell_key = p_cell_key
    entry_data = p_entry

    collision_layer = 1 << 17
    collision_mask = 0

    var foundation: Vector2i = entity_data.foundation
    var entity_height: float = _resolve_entity_height(entity_data)
    var box_size := Vector3(
        float(foundation.x) * CellUtil.CELL_SIZE,
        entity_height,
        float(foundation.y) * CellUtil.CELL_SIZE,
    )

    _setup_hitbox(box_size)
    _setup_selection_box(box_size)
    _setup_health_bar(box_size)


func set_selected(value: bool) -> void:
    is_selected = value
    if _selection_box:
        _selection_box.visible = value
    if _health_bar:
        _health_bar.visible = value


func get_cell_key() -> String:
    return cell_key


func get_entry_data() -> Dictionary:
    return entry_data


func _resolve_entity_height(entity_data: EntityData) -> float:
    var height: float = 0.0
    var art: ArtData = entity_data.art_data
    if art and not art.model_path.is_empty() and ResourceLoader.exists(art.model_path):
        var scene := load(art.model_path) as PackedScene
        if scene:
            var instance := scene.instantiate()
            height = _find_max_y_recursive(instance)
            instance.queue_free()
    if height <= 0.01 and art and art.placeholder_size != Vector3.ZERO:
        height = art.placeholder_size.y
    if height <= 0.01:
        height = entity_data.height * TerrainSystem.HEIGHT_STEP
    return maxf(height, 1.5)


func _find_max_y_recursive(node: Node) -> float:
    var max_y := 0.0
    if node is MeshInstance3D:
        var mesh_inst := node as MeshInstance3D
        if mesh_inst.mesh:
            var aabb := mesh_inst.get_aabb()
            var top_y: float = aabb.position.y + aabb.size.y
            if top_y > max_y:
                max_y = top_y
    for child in node.get_children():
        var child_y := _find_max_y_recursive(child)
        if child_y > max_y:
            max_y = child_y
    return max_y


func _setup_hitbox(box_size: Vector3) -> void:
    _box_shape = BoxShape3D.new()
    _box_shape.size = box_size
    var hitbox := CollisionShape3D.new()
    hitbox.name = "SelectionHitbox"
    hitbox.shape = _box_shape
    hitbox.transform = Transform3D(Basis.IDENTITY, Vector3(0, box_size.y * 0.5, 0))
    hitbox.visible = false
    add_child(hitbox)

    _outline_shape = BoxShape3D.new()
    _outline_shape.size = box_size
    var outline := CollisionShape3D.new()
    outline.name = "SelectOutline"
    outline.shape = _outline_shape
    outline.transform = Transform3D(Basis.IDENTITY, Vector3(0, box_size.y * 0.5, 0))
    outline.visible = false
    outline.disabled = true
    add_child(outline)


func _setup_selection_box(box_size: Vector3) -> void:
    var mat := ORMMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color.WHITE
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED

    var half_xz := Vector2(box_size.x * 0.5, box_size.z * 0.5)
    var corners: Array[Vector3] = [
        Vector3(-half_xz.x, 0.0, -half_xz.y),
        Vector3(half_xz.x, 0.0, -half_xz.y),
        Vector3(half_xz.x, 0.0, half_xz.y),
        Vector3(-half_xz.x, 0.0, half_xz.y),
        Vector3(-half_xz.x, box_size.y, -half_xz.y),
        Vector3(half_xz.x, box_size.y, -half_xz.y),
        Vector3(half_xz.x, box_size.y, half_xz.y),
        Vector3(-half_xz.x, box_size.y, half_xz.y),
    ]
    var edges: Array[Array] = [
        [0, 1],
        [1, 2],
        [2, 3],
        [3, 0],
        [4, 5],
        [5, 6],
        [6, 7],
        [7, 4],
        [0, 4],
        [1, 5],
        [2, 6],
        [3, 7],
    ]

    var mesh := ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
    for edge in edges:
        mesh.surface_add_vertex(corners[edge[0]])
        mesh.surface_add_vertex(corners[edge[1]])
    mesh.surface_end()

    _selection_box = MeshInstance3D.new()
    _selection_box.name = "SelectionBox"
    _selection_box.mesh = mesh
    _selection_box.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
    _selection_box.visible = false
    add_child(_selection_box)


func _setup_health_bar(_box_size: Vector3) -> void:
    var parent := get_parent()
    if not parent:
        return
    var hp := parent.get_node_or_null("HealthComponent") as HealthComponent
    if not hp:
        return
    _has_health = true

    hp.health_changed.connect(_on_health_changed)

    var hit_box_size: Vector3 = _outline_shape.size
    var min_x: float = hit_box_size.x / -2.0
    var max_y: float = hit_box_size.y
    var min_z: float = hit_box_size.z / -2.0
    var max_z: float = hit_box_size.z / 2.0

    var health_value: float = (
        float(hp.current_health) / float(hp.max_health) if hp.max_health > 0 else 0.0
    )
    var health_bar_length: float = (max_z - min_z) * health_value
    var health_bar_z_pos: float = -((max_z - min_z) - health_bar_length) / 2.0

    _health_bar = MeshInstance3D.new()
    _health_bar.mesh = BoxMesh.new()
    _health_bar.name = "HealthBar"
    _health_bar.scale = Vector3(
        HEALTH_BAR_CUBE_SIZE - 0.02,
        HEALTH_BAR_CUBE_SIZE - 0.02,
        health_bar_length,
    )
    _health_bar.position = Vector3(
        min_x + HEALTH_BAR_CUBE_SIZE / 2.0,
        max_y - HEALTH_BAR_CUBE_SIZE / 2.0,
        health_bar_z_pos,
    )
    _health_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var bar_mat := ORMMaterial3D.new()
    bar_mat.albedo_color = _get_health_color(health_value)
    _health_bar.material_override = bar_mat
    _health_bar.visible = false
    add_child(_health_bar)


func _on_health_changed(_new_health: int, _old_health: int) -> void:
    _update_health_bar_visual()


func _update_health_bar_visual() -> void:
    if not _has_health or not is_instance_valid(_health_bar):
        return
    var parent := get_parent()
    if not parent:
        return
    var hp := parent.get_node_or_null("HealthComponent") as HealthComponent
    if not hp:
        return

    var hit_box_size: Vector3 = _outline_shape.size
    var min_z: float = hit_box_size.z / -2.0
    var max_z: float = hit_box_size.z / 2.0
    var health_value: float = (
        float(hp.current_health) / float(hp.max_health) if hp.max_health > 0 else 0.0
    )
    var health_bar_length: float = (max_z - min_z) * health_value
    var health_bar_z_pos: float = -((max_z - min_z) - health_bar_length) / 2.0
    _health_bar.position = Vector3(
        _health_bar.position.x,
        _health_bar.position.y,
        health_bar_z_pos,
    )
    _health_bar.scale = Vector3(
        _health_bar.scale.x,
        _health_bar.scale.y,
        health_bar_length,
    )
    var bar_mat: ORMMaterial3D = _health_bar.material_override as ORMMaterial3D
    if bar_mat:
        bar_mat.albedo_color = _get_health_color(health_value)


func _get_health_color(health_value: float) -> Color:
    if health_value > 0.5:
        return Color.GREEN
    elif health_value > 0.25:
        return Color.YELLOW
    elif health_value > 0.0:
        return Color.RED
    return Color(0.5, 0.0, 0.0)
