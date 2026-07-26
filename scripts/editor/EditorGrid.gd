extends Node

var editor: Node3D = null

var _grid_overlay: MeshInstance3D
var _cell_highlight: MeshInstance3D
var _highlight_quad_mat: ORMMaterial3D
var _highlight_line_mat: ORMMaterial3D
var _height_label: Label


func setup() -> void:
    _grid_overlay = MeshInstance3D.new()
    _grid_overlay.name = "GridOverlay"
    _grid_overlay.top_level = true
    editor.add_child(_grid_overlay)
    _draw_grid()
    _cell_highlight = MeshInstance3D.new()
    _cell_highlight.name = "CellHighlight"
    _cell_highlight.top_level = true
    editor.add_child(_cell_highlight)
    _highlight_quad_mat = ORMMaterial3D.new()
    _highlight_quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _highlight_quad_mat.albedo_color = Color(1, 1, 0, 0.7)
    _highlight_quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _highlight_quad_mat.render_priority = 1
    _highlight_line_mat = ORMMaterial3D.new()
    _highlight_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _highlight_line_mat.albedo_color = Color(0, 0, 0, 0.5)
    _highlight_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _highlight_line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    _highlight_line_mat.render_priority = 1


func update() -> void:
    if not editor:
        return
    _update_cell_highlight()
    _update_height_label()


func set_grid_visible(visible: bool) -> void:
    _grid_overlay.visible = visible


func _draw_grid() -> void:
    var mesh := ImmediateMesh.new()
    var material := ORMMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(1, 1, 1, 0.3)
    mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

    var cell_size := CellUtil.CELL_SIZE
    var cells_x: int = TerrainSystem.grid_cells.x
    var cells_z: int = TerrainSystem.grid_cells.y
    var half_w: float = float(cells_x) * 0.5 * cell_size
    var half_h: float = float(cells_z) * 0.5 * cell_size

    for i in range(cells_x + 1):
        var world_x: float = float(i) * cell_size - half_w
        var abs_x: float = absf(world_x)
        var ratio_x: float = abs_x / half_w if half_w > 0.0 else 0.0
        var z_limit: float = half_h * (1.0 - ratio_x)
        if z_limit > 0.0:
            mesh.surface_add_vertex(Vector3(world_x, 0.01, -z_limit))
            mesh.surface_add_vertex(Vector3(world_x, 0.01, z_limit))

    for j in range(cells_z + 1):
        var world_z: float = float(j) * cell_size - half_h
        var abs_z: float = absf(world_z)
        var ratio_z: float = abs_z / half_h if half_h > 0.0 else 0.0
        var x_limit: float = half_w * (1.0 - ratio_z)
        if x_limit > 0.0:
            mesh.surface_add_vertex(Vector3(-x_limit, 0.01, world_z))
            mesh.surface_add_vertex(Vector3(x_limit, 0.01, world_z))

    if half_w > 0.0 and half_h > 0.0:
        var tip_left := Vector3(-half_w, 0.01, 0.0)
        var tip_top := Vector3(0.0, 0.01, -half_h)
        var tip_right := Vector3(half_w, 0.01, 0.0)
        var tip_bottom := Vector3(0.0, 0.01, half_h)
        mesh.surface_add_vertex(tip_left)
        mesh.surface_add_vertex(tip_top)
        mesh.surface_add_vertex(tip_top)
        mesh.surface_add_vertex(tip_right)
        mesh.surface_add_vertex(tip_right)
        mesh.surface_add_vertex(tip_bottom)
        mesh.surface_add_vertex(tip_bottom)
        mesh.surface_add_vertex(tip_left)

    mesh.surface_end()
    _grid_overlay.mesh = mesh
    _grid_overlay.material_override = material


func _update_cell_highlight() -> void:
    if not _cell_highlight:
        return
    if editor._active_tool != editor.Tool.PAINT_HEIGHT:
        _cell_highlight.visible = false
        return
    var cell_data: Dictionary = TerrainSystem.get_cell(editor._hovered_cell)
    if cell_data.is_empty():
        _cell_highlight.visible = false
        return
    _cell_highlight.visible = true
    var mesh := ImmediateMesh.new()
    var world_pos := CellUtil.cell_to_world(editor._hovered_cell, TerrainSystem.grid_cells)
    var height: int = cell_data.get("max_height", cell_data.get("height", 0))
    world_pos.y = float(height) * TerrainSystem.HEIGHT_STEP + 0.02
    var half: float = CellUtil.CELL_SIZE * 0.475
    var lw: float = CellUtil.CELL_SIZE * 0.03
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _highlight_quad_mat)
    var y: float = world_pos.y
    var x0: float = world_pos.x - half
    var x1: float = world_pos.x + half
    var z0: float = world_pos.z - half
    var z1: float = world_pos.z + half
    # Front edge (z = z0)
    mesh.surface_add_vertex(Vector3(x0, y, z0 - lw))
    mesh.surface_add_vertex(Vector3(x1, y, z0 - lw))
    mesh.surface_add_vertex(Vector3(x1, y, z0 + lw))
    mesh.surface_add_vertex(Vector3(x0, y, z0 - lw))
    mesh.surface_add_vertex(Vector3(x1, y, z0 + lw))
    mesh.surface_add_vertex(Vector3(x0, y, z0 + lw))
    # Back edge (z = z1)
    mesh.surface_add_vertex(Vector3(x0, y, z1 - lw))
    mesh.surface_add_vertex(Vector3(x1, y, z1 - lw))
    mesh.surface_add_vertex(Vector3(x1, y, z1 + lw))
    mesh.surface_add_vertex(Vector3(x0, y, z1 - lw))
    mesh.surface_add_vertex(Vector3(x1, y, z1 + lw))
    mesh.surface_add_vertex(Vector3(x0, y, z1 + lw))
    # Left edge (x = x0)
    mesh.surface_add_vertex(Vector3(x0 - lw, y, z0))
    mesh.surface_add_vertex(Vector3(x0 + lw, y, z0))
    mesh.surface_add_vertex(Vector3(x0 + lw, y, z1))
    mesh.surface_add_vertex(Vector3(x0 - lw, y, z0))
    mesh.surface_add_vertex(Vector3(x0 + lw, y, z1))
    mesh.surface_add_vertex(Vector3(x0 - lw, y, z1))
    # Right edge (x = x1)
    mesh.surface_add_vertex(Vector3(x1 - lw, y, z0))
    mesh.surface_add_vertex(Vector3(x1 + lw, y, z0))
    mesh.surface_add_vertex(Vector3(x1 + lw, y, z1))
    mesh.surface_add_vertex(Vector3(x1 - lw, y, z0))
    mesh.surface_add_vertex(Vector3(x1 + lw, y, z1))
    mesh.surface_add_vertex(Vector3(x1 - lw, y, z1))
    mesh.surface_end()
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _highlight_line_mat)
    var drop: float = 2.0
    var pw: float = 0.04
    var corners: Array[Vector3] = [
        Vector3(x0, y, z0),
        Vector3(x1, y, z0),
        Vector3(x1, y, z1),
        Vector3(x0, y, z1),
    ]
    for c in corners:
        var cx: float = c.x
        var cy: float = c.y
        var cz: float = c.z
        var by: float = cy - drop
        mesh.surface_add_vertex(Vector3(cx - pw, cy, cz))
        mesh.surface_add_vertex(Vector3(cx + pw, cy, cz))
        mesh.surface_add_vertex(Vector3(cx + pw, by, cz))
        mesh.surface_add_vertex(Vector3(cx - pw, cy, cz))
        mesh.surface_add_vertex(Vector3(cx + pw, by, cz))
        mesh.surface_add_vertex(Vector3(cx - pw, by, cz))
        mesh.surface_add_vertex(Vector3(cx, cy, cz - pw))
        mesh.surface_add_vertex(Vector3(cx, cy, cz + pw))
        mesh.surface_add_vertex(Vector3(cx, by, cz + pw))
        mesh.surface_add_vertex(Vector3(cx, cy, cz - pw))
        mesh.surface_add_vertex(Vector3(cx, by, cz + pw))
        mesh.surface_add_vertex(Vector3(cx, by, cz - pw))
    mesh.surface_end()
    _cell_highlight.mesh = mesh
    _cell_highlight.material_override = null
    _cell_highlight.position = Vector3.ZERO


func _update_height_label() -> void:
    if not _height_label:
        return
    var cell: Vector2i = editor._hovered_cell
    var cell_data: Dictionary = TerrainSystem.get_cell(cell)
    var h: int = cell_data.get("height", 0)
    var cell_world := CellUtil.cell_to_world(cell, TerrainSystem.grid_cells)
    var wx: float = cell_world.x
    var wz: float = cell_world.z
    var wy: float = float(h) * TerrainSystem.HEIGHT_STEP
    _height_label.text = (
        "Cell: (%d,%d) | Pos: (%.1f, %.1f, %.1f) | H: %d" % [cell.x, cell.y, wx, wy, wz, h]
    )
