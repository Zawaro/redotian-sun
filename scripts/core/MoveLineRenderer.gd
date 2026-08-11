extends Node

## Shared batched renderer for transient gameplay lines (move-target and rally
## lines). All registered line sources draw through ONE ImmediateMesh rebuilt
## once per frame — 60 per-unit meshes become a single buffer + draw call.
## Sources are pulled each frame, so per-line endpoints (e.g. an attack target
## being tracked) update without per-unit mesh churn.

const LINE_COLOR := Color(0.0, 0.8, 0.0)

var _line_mesh: MeshInstance3D = null
var _material: ORMMaterial3D = null
var _sources: Dictionary = {}


func _ready() -> void:
    _material = ORMMaterial3D.new()
    _material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material.vertex_color_use_as_albedo = true
    _material.no_depth_test = true
    _material.render_priority = 100
    _line_mesh = MeshInstance3D.new()
    _line_mesh.name = "MoveLineBatch"
    _line_mesh.material_override = _material
    _line_mesh.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_line_mesh)


func register(source: Node) -> void:
    _sources[source] = true


func unregister(source: Node) -> void:
    _sources.erase(source)


func _process(_delta: float) -> void:
    var immesh := _line_mesh.mesh as ImmediateMesh
    if immesh == null:
        immesh = ImmediateMesh.new()
        _line_mesh.mesh = immesh
    immesh.clear_surfaces()
    var visible: Array[Dictionary] = []
    for source in _sources.keys():
        if not is_instance_valid(source):
            _sources.erase(source)
            continue
        var data: Dictionary = source.get_line_render_data()
        if float(data.get("alpha", 0.0)) > 0.01:
            visible.append(data)
    if visible.is_empty():
        return
    immesh.surface_begin(Mesh.PRIMITIVE_LINES, _material)
    for data: Dictionary in visible:
        var col := Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, float(data["alpha"]))
        immesh.surface_set_color(col)
        immesh.surface_add_vertex(data["origin"] as Vector3)
        immesh.surface_add_vertex(data["target"] as Vector3)
    immesh.surface_end()
    immesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
    for data: Dictionary in visible:
        var col := Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, float(data["alpha"]))
        immesh.surface_set_color(col)
        _draw_marker(
            immesh,
            data["target"] as Vector3,
            float(data["marker_half"]),
            bool(data.get("marker_diamond", false)),
        )
    immesh.surface_end()


## Filled destination marker: a square (move-target) or diamond (rally), laid on
## the ground plane, 6 vertices (two triangles) per marker.
func _draw_marker(immesh: ImmediateMesh, pos: Vector3, half: float, diamond: bool) -> void:
    if diamond:
        var corners := [
            pos + Vector3(half, 0, 0),
            pos + Vector3(0, 0, half),
            pos + Vector3(-half, 0, 0),
            pos + Vector3(0, 0, -half),
        ]
        immesh.surface_add_vertex(corners[0])
        immesh.surface_add_vertex(corners[1])
        immesh.surface_add_vertex(corners[2])
        immesh.surface_add_vertex(corners[0])
        immesh.surface_add_vertex(corners[2])
        immesh.surface_add_vertex(corners[3])
        return
    immesh.surface_add_vertex(pos + Vector3(-half, 0, -half))
    immesh.surface_add_vertex(pos + Vector3(half, 0, -half))
    immesh.surface_add_vertex(pos + Vector3(half, 0, half))
    immesh.surface_add_vertex(pos + Vector3(-half, 0, -half))
    immesh.surface_add_vertex(pos + Vector3(half, 0, half))
    immesh.surface_add_vertex(pos + Vector3(-half, 0, half))
