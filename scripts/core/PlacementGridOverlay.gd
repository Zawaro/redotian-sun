class_name PlacementGridOverlay
extends Node3D

## Renders build-mode placement highlight cells with per-cell color (#352):
## white = reachable placement region, green = valid cells under the ghost,
## red = blocked cells. Flat cells render as one MultiMesh of chamfered
## octagon planes; non-flat (slope) cells render terrain-matched patches —
## the shared octagon silhouette draped on the cell's two terrain-triangle
## planes, split along the `derive_crease` diagonal rule (#386).

enum CellState { HIDDEN, FREE, BLOCKED }

const WHITE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.15)
const GREEN_COLOR: Color = Color(0.0, 1.0, 0.0, 0.3)
const RED_COLOR: Color = Color(1.0, 0.0, 0.0, 0.3)
const PLANE_Y_OFFSET: float = 0.025
const CELL_COVERAGE: float = 0.95
const CORNER_CHAMFER: float = 0.10
## White cells render only within this cursor-anchored radius — the same window
## the removed line grid used, so the full white set never renders at once.
const WHITE_WINDOW_MARGIN: float = 3.0
## ponytail: fixed cap on terrain-matched patch slots; upgrade to a batched
## MultiMesh if the window ever holds more non-flat cells than this.
const PATCH_POOL_CAP: int = 256

## func(cell: Vector2i) -> CellState — supplied by BuildingManager.
var cell_state_resolver: Callable = _default_cell_state

var _white_cells: Dictionary = {}
var _cursor_origin := Vector2i.ZERO
var _cursor_footprint := Vector2i.ZERO
var _outside_white_blocked := false
var _has_cursor := false
var _multimesh: MultiMesh = null
var _material: StandardMaterial3D = null
var _patch_in_use: Dictionary = {}
var _patch_pool: Array[MeshInstance3D] = []


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
    _rebuild_patches({})


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


## Flat gate: "slope" cells render the terrain-matched patch, everything else
## (clear, empty data, or any future type) keeps the octagon.
func _is_flat_cell(cell: Vector2i) -> bool:
    return TerrainSystem.get_cell_type(cell) != "slope"


## Chooses the internal diagonal of the two-triangle patch for four corner
## heights in world order [NW, NE, SW, SE]. Returns 0 = {NW,SE} diagonal,
## 1 = {NE,SW} diagonal, -1 = coplanar (either — the internal edge is
## invisible for the unshaded material).
## Engine-side form of tools/isotem's derive_crease:
## - coplanar (h_nw + h_se == h_ne + h_sw) -> either
## - one unique corner (max or min) -> the diagonal NOT through it
## - two max corners on opposite corners (saddle) -> the diagonal joining them
static func pick_diagonal(corners: Array) -> int:
    if is_equal_approx(corners[0] + corners[3], corners[1] + corners[2]):
        return -1
    var hi: float = corners.max()
    var lo: float = corners.min()
    var hi_i: Array[int] = []
    var lo_i: Array[int] = []
    for i in 4:
        if is_equal_approx(corners[i], hi):
            hi_i.append(i)
        if is_equal_approx(corners[i], lo):
            lo_i.append(i)
    if hi_i.size() == 2:
        if hi_i[0] == 0 and hi_i[1] == 3:
            return 0
        if hi_i[0] == 1 and hi_i[1] == 2:
            return 1
        # Two adjacent highs, non-coplanar (no such pattern in current
        # content): ponytail: fixed {NW,SE}; if such patterns appear in maps,
        # score both diagonals against the bilinear surface and keep the
        # smaller-deviation one.
        return 0
    if hi_i.size() == 1:
        return 0 if (hi_i[0] == 1 or hi_i[0] == 2) else 1
    if lo_i.size() == 1:
        return 0 if (lo_i[0] == 1 or lo_i[0] == 2) else 1
    # One max, one min, two middles: no unique corner and no saddle.
    # ponytail: fixed {NW,SE}; same upgrade path as the adjacent-high case.
    return 0


## Catalog `.tres` corner order [NW, NE, SE, SW] -> world order [NW, NE, SW, SE].
static func catalog_corners_to_world(corners: Array) -> Array:
    return [corners[0], corners[1], corners[3], corners[2]]


## The chamfered-octagon outline in cell-local XZ (center origin), shared by
## the flat octagon mesh and the terrain-matched patches so both silhouettes
## match exactly (#386 smoke test: corner size and inset must line up).
static func _octagon_local_xz() -> PackedVector2Array:
    var half := CellUtil.CELL_SIZE * CELL_COVERAGE * 0.5
    var cut := CellUtil.CELL_SIZE * CORNER_CHAMFER
    return PackedVector2Array(
        [
            Vector2(-half + cut, -half),
            Vector2(half - cut, -half),
            Vector2(half, -half + cut),
            Vector2(half, half - cut),
            Vector2(half - cut, half),
            Vector2(-half + cut, half),
            Vector2(-half, half - cut),
            Vector2(-half, -half + cut),
        ]
    )


## The two octagon half-rings split along the cell's terrain crease, in local
## XZ (center origin). The split points are the crease diagonal's crossings of
## the two chamfer edges it joins, so the outer silhouette stays exactly the
## shared octagon while neither half straddles the crease.
## `crease`: 0 = {NW,SE} diagonal, 1 = {NE,SW}, -1 = planar (treated as 0).
static func _octagon_halves(crease: int) -> Array:
    var ring := _octagon_local_xz()
    var half := CellUtil.CELL_SIZE * CELL_COVERAGE * 0.5
    var cut := CellUtil.CELL_SIZE * CORNER_CHAMFER
    var m := half - cut * 0.5
    if crease == 1:
        var m_ne := Vector2(m, -m)
        var m_sw := Vector2(-m, m)
        return [
            PackedVector2Array([m_ne, ring[2], ring[3], ring[4], ring[5], m_sw]),
            PackedVector2Array([m_sw, ring[6], ring[7], ring[0], ring[1], m_ne]),
        ]
    var m_nw := Vector2(-m, -m)
    var m_se := Vector2(m, m)
    return [
        PackedVector2Array([m_nw, ring[0], ring[1], ring[2], ring[3], m_se]),
        PackedVector2Array([m_se, ring[4], ring[5], ring[6], ring[7], m_nw]),
    ]


## The terrain triangles each half-ring hangs on, as world corner indices
## [NW,NE,SW,SE] (0=NW, 1=NE, 2=SW, 3=SE). Same diagonal split the baked
## catalog tile uses, so the patch lands on the rendered surface rather than
## the bilinear heightfield.
static func _patch_half_plane_indices(crease: int) -> Array:
    if crease == 1:
        return [[1, 2, 3], [0, 1, 2]]
    return [[0, 1, 3], [0, 2, 3]]


## Height on the plane through three world corner points at the given world XZ
## (barycentric in XZ; the cell's triangles are never XZ-degenerate).
static func _plane_y_at(p0: Vector3, p1: Vector3, p2: Vector3, xz: Vector2) -> float:
    var denom := (p1.z - p2.z) * (p0.x - p2.x) + (p2.x - p1.x) * (p0.z - p2.z)
    var l0 := ((p1.z - p2.z) * (xz.x - p2.x) + (p2.x - p1.x) * (xz.y - p2.z)) / denom
    var l1 := ((p2.z - p0.z) * (xz.x - p2.x) + (p0.x - p2.x) * (xz.y - p2.z)) / denom
    return l0 * p0.y + l1 * p1.y + (1.0 - l0 - l1) * p2.y


## Terrain-matched highlight patch: the shared octagon outline draped on the
## cell's two terrain-triangle planes. The octagon is split along the
## `pick_diagonal` crease; each half's vertices are evaluated on its own
## triangle plane + PLANE_Y_OFFSET, so the patch folds exactly where (and how)
## the rendered tile folds — no bilinear-vs-plane sliver through the crease.
## `crease`: pick_diagonal result (0 = {NW,SE}, 1 = {NE,SW}, -1 = planar/any).
## The state color (including alpha) rides in the vertex color — a
## StandardMaterial3D albedo cannot carry an alpha channel without a texture,
## so this mirrors the octagon path's color pipeline.
static func _build_patch_mesh(
    cell_center: Vector3, corner_heights: Array, crease: int, color: Color
) -> ArrayMesh:
    var hc := CellUtil.CELL_SIZE * 0.5
    var corner_local := [
        Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)
    ]
    var corners: Array[Vector3] = []
    for i in 4:
        corners.append(
            Vector3(
                cell_center.x + corner_local[i].x * hc,
                float(corner_heights[i]),
                cell_center.z + corner_local[i].y * hc
            )
        )
    var halves := _octagon_halves(crease)
    var planes := _patch_half_plane_indices(crease)
    var vertices := PackedVector3Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    for h in 2:
        var base := vertices.size()
        var tri: Array = planes[h]
        for local in halves[h]:
            var xz := Vector2(cell_center.x + local.x, cell_center.z + local.y)
            var y: float = _plane_y_at(corners[tri[0]], corners[tri[1]], corners[tri[2]], xz)
            vertices.append(Vector3(xz.x, y + PLANE_Y_OFFSET, xz.y))
            colors.append(color)
        var count: int = halves[h].size()
        for k in range(1, count - 1):
            indices.append(base)
            indices.append(base + k)
            indices.append(base + k + 1)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


func _ready() -> void:
    var instance := MultiMeshInstance3D.new()
    instance.name = "HighlightCells"
    _multimesh = MultiMesh.new()
    _multimesh.transform_format = MultiMesh.TRANSFORM_3D
    _multimesh.use_colors = true
    _multimesh.mesh = _build_cell_mesh()
    _multimesh.instance_count = 0
    _material = _build_material()
    instance.material_override = _material
    instance.multimesh = _multimesh
    add_child(instance)


func _build_material() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.vertex_color_use_as_albedo = true
    return mat


## Shared chamfered-octagon plane: XZ from the shared outline, flat at local
## y = 0. One mesh for every cell — the instance transform carries
## position/height, the instance color carries state.
func _build_cell_mesh() -> ArrayMesh:
    var local := _octagon_local_xz()
    var vertices := PackedVector3Array()
    for i in 8:
        var a := Vector3(local[i].x, 0.0, local[i].y)
        var b := Vector3(local[(i + 1) % 8].x, 0.0, local[(i + 1) % 8].y)
        vertices.append(a)
        vertices.append(Vector3.ZERO)
        vertices.append(b)
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
    var flat_cells: Dictionary = {}
    var patch_cells: Dictionary = {}
    for cell in cell_colors:
        if _is_flat_cell(cell):
            flat_cells[cell] = cell_colors[cell]
        else:
            patch_cells[cell] = cell_colors[cell]
    _multimesh.instance_count = flat_cells.size()
    var index := 0
    for cell in flat_cells:
        var world: Vector3 = CellUtil.cell_to_world(cell)
        var transform := Transform3D(Basis.IDENTITY, Vector3(world.x, _cell_plane_y(cell), world.z))
        _multimesh.set_instance_transform(index, transform)
        _multimesh.set_instance_color(index, flat_cells[cell])
        index += 1
    _rebuild_patches(patch_cells)


## Applies the terrain-matched patch instances to `patch_cells` (cell ->
## color), reusing pooled MeshInstance3D slots. Rebuilds are driven by the
## rebuild path (set / color change), never per frame.
func _rebuild_patches(patch_cells: Dictionary) -> void:
    if _material == null:
        return
    var old_cells: Dictionary = {}
    old_cells.assign(_patch_in_use)
    _patch_in_use.clear()
    # Free every old slot, then re-acquire from the pool. Freeing only cells
    # that left the set leaked still-visible instances for surviving cells and
    # stacked a translucent quad per rebuild (#386 smoke-test finding).
    for cell in old_cells:
        _free_patch_instance(old_cells[cell])
    for cell in patch_cells:
        var inst: MeshInstance3D = _acquire_patch_instance()
        if inst == null:
            continue
        _configure_patch_instance(inst, cell, patch_cells[cell])
        _patch_in_use[cell] = inst


func _acquire_patch_instance() -> MeshInstance3D:
    if not _patch_pool.is_empty():
        var inst: MeshInstance3D = _patch_pool.pop_back()
        inst.visible = true
        return inst
    if _patch_in_use.size() + _patch_pool.size() >= PATCH_POOL_CAP:
        return null
    var inst := MeshInstance3D.new()
    inst.name = "Patch"
    inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    inst.material_override = _material
    add_child(inst)
    return inst


func _free_patch_instance(inst: MeshInstance3D) -> void:
    inst.visible = false
    _patch_pool.append(inst)


func _configure_patch_instance(inst: MeshInstance3D, cell: Vector2i, color: Color) -> void:
    var corners: Array = TerrainSystem.get_cell_corner_heights(cell)
    var crease: int = pick_diagonal(corners)
    if crease < 0:
        crease = 0
    inst.mesh = _build_patch_mesh(CellUtil.cell_to_world(cell), corners, crease, color)


func _default_cell_state(_cell: Vector2i) -> int:
    return CellState.FREE
