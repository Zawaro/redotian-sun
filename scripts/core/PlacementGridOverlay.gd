class_name PlacementGridOverlay
extends Node3D

## Renders build-mode placement highlight cells as one MultiMesh of flat,
## chamfered-octagon planes with per-instance color (#352):
## white = reachable placement region, green = valid cells under the ghost,
## red = blocked cells.

enum CellState { HIDDEN, FREE, BLOCKED }

const WHITE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.15)
const GREEN_COLOR: Color = Color(0.0, 1.0, 0.0, 0.2)
const RED_COLOR: Color = Color(1.0, 0.0, 0.0, 0.2)
const PLANE_Y_OFFSET: float = 0.025
const CELL_COVERAGE: float = 0.95
const CORNER_CHAMFER: float = 0.10
## White cells render only within this cursor-anchored radius — the same window
## the removed line grid used, so the full white set never renders at once.
const WHITE_WINDOW_MARGIN: float = 3.0

## func(cell: Vector2i) -> CellState — supplied by BuildingManager.
var cell_state_resolver: Callable = _default_cell_state

var _white_cells: Dictionary = {}
var _cursor_origin := Vector2i.ZERO
var _cursor_footprint := Vector2i.ZERO
var _outside_white_blocked := false
var _has_cursor := false
var _multimesh: MultiMesh = null


func set_white_cells(cells: Array[Vector2i]) -> void:
    _white_cells.clear()
    for cell in cells:
        _white_cells[cell] = true
    _rebuild()


func set_cursor(origin: Vector2i, footprint: Vector2i, outside_white_blocked: bool = false) -> void:
    _cursor_origin = origin
    _cursor_footprint = footprint
    _outside_white_blocked = outside_white_blocked
    _has_cursor = true
    _rebuild()


func clear() -> void:
    _white_cells.clear()
    _outside_white_blocked = false
    _has_cursor = false
    _rebuild()


## Pure per-cell color assignment — testable without rendering.
## Cursor footprint cells win over white cells. White cells render only inside
## the cursor-anchored window; with `outside_white_blocked`, free cursor cells
## outside the white region show red (adjacency-bound ghosts).
func compute_cell_colors() -> Dictionary:
    var cell_colors := {}
    var window := _white_window() if _has_cursor else _white_cells.keys()
    for cell in window:
        var state: int = cell_state_resolver.call(cell)
        if state == CellState.HIDDEN:
            continue
        cell_colors[cell] = RED_COLOR if state == CellState.BLOCKED else WHITE_COLOR
    if _has_cursor:
        for dx in _cursor_footprint.x:
            for dz in _cursor_footprint.y:
                var cell := _cursor_origin + Vector2i(dx, dz)
                var state: int = cell_state_resolver.call(cell)
                if state == CellState.HIDDEN:
                    continue
                if _outside_white_blocked and not _white_cells.has(cell):
                    cell_colors[cell] = RED_COLOR
                else:
                    cell_colors[cell] = RED_COLOR if state == CellState.BLOCKED else GREEN_COLOR
    return cell_colors


## Cells of the white set within the old line-grid radius around the ghost
## center: max(footprint) * 0.5 + margin.
func _white_window() -> Array:
    var radius: float = (
        maxf(float(_cursor_footprint.x), float(_cursor_footprint.y)) * 0.5 + WHITE_WINDOW_MARGIN
    )
    var center := Vector2(_cursor_origin) + Vector2(_cursor_footprint) * 0.5
    var window: Array = []
    for cell in _white_cells:
        var cell_center := Vector2(cell) + Vector2(0.5, 0.5)
        if cell_center.distance_to(center) <= radius:
            window.append(cell)
    return window


## Flat plane at the cell's highest terrain corner + PLANE_Y_OFFSET.
func _cell_plane_y(cell: Vector2i) -> float:
    return TerrainSystem.get_cell_max_height(cell) + PLANE_Y_OFFSET


func _ready() -> void:
    var instance := MultiMeshInstance3D.new()
    instance.name = "HighlightCells"
    _multimesh = MultiMesh.new()
    _multimesh.transform_format = MultiMesh.TRANSFORM_3D
    _multimesh.use_colors = true
    _multimesh.mesh = _build_cell_mesh()
    _multimesh.instance_count = 0
    instance.material_override = _build_material()
    instance.multimesh = _multimesh
    add_child(instance)


func _build_material() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.vertex_color_use_as_albedo = true
    return mat


## Shared chamfered-octagon plane: XZ = 90% of the cell size, corners cut by
## 15% of the cell size, flat at local y = 0. One mesh for every cell — the
## instance transform carries position/height, the instance color carries state.
func _build_cell_mesh() -> ArrayMesh:
    var half := CellUtil.CELL_SIZE * CELL_COVERAGE * 0.5
    var cut := CellUtil.CELL_SIZE * CORNER_CHAMFER
    var points: Array[Vector3] = [
        Vector3(-half + cut, 0.0, -half),
        Vector3(half - cut, 0.0, -half),
        Vector3(half, 0.0, -half + cut),
        Vector3(half, 0.0, half - cut),
        Vector3(half - cut, 0.0, half),
        Vector3(-half + cut, 0.0, half),
        Vector3(-half, 0.0, half - cut),
        Vector3(-half, 0.0, -half + cut),
    ]
    var vertices := PackedVector3Array()
    for i in 8:
        vertices.append(points[i])
        vertices.append(Vector3.ZERO)
        vertices.append(points[(i + 1) % 8])
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


func _rebuild() -> void:
    # No cursor yet -> nothing renders (avoids a full white-set flash between
    # entering build mode and the first cursor update).
    if _multimesh == null or not _has_cursor:
        return
    var cell_colors := compute_cell_colors()
    _multimesh.instance_count = cell_colors.size()
    var index := 0
    for cell in cell_colors:
        var world: Vector3 = CellUtil.cell_to_world(cell)
        var transform := Transform3D(Basis.IDENTITY, Vector3(world.x, _cell_plane_y(cell), world.z))
        _multimesh.set_instance_transform(index, transform)
        _multimesh.set_instance_color(index, cell_colors[cell])
        index += 1


func _default_cell_state(_cell: Vector2i) -> int:
    return CellState.FREE
