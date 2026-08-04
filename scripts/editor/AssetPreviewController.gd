extends Node3D

## Asset preview scene controller: browse every theater-registered TerrainObject
## family, cycle its four directional variants, and inspect it through stackable
## render states (mesh / vector footprint / collision AABB / theater context)
## while an info box shows the object's data. Camera: reused iso Camera01 by
## default, plus a free-orbit rig and an auto-turntable.
## Dev tool only — no gameplay logic.

const THEATER_PATH: String = "res://resources/theaters/temperate.tres"
const DIRECTIONS: Array[String] = ["n", "e", "s", "w"]

const STATE_MESH := 0
const STATE_VECTOR := 1
const STATE_COLLISION := 2
const STATE_THEATER := 3
const _STATE_NAMES := {
    STATE_MESH: "Mesh",
    STATE_VECTOR: "Vector",
    STATE_COLLISION: "Collision",
    STATE_THEATER: "Theater",
}

var _theater: TheaterData = null
var _families: Array[Dictionary] = []
var _family_index := 0
var _direction_index := 0
var _spin_enabled := false
var _spin_rotation := 0.0
var _camera_mode_orbital := false

var _states: Dictionary = {
    STATE_MESH: true,
    STATE_VECTOR: false,
    STATE_COLLISION: false,
    STATE_THEATER: false,
}
var _state_focus := STATE_MESH

var _bounds := AABB()
var _min_height := 0

var _glb_mesh_cache: Dictionary = {}

var _object_root: Node3D = null
var _mesh_pivot: Node3D = null
var _gameplay_camera: Node = null
var _iso_camera: Camera3D = null
var _orbit_rig: Node3D = null
var _orbit_camera: Camera3D = null

var _mesh_node: MeshInstance3D = null
var _vector_mesh: MeshInstance3D = null
var _collision_mesh: MeshInstance3D = null
var _theater_label: Label3D = null
var _highlight_mesh: MeshInstance3D = null
var _axis_mesh: MeshInstance3D = null

var _family_dropdown: OptionButton = null
var _direction_button: Button = null
var _cam_button: CheckButton = null
var _spin_button: CheckButton = null
var _state_buttons: Dictionary = {}
var _info_header: Label = null
var _info_stats: Label = null
var _info_context: Label = null
var _cell_list: VBoxContainer = null
var _cached_materials: Dictionary = {}


func _ready() -> void:
    _theater = load(THEATER_PATH) as TheaterData
    if _theater == null:
        push_error("AssetPreview: theater missing at " + THEATER_PATH)
        return
    _build_families()
    _object_root = get_node("ObjectRoot")
    _mesh_pivot = Node3D.new()
    _mesh_pivot.name = "MeshPivot"
    _object_root.add_child(_mesh_pivot)
    _gameplay_camera = get_node_or_null("GameplayCamera")
    _iso_camera = get_node_or_null("GameplayCamera/Camera3D") as Camera3D
    _orbit_rig = get_node_or_null("OrbitRig") as Node3D
    if _orbit_rig != null:
        _orbit_camera = _orbit_rig.get_node_or_null("Camera3D") as Camera3D
        _orbit_rig.target = _mesh_pivot
    _build_axis_mesh()
    _build_hud()
    _select_family(0)
    _set_camera_mode(false)


func _process(delta: float) -> void:
    if _spin_enabled and _mesh_pivot != null:
        _spin_rotation += delta * 0.6
        _apply_facing()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("asset_preview_next"):
        next_family()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("asset_preview_prev"):
        prev_family()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("asset_preview_dir_cycle"):
        cycle_direction()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("asset_preview_cam_toggle"):
        toggle_camera_mode()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("asset_preview_spin"):
        toggle_spin()
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("asset_preview_state_cycle"):
        cycle_state()
        get_viewport().set_input_as_handled()


# --- Public API (also exercised by tests) ---


func current_object_id() -> String:
    var base: String = _families[_family_index]["base"] if not _families.is_empty() else ""
    if base.is_empty():
        return ""
    return base + "_" + DIRECTIONS[_direction_index]


func get_family_count() -> int:
    return _families.size()


func current_object() -> TerrainObject:
    if _families.is_empty():
        return null
    var variants: Dictionary = _families[_family_index]["variants"]
    return variants.get(DIRECTIONS[_direction_index]) as TerrainObject


func get_theater() -> TheaterData:
    return _theater


func get_mesh_node() -> MeshInstance3D:
    return _mesh_node


func get_mesh_pivot() -> Node3D:
    return _mesh_pivot


func get_state(state: int) -> bool:
    return bool(_states.get(state, false))


func get_state_focus() -> int:
    return _state_focus


func is_orbit_active() -> bool:
    return _camera_mode_orbital


func is_spin_enabled() -> bool:
    return _spin_enabled


func get_object_root() -> Node3D:
    return _object_root


func next_family() -> void:
    if _families.is_empty():
        return
    _select_family((_family_index + 1) % _families.size())


func prev_family() -> void:
    if _families.is_empty():
        return
    _select_family((_family_index - 1 + _families.size()) % _families.size())


func select_family(index: int) -> void:
    _select_family(clampi(index, 0, _families.size() - 1))


func cycle_direction() -> void:
    _direction_index = (_direction_index + 1) % DIRECTIONS.size()
    _spin_rotation = 0.0
    _rebuild_display()
    _sync_hud()


func select_direction(direction: String) -> void:
    var idx := DIRECTIONS.find(direction)
    if idx == -1:
        return
    _direction_index = idx
    _spin_rotation = 0.0
    _rebuild_display()
    _sync_hud()


func toggle_camera_mode() -> void:
    _set_camera_mode(not _camera_mode_orbital)
    _sync_hud()


func toggle_spin() -> void:
    _spin_enabled = not _spin_enabled
    if not _spin_enabled:
        _spin_rotation = 0.0
        _apply_facing()
    _sync_hud()


func set_state(state: int, enabled: bool) -> void:
    if not _states.has(state):
        return
    _states[state] = enabled
    _update_state_visibility()
    _sync_hud()


func cycle_state() -> void:
    _state_focus = (_state_focus + 1) % _STATE_NAMES.size()
    set_state(_state_focus, not get_state(_state_focus))


# --- Setup ---


func _build_families() -> void:
    var variants: Dictionary = TerrainCatalog.get_all_objects()
    var by_base: Dictionary = {}
    for object_id in variants:
        var id_str := String(object_id)
        var suffix := ""
        for dir in DIRECTIONS:
            if id_str.ends_with("_" + dir):
                suffix = dir
                break
        if suffix == "":
            continue
        var base := id_str.substr(0, id_str.length() - suffix.length() - 1)
        var fam: Dictionary = by_base.get(base, {"base": base, "variants": {}})
        fam["variants"][suffix] = variants[object_id]
        by_base[base] = fam
    var bases: Array = by_base.keys()
    bases.sort()
    for b in bases:
        _families.append(by_base[b])


func _ensure_glb(glb_path: String) -> void:
    if glb_path.is_empty() or _glb_mesh_cache.has(glb_path):
        return
    var scene := load(glb_path) as PackedScene
    if scene == null:
        push_error("AssetPreview: cannot load GLB " + glb_path)
        return
    var instance := scene.instantiate()
    _collect_glb_meshes(instance, glb_path)
    instance.free()


func _collect_glb_meshes(node: Node, glb_path: String) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        var clean_name := (mesh_instance.name as String).trim_suffix("_3D")
        var cache: Dictionary = _glb_mesh_cache.get(glb_path, {})
        if not cache.has(clean_name) and mesh_instance.mesh != null:
            cache[clean_name] = mesh_instance.mesh
            _glb_mesh_cache[glb_path] = cache
    for child in node.get_children():
        _collect_glb_meshes(child, glb_path)


func _resolved_art() -> TerrainArtData.ArtResolution:
    return TerrainCatalog.resolve_art(current_object_id(), TerrainCatalog.get_active_theater_id())


func _art_rotation() -> float:
    return _resolved_art().rotation


func _line_material(name: String, color: Color) -> ORMMaterial3D:
    if _cached_materials.has(name):
        return _cached_materials[name]
    var mat := ORMMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = color
    _cached_materials[name] = mat
    return mat


# --- Display selection / rebuild ---


func _select_family(index: int) -> void:
    if _families.is_empty():
        return
    _family_index = clampi(index, 0, _families.size() - 1)
    _direction_index = 0
    _spin_rotation = 0.0
    _rebuild_display()
    _sync_hud()


func _rebuild_display() -> void:
    var obj := current_object()
    if obj == null:
        return
    _clear_object_children()
    _bounds = TerrainObject.footprint_bounds(obj)
    _min_height = int(_bounds.position.y)
    _object_root.position = Vector3(
        _bounds.position.x * CellUtil.CELL_SIZE,
        _min_height * TerrainSystem.HEIGHT_STEP,
        _bounds.position.z * CellUtil.CELL_SIZE
    )
    if _mesh_pivot != null:
        _mesh_pivot.position = _footprint_center_local()
    _build_mesh_state()
    _build_vector_state()
    _build_collision_state()
    _build_theater_state()
    _update_state_visibility()
    _apply_facing()
    _update_info_box()


func _apply_facing() -> void:
    if _mesh_pivot != null:
        _mesh_pivot.rotation.y = deg_to_rad(_art_rotation()) + _spin_rotation


func _footprint_center_local() -> Vector3:
    return Vector3(
        _bounds.size.x * CellUtil.CELL_SIZE * 0.5,
        _bounds.size.y * TerrainSystem.HEIGHT_STEP * 0.5,
        _bounds.size.z * CellUtil.CELL_SIZE * 0.5
    )


func _clear_object_children() -> void:
    if _mesh_node != null and is_instance_valid(_mesh_node):
        _mesh_node.queue_free()
        _mesh_node = null
    for child in _object_root.get_children():
        if child == _mesh_pivot:
            continue
        _object_root.remove_child(child)
        child.queue_free()
    _vector_mesh = null
    _collision_mesh = null
    _theater_label = null
    _highlight_mesh = null


# --- Render states ---


func _build_mesh_state() -> void:
    var resolution := _resolved_art()
    if not resolution.valid or resolution.glb_path.is_empty():
        return
    _ensure_glb(resolution.glb_path)
    var meshes: Dictionary = _glb_mesh_cache.get(resolution.glb_path, {})
    var mesh: Mesh = meshes.get(resolution.submesh_id, null)
    if mesh == null:
        return
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "Mesh_" + current_object_id()
    mesh_instance.mesh = mesh
    if _mesh_pivot != null:
        mesh_instance.position = -_footprint_center_local()
        _mesh_pivot.add_child(mesh_instance)
    else:
        _object_root.add_child(mesh_instance)
    _mesh_node = mesh_instance


func _resolved_mesh_name() -> String:
    return _resolved_art().submesh_id


func _build_vector_state() -> void:
    var obj := current_object()
    if obj == null:
        return
    var immesh := ImmediateMesh.new()
    var mat := _line_material("preview_vector", Color(0.0, 1.0, 1.0, 1.0))
    var half := CellUtil.CELL_SIZE
    for key in obj.cells:
        var parts: PackedStringArray = String(key).split(",")
        if parts.size() != 2:
            continue
        var x := int(parts[0])
        var z := int(parts[1])
        var entry: Variant = obj.cells.get(key, {})
        var corners: Array = entry.get("corners", []) if entry is Dictionary else []
        var c0 := _corner_local(x, z, 0, corners)
        var c1 := _corner_local(x, z, 1, corners)
        var c2 := _corner_local(x, z, 2, corners)
        var c3 := _corner_local(x, z, 3, corners)
        var b0 := _cell_corner_local(x, z, 0, 0.0)
        var b1 := _cell_corner_local(x, z, 1, 0.0)
        var b2 := _cell_corner_local(x, z, 2, 0.0)
        var b3 := _cell_corner_local(x, z, 3, 0.0)
        immesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
        immesh.surface_add_vertex(c0)
        immesh.surface_add_vertex(c1)
        immesh.surface_add_vertex(c1)
        immesh.surface_add_vertex(c2)
        immesh.surface_add_vertex(c2)
        immesh.surface_add_vertex(c3)
        immesh.surface_add_vertex(c3)
        immesh.surface_add_vertex(c0)
        immesh.surface_add_vertex(b0)
        immesh.surface_add_vertex(b1)
        immesh.surface_add_vertex(b1)
        immesh.surface_add_vertex(b2)
        immesh.surface_add_vertex(b2)
        immesh.surface_add_vertex(b3)
        immesh.surface_add_vertex(b3)
        immesh.surface_add_vertex(b0)
        immesh.surface_add_vertex(c0)
        immesh.surface_add_vertex(b0)
        immesh.surface_add_vertex(c1)
        immesh.surface_add_vertex(b1)
        immesh.surface_add_vertex(c2)
        immesh.surface_add_vertex(b2)
        immesh.surface_add_vertex(c3)
        immesh.surface_add_vertex(b3)
        immesh.surface_end()
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "VectorFootprint"
    mesh_instance.mesh = immesh
    _object_root.add_child(mesh_instance)
    _vector_mesh = mesh_instance


func _build_collision_state() -> void:
    var lo := Vector3(
        _bounds.position.x * CellUtil.CELL_SIZE, 0.0, _bounds.position.z * CellUtil.CELL_SIZE
    )
    var hi := Vector3(
        (_bounds.position.x + _bounds.size.x) * CellUtil.CELL_SIZE,
        maxf(_bounds.size.y * TerrainSystem.HEIGHT_STEP, TerrainSystem.HEIGHT_STEP),
        (_bounds.position.z + _bounds.size.z) * CellUtil.CELL_SIZE
    )
    var corners := [
        lo,
        Vector3(hi.x, lo.y, lo.z),
        Vector3(hi.x, lo.y, hi.z),
        Vector3(lo.x, lo.y, hi.z),
        Vector3(lo.x, hi.y, lo.z),
        Vector3(hi.x, hi.y, lo.z),
        hi,
        Vector3(lo.x, hi.y, hi.z),
    ]
    var edges := [
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
    var immesh := ImmediateMesh.new()
    var mat := _line_material("preview_collision", Color(1.0, 1.0, 0.0, 1.0))
    immesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
    for edge in edges:
        immesh.surface_add_vertex(corners[edge[0]])
        immesh.surface_add_vertex(corners[edge[1]])
    immesh.surface_end()
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "CollisionBox"
    mesh_instance.mesh = immesh
    _object_root.add_child(mesh_instance)
    _collision_mesh = mesh_instance


func _build_theater_state() -> void:
    var label := Label3D.new()
    label.name = "TheaterContext"
    label.text = ("Theater: %s" % [_theater.id])
    label.pixel_size = 0.01
    label.font_size = 64
    label.no_depth_test = true
    label.position = Vector3(
        _bounds.size.x * CellUtil.CELL_SIZE * 0.5,
        _bounds.size.y * TerrainSystem.HEIGHT_STEP + 1.5,
        _bounds.size.z * CellUtil.CELL_SIZE * 0.5
    )
    _object_root.add_child(label)
    _theater_label = label


func _update_state_visibility() -> void:
    if _mesh_node != null:
        _mesh_node.visible = get_state(STATE_MESH)
    if _vector_mesh != null:
        _vector_mesh.visible = get_state(STATE_VECTOR)
    if _collision_mesh != null:
        _collision_mesh.visible = get_state(STATE_COLLISION)
    if _theater_label != null:
        _theater_label.visible = get_state(STATE_THEATER)


func _build_axis_mesh() -> void:
    var immesh := ImmediateMesh.new()
    var x_mat := _line_material("preview_axis_x", Color(1.0, 0.2, 0.2, 1.0))
    var z_mat := _line_material("preview_axis_z", Color(0.2, 0.2, 1.0, 1.0))
    var len := 6.0
    immesh.surface_begin(Mesh.PRIMITIVE_LINES, x_mat)
    immesh.surface_add_vertex(Vector3(0, 0.02, 0))
    immesh.surface_add_vertex(Vector3(len, 0.02, 0))
    immesh.surface_end()
    immesh.surface_begin(Mesh.PRIMITIVE_LINES, z_mat)
    immesh.surface_add_vertex(Vector3(0, 0.02, 0))
    immesh.surface_add_vertex(Vector3(0, 0.02, len))
    immesh.surface_end()
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "AxisLines"
    mesh_instance.mesh = immesh
    add_child(mesh_instance)
    _axis_mesh = mesh_instance


func _corner_local(x: int, z: int, corner_index: int, corners: Array) -> Vector3:
    var h := 0.0
    if corners.size() == 4:
        h = float(int(corners[corner_index]) - _min_height) * TerrainSystem.HEIGHT_STEP
    return _cell_corner_local(x, z, corner_index, h)


func _cell_corner_local(x: int, z: int, corner_index: int, height: float) -> Vector3:
    var offsets: Array[Vector2] = [
        Vector2(0.0, 0.0),
        Vector2(CellUtil.CELL_SIZE, 0.0),
        Vector2(CellUtil.CELL_SIZE, CellUtil.CELL_SIZE),
        Vector2(0.0, CellUtil.CELL_SIZE),
    ]
    var o: Vector2 = offsets[corner_index]
    return Vector3(x * CellUtil.CELL_SIZE + o.x, height, z * CellUtil.CELL_SIZE + o.y)


func _highlight_cell(cell_key: String) -> void:
    if _highlight_mesh != null:
        _object_root.remove_child(_highlight_mesh)
        _highlight_mesh.queue_free()
        _highlight_mesh = null
    var parts: PackedStringArray = cell_key.split(",")
    if parts.size() != 2:
        return
    var x := int(parts[0])
    var z := int(parts[1])
    var obj := current_object()
    if obj == null:
        return
    var entry: Variant = obj.cells.get(cell_key, {})
    var corners: Array = entry.get("corners", []) if entry is Dictionary else []
    var top := [
        _corner_local(x, z, 0, corners),
        _corner_local(x, z, 1, corners),
        _corner_local(x, z, 2, corners),
        _corner_local(x, z, 3, corners),
    ]
    var bottom := [
        _cell_corner_local(x, z, 0, 0.0),
        _cell_corner_local(x, z, 1, 0.0),
        _cell_corner_local(x, z, 2, 0.0),
        _cell_corner_local(x, z, 3, 0.0),
    ]
    var immesh := ImmediateMesh.new()
    var mat := _line_material("preview_highlight", Color(0.0, 1.0, 0.2, 1.0))
    immesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
    for i in 4:
        immesh.surface_add_vertex(top[i])
        immesh.surface_add_vertex(top[(i + 1) % 4])
        immesh.surface_add_vertex(bottom[i])
        immesh.surface_add_vertex(bottom[(i + 1) % 4])
        immesh.surface_add_vertex(top[i])
        immesh.surface_add_vertex(bottom[i])
    immesh.surface_end()
    _highlight_mesh = MeshInstance3D.new()
    _highlight_mesh.name = "CellHighlight"
    _highlight_mesh.mesh = immesh
    _object_root.add_child(_highlight_mesh)


# --- Camera ---


func _set_camera_mode(orbital: bool) -> void:
    _camera_mode_orbital = orbital
    if _gameplay_camera != null:
        _gameplay_camera.process_mode = (
            Node.PROCESS_MODE_DISABLED if orbital else Node.PROCESS_MODE_INHERIT
        )
    if _iso_camera != null:
        _iso_camera.current = not orbital
    if _orbit_camera != null:
        _orbit_camera.current = orbital


# --- HUD ---


func _build_hud() -> void:
    var hud := get_node("HUD")
    var top := HBoxContainer.new()
    top.name = "TopBar"
    top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 8.0
    top.offset_top = 8.0
    top.offset_right = -8.0
    hud.add_child(top)

    var prev := Button.new()
    prev.text = "< Prev"
    prev.tooltip_text = "Previous family (Left arrow)"
    prev.pressed.connect(prev_family)
    top.add_child(prev)

    _family_dropdown = OptionButton.new()
    _family_dropdown.tooltip_text = "Pick a base family"
    for fam in _families:
        _family_dropdown.add_item(fam["base"])
    _family_dropdown.item_selected.connect(select_family)
    top.add_child(_family_dropdown)

    var next := Button.new()
    next.text = "Next >"
    next.tooltip_text = "Next family (Right arrow)"
    next.pressed.connect(next_family)
    top.add_child(next)

    _direction_button = Button.new()
    _direction_button.tooltip_text = "Cycle direction N/E/S/W (R)"
    _direction_button.pressed.connect(cycle_direction)
    top.add_child(_direction_button)

    top.add_child(HSeparator.new())

    _cam_button = CheckButton.new()
    _cam_button.text = "Orbit"
    _cam_button.tooltip_text = "Free orbit around the object (C)"
    _cam_button.toggled.connect(func(on: bool) -> void: toggle_camera_mode())
    top.add_child(_cam_button)

    _spin_button = CheckButton.new()
    _spin_button.text = "Spin"
    _spin_button.tooltip_text = "Auto-turntable around Y axis (T)"
    _spin_button.toggled.connect(func(on: bool) -> void: toggle_spin())
    top.add_child(_spin_button)

    var states_row := HBoxContainer.new()
    states_row.name = "StatesRow"
    states_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    states_row.offset_left = 8.0
    states_row.offset_top = 42.0
    states_row.offset_right = -8.0
    hud.add_child(states_row)

    for state in [STATE_MESH, STATE_VECTOR, STATE_COLLISION, STATE_THEATER]:
        var cb := CheckButton.new()
        cb.text = _STATE_NAMES[state]
        cb.button_pressed = get_state(state)
        cb.toggled.connect(func(on: bool, s: int = state) -> void: set_state(s, on))
        states_row.add_child(cb)
        _state_buttons[state] = cb

    var hint := Label.new()
    hint.text = "State cycle: F"
    hint.modulate = Color(1, 1, 1, 0.6)
    states_row.add_child(hint)

    var panel := PanelContainer.new()
    panel.name = "InfoPanel"
    panel.anchor_left = 0.72
    panel.anchor_right = 1.0
    panel.anchor_top = 0.0
    panel.anchor_bottom = 1.0
    panel.offset_left = 8.0
    panel.offset_top = 8.0
    panel.offset_right = -8.0
    panel.offset_bottom = -8.0
    hud.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 8)
    margin.add_theme_constant_override("margin_right", 8)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    panel.add_child(margin)

    var vbox := VBoxContainer.new()
    margin.add_child(vbox)

    _info_header = Label.new()
    _info_header.add_theme_font_size_override("font_size", 16)
    vbox.add_child(_info_header)

    _info_stats = Label.new()
    vbox.add_child(_info_stats)

    _info_context = Label.new()
    vbox.add_child(_info_context)

    vbox.add_child(HSeparator.new())

    var cells_label := Label.new()
    cells_label.text = "Cells (click to highlight)"
    vbox.add_child(cells_label)

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, 0)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(scroll)

    _cell_list = VBoxContainer.new()
    _cell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_cell_list)


func _sync_hud() -> void:
    if _family_dropdown != null and not _families.is_empty():
        _family_dropdown.select(_family_index)
    if _direction_button != null:
        _direction_button.text = "Facing: " + DIRECTIONS[_direction_index].to_upper()
    if _cam_button != null:
        _cam_button.set_pressed_no_signal(_camera_mode_orbital)
    if _spin_button != null:
        _spin_button.set_pressed_no_signal(_spin_enabled)
    for state in _state_buttons:
        var cb: CheckButton = _state_buttons[state]
        if cb.is_pressed() != get_state(state):
            cb.set_pressed_no_signal(get_state(state))


func _update_info_box() -> void:
    var obj := current_object()
    if obj == null:
        return
    var id := current_object_id()
    _info_header.text = (
        "%s\n%s  (%s)"
        % [
            obj.display_name if not obj.display_name.is_empty() else obj.id,
            id,
            DIRECTIONS[_direction_index].to_upper(),
        ]
    )
    var land_types := {}
    for key in obj.cells:
        var entry: Variant = obj.cells.get(key, {})
        if entry is Dictionary:
            var land := String(entry.get("land", ""))
            if not land.is_empty():
                land_types[land] = true
    _info_stats.text = (
        (
            "Cell type: %s\nGrid: %dx%d cells, %d occupied\n"
            % [
                obj.cell_type,
                int(_bounds.size.x),
                int(_bounds.size.z),
                obj.cells.size(),
            ]
        )
        + (
            "Heights: %d..%d\nLand: %s"
            % [
                _min_height,
                _min_height + int(_bounds.size.y),
                ", ".join(land_types.keys()),
            ]
        )
    )
    var resolution := _resolved_art()
    var glb_file := resolution.glb_path.get_file() if resolution.valid else "-"
    var submesh := resolution.submesh_id if resolution.valid else "-"
    var base := current_object_id()
    var fallback := ""
    if resolution.valid and submesh != base and resolution.submesh_id != base:
        fallback = " (submesh -> %s)" % submesh
    _info_context.text = (
        ("Theater: %s\nArt: %s\n" + "Mesh: %s%s\nRotation: %d deg")
        % [
            _theater.id,
            glb_file,
            _resolved_mesh_name(),
            fallback,
            int(_art_rotation()),
        ]
    )
    _rebuild_cell_list(obj)


func _rebuild_cell_list(obj: TerrainObject) -> void:
    for child in _cell_list.get_children():
        _cell_list.remove_child(child)
        child.queue_free()
    var keys: Array = obj.cells.keys()
    keys.sort_custom(_cell_key_less)
    for key in keys:
        var entry: Variant = obj.cells.get(key, {})
        var cell: Dictionary = {}
        if entry is Dictionary:
            cell = entry
        var corners: Array = cell.get("corners", [])
        var crease := String(cell.get("crease", ""))
        var slope := int(cell.get("slope", 0))
        var land := String(cell.get("land", ""))
        var conns: Variant = cell.get("connections", {})
        var conn_text := ""
        if conns is Dictionary and not (conns as Dictionary).is_empty():
            var parts_list: Array[String] = []
            for edge in conns as Dictionary:
                var role := String((conns as Dictionary)[edge].get("role", ""))
                parts_list.append("%s:%s" % [edge, role])
            conn_text = "  " + ", ".join(parts_list)
        var row := Button.new()
        row.text = (
            "%s  %s  corners %s  crease %s  slope %d%s"
            % [
                key,
                land,
                str(corners),
                crease,
                slope,
                conn_text,
            ]
        )
        row.alignment = HORIZONTAL_ALIGNMENT_LEFT
        row.pressed.connect(_highlight_cell.bind(String(key)))
        _cell_list.add_child(row)


func _cell_key_less(a: Variant, b: Variant) -> bool:
    var pa: PackedStringArray = String(a).split(",")
    var pb: PackedStringArray = String(b).split(",")
    if pa.size() != 2 or pb.size() != 2:
        return String(a) < String(b)
    if int(pa[0]) != int(pb[0]):
        return int(pa[0]) < int(pb[0])
    return int(pa[1]) < int(pb[1])
