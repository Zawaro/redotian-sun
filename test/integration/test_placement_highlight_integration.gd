extends Node

# Build-mode terrain-matched highlight integration (#386): importing a real
# map fixture, entering build mode over a slope region must yield exactly one
# non-flat patch instance per non-flat cell in the cursor window / footprint
# (Y at corner heights + offset, state colors riding the vertex color),
# while flat cells keep the octagon MultiMesh path, and a flat region yields
# no patches at all.

const MAP_A := "res://games/ts/assets/test_terrain.json"
const MAP_B := "res://games/ts/assets/test_map01.json"

var _bm: Node


func _types_by_cell() -> Dictionary:
    var by_type := {"slope": [], "clear": []}
    for key in TerrainSystem.get_all_cells():
        var parts: PackedStringArray = key.split(",")
        var cell := Vector2i(int(parts[0]), int(parts[1]))
        var t: String = TerrainSystem.get_cell_type(cell)
        by_type.get(t, []).append(cell)
    return by_type


func _enter_build_mode(white: Array, origin: Vector2i, resolver: Callable) -> PlacementGridOverlay:
    var overlay := PlacementGridOverlay.new()
    _bm.add_child(overlay)
    overlay.cell_state_resolver = resolver
    overlay.set_white_cells(white)
    overlay.set_cursor(origin, Vector2i(1, 1))
    return overlay


func _free_overlay(overlay: PlacementGridOverlay) -> void:
    _bm.remove_child(overlay)
    overlay.free()


func _white_window_for(origin: Vector2i) -> Array:
    # Mirrors the overlay's cursor-anchored window: footprint 1x1, radius
    # max(1, 1) * 0.5 + margin (same formula as the removed line grid).
    var radius: float = 1.0 * 0.5 + PlacementGridOverlay.WHITE_WINDOW_MARGIN
    var center := Vector2(origin) + Vector2(0.5, 0.5)
    var window: Array = []
    for key in TerrainSystem.get_all_cells():
        var parts: PackedStringArray = key.split(",")
        var cell := Vector2i(int(parts[0]), int(parts[1]))
        if not BoundsSystem.is_in_map_bounds(cell):
            continue
        if (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(center) <= radius:
            window.append(cell)
    return window


func _nearest_slope_origin(tag: String) -> Vector2i:
    var slopes: Array = _types_by_cell().get("slope", [])
    var mid := Vector2(TerrainSystem.grid_cells) * 0.5
    var origin := Vector2i.ZERO
    var best_dist := 1e12
    for cell in slopes:
        var d: float = (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(mid)
        if d < best_dist:
            best_dist = d
            origin = cell
    TestHelper.assert_true(
        BoundsSystem.is_in_map_bounds(origin),
        "%s: cursor cell is inside the playable diamond" % tag
    )
    TestHelper.assert_eq(
        TerrainSystem.get_cell_type(origin), "slope", "%s: cursor lands on a slope cell" % tag
    )
    return origin


## Typed return is required: set_white_cells takes Array[Vector2i], and an
## untyped array aborts the call at the runtime type check.
func _all_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for key in TerrainSystem.get_all_cells():
        var parts: PackedStringArray = key.split(",")
        cells.append(Vector2i(int(parts[0]), int(parts[1])))
    return cells


func _assert_patch_geometry(overlay: PlacementGridOverlay, cells: Array) -> void:
    for cell in cells:
        var inst: MeshInstance3D = overlay._patch_in_use.get(cell)
        if inst == null:
            continue
        TestHelper.assert_true(inst.is_inside_tree(), "patch instance is in the tree")
        var mesh: ArrayMesh = inst.mesh
        TestHelper.assert_true(mesh != null, "patch mesh assigned for %s" % cell)
        var arrays := mesh.surface_get_arrays(0)
        var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        TestHelper.assert_eq(positions.size(), 12, "two 6-vertex halves for %s" % cell)

        # Independent oracle: the patch must lie on the cell's two rendered
        # terrain triangles (corner heights split on the derived crease), not
        # on the bilinear heightfield sampler — that mismatch was the
        # through-the-fold bleed (#386). Plane height via the triangle normal.
        var center := CellUtil.cell_to_world(cell)
        var heights: Array = TerrainSystem.get_cell_corner_heights(cell)
        var crease: int = PlacementGridOverlay.pick_diagonal(heights)
        if crease < 0:
            crease = 0
        var hc := CellUtil.CELL_SIZE * 0.5
        var corner_local := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
        var corners: Array[Vector3] = []
        for i in 4:
            corners.append(
                Vector3(
                    center.x + corner_local[i].x * hc,
                    float(heights[i]),
                    center.z + corner_local[i].y * hc
                )
            )
        var planes: Array = [[1, 2, 3], [0, 1, 2]] if crease == 1 else [[0, 1, 3], [0, 2, 3]]
        var ring := PlacementGridOverlay._octagon_local_xz()
        var ring_hits := 0
        for v in positions:
            var local := Vector2(v.x - center.x, v.z - center.z)
            var side := (local.x + local.y) if crease == 1 else (local.x - local.y)
            var tri: Array = planes[0] if side > 1e-6 else planes[1]
            var oracle: float = (
                _triangle_plane_y(
                    corners[tri[0]], corners[tri[1]], corners[tri[2]], Vector2(v.x, v.z)
                )
                + PlacementGridOverlay.PLANE_Y_OFFSET
            )
            TestHelper.assert_true(
                absf(v.y - oracle) < 1e-4,
                (
                    "vertex y on the rendered tile plane for %s (got %.4f want %.4f)"
                    % [cell, v.y, oracle]
                )
            )
            for r in ring:
                if absf(local.x - r.x) < 1e-4 and absf(local.y - r.y) < 1e-4:
                    ring_hits += 1
                    break
        TestHelper.assert_eq(ring_hits, 8, "all 8 octagon ring vertices present on %s" % cell)

        # The cliff constraint on real terrain: no near-vertical face.
        var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
        for t in indices.size() / 3:
            var a: Vector3 = positions[indices[t * 3]]
            var b: Vector3 = positions[indices[t * 3 + 1]]
            var c: Vector3 = positions[indices[t * 3 + 2]]
            var n: Vector3 = (b - a).cross(c - a).normalized()
            TestHelper.assert_true(absf(n.y) >= 0.5, "no near-vertical face on %s" % cell)


## Height at world XZ `p` on the plane through three corner points, via the
## plane normal — an independent formulation from the production barycentric
## path.
static func _triangle_plane_y(a: Vector3, b: Vector3, c: Vector3, p: Vector2) -> float:
    var n: Vector3 = (b - a).cross(c - a)
    return a.y - (n.x * (p.x - a.x) + n.z * (p.y - a.z)) / n.y


func _vertex_color_of(overlay: PlacementGridOverlay, cell: Vector2i) -> Color:
    var inst: MeshInstance3D = overlay._patch_in_use.get(cell)
    if inst == null or inst.mesh == null:
        return Color(-1, -1, -1, -1)
    var arrays := inst.mesh.surface_get_arrays(0)
    var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
    return colors[0]


func _run_map_case(path: String, slope_pin: int, flat_pin: int, tag: String) -> void:
    TerrainSystem.import_from_json(path)
    var all: Dictionary = TerrainSystem.get_all_cells()
    TestHelper.assert_true(all.size() > 0, "%s: map imported cells" % tag)
    TestHelper.assert_eq(all.size(), flat_pin + slope_pin, "%s: fixture cell count is stable" % tag)

    var by_type := _types_by_cell()
    var slopes: Array = by_type.get("slope", [])
    TestHelper.assert_eq(slopes.size(), slope_pin, "%s: slope cell count" % tag)
    if slopes.is_empty():
        return

    # Center the cursor on the slope cell nearest the grid center.
    var origin: Vector2i = _nearest_slope_origin(tag)

    var free_resolver := func(_cell: Vector2i) -> int: return PlacementGridOverlay.CellState.FREE
    var overlay := _enter_build_mode(_all_cells(), origin, free_resolver)

    var window := _white_window_for(origin)
    TestHelper.assert_true(window.size() > 0, "%s: window non-empty" % tag)
    var patches_expected: Dictionary = {}
    var octagons_expected := 0
    for cell in window:
        if TerrainSystem.get_cell_type(cell) == "slope":
            patches_expected[cell] = true
        else:
            octagons_expected += 1
    TestHelper.assert_true(
        patches_expected.size() > 0, "%s: window contains slope cells (non-vacuous)" % tag
    )

    TestHelper.assert_eq(
        overlay._patch_in_use.size(),
        patches_expected.size(),
        "%s: one patch per non-flat window cell" % tag
    )
    for cell in patches_expected:
        TestHelper.assert_true(
            overlay._patch_in_use.has(cell), "%s: slope cell %s rendered as a patch" % [tag, cell]
        )
    TestHelper.assert_eq(
        overlay._multimesh.instance_count,
        octagons_expected,
        "%s: octagon count unchanged for flat cells" % tag
    )

    _assert_patch_geometry(overlay, patches_expected.keys())
    # to_html(false) ignores alpha, and RGB values 0/1 are exact in float32.
    (
        TestHelper
        . assert_eq(
            _vertex_color_of(overlay, origin).to_html(false),
            PlacementGridOverlay.GREEN_COLOR.to_html(false),
            "%s: cursor footprint cell is green" % tag,
        )
    )
    for cell in patches_expected:
        if cell != origin:
            (
                TestHelper
                . assert_eq(
                    _vertex_color_of(overlay, cell).to_html(false),
                    PlacementGridOverlay.WHITE_COLOR.to_html(false),
                    "%s: window cell is white" % tag,
                )
            )
    _free_overlay(overlay)


func _test_a() -> void:
    # Pins measured from the fixture (46x46 grid -> 4232 diamond cells, 26
    # slope). The issue's "91 slope cells" predates the current fixture.
    _run_map_case(MAP_A, 26, 4206, "test_terrain")


func _test_b() -> void:
    _run_map_case(MAP_B, 461, 4539, "test_map01")


func test_slope_region_yields_patches_for_all_states() -> void:
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    _test_a()
    _test_b()


func test_flat_region_yields_no_patches() -> void:
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    TerrainSystem.import_from_json(MAP_A)
    var radius: float = 1.0 * 0.5 + PlacementGridOverlay.WHITE_WINDOW_MARGIN
    var grid_center: Vector2 = Vector2(TerrainSystem.grid_cells) * 0.5
    var cells: Array = _all_cells()
    # Nearest-first scan for a flat cell whose full highlight window holds no
    # slope, so the zero-patch assertion is non-vacuous.
    var flat_origin := Vector2i.ZERO
    var found := false
    var by_dist: Array = cells.duplicate()
    by_dist.sort_custom(
        func(a: Vector2i, b: Vector2i) -> bool:
            return (
                (Vector2(a) + Vector2(0.5, 0.5)).distance_to(grid_center)
                < (Vector2(b) + Vector2(0.5, 0.5)).distance_to(grid_center)
            )
    )
    for cell in by_dist:
        if TerrainSystem.get_cell_type(cell) != "clear":
            continue
        var cell_center: Vector2 = Vector2(cell) + Vector2(0.5, 0.5)
        var slopes_in_window := 0
        for other in cells:
            var other_center: Vector2 = Vector2(other) + Vector2(0.5, 0.5)
            if (
                other_center.distance_to(cell_center) <= radius
                and TerrainSystem.get_cell_type(other) == "slope"
            ):
                slopes_in_window += 1
        flat_origin = cell
        if slopes_in_window == 0:
            found = true
            break
    TestHelper.assert_true(found, "found a flat cell with a slope-free highlight window")
    var free_resolver := func(_cell: Vector2i) -> int: return PlacementGridOverlay.CellState.FREE
    var overlay := _enter_build_mode(cells, flat_origin, free_resolver)
    TestHelper.assert_eq(overlay._patch_in_use.size(), 0, "no patches in a flat region")
    TestHelper.assert_true(overlay._multimesh.instance_count > 0, "flat octagons still render")
    _free_overlay(overlay)


func test_blocked_slope_cell_renders_red_patch() -> void:
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    TerrainSystem.import_from_json(MAP_A)
    var origin: Vector2i = _nearest_slope_origin("test_terrain")
    var blocked_resolver := func(_cell: Vector2i) -> int:
        return PlacementGridOverlay.CellState.BLOCKED
    var overlay := _enter_build_mode(_all_cells(), origin, blocked_resolver)
    TestHelper.assert_true(
        overlay._patch_in_use.has(origin), "blocked slope cell under the ghost renders a patch"
    )
    (
        TestHelper
        . assert_eq(
            _vertex_color_of(overlay, origin).to_html(false),
            PlacementGridOverlay.RED_COLOR.to_html(false),
            "blocked slope cell under the ghost renders the red patch",
        )
    )
    var window_red := 0
    for cell in overlay._patch_in_use:
        if cell == origin:
            continue
        (
            TestHelper
            . assert_eq(
                _vertex_color_of(overlay, cell).to_html(false),
                PlacementGridOverlay.RED_COLOR.to_html(false),
                "window cell %s renders the red patch" % cell,
            )
        )
        window_red += 1
    TestHelper.assert_true(
        window_red > 0, "non-vacuous: the window holds patch cells beyond the cursor footprint"
    )
    _free_overlay(overlay)


func test_repeated_rebuilds_do_not_stack_patch_instances() -> void:
    # Regression (#386 smoke test): a patch cell surviving a rebuild must reuse
    # its slot, not stack a new visible instance on the old one — leaked quads
    # composite per rebuild and tinted slope cells stronger than flat octagons.
    if _bm == null:
        TestHelper.fail("BuildingManager not injected")
        return
    TerrainSystem.import_from_json(MAP_A)
    var origin: Vector2i = _nearest_slope_origin("test_terrain")
    var free_resolver := func(_cell: Vector2i) -> int: return PlacementGridOverlay.CellState.FREE
    var overlay := _enter_build_mode(_all_cells(), origin, free_resolver)
    TestHelper.assert_true(overlay._patch_in_use.has(origin), "slope cell renders a patch")
    (
        TestHelper
        . assert_eq(
            _visible_patch_count(overlay),
            overlay._patch_in_use.size(),
            "rebuild 1: one visible instance per patch cell",
        )
    )

    # Same overlay, same cell set, state color flips white -> red: the leaked
    # implementation left the old white quad visible under the new red one.
    var blocked_resolver := func(_cell: Vector2i) -> int:
        return PlacementGridOverlay.CellState.BLOCKED
    overlay.cell_state_resolver = blocked_resolver
    overlay.set_cursor(origin, Vector2i(1, 1))
    (
        TestHelper
        . assert_eq(
            _vertex_color_of(overlay, origin).to_html(false),
            PlacementGridOverlay.RED_COLOR.to_html(false),
            "rebuild 2: surviving cell re-colors to red",
        )
    )
    (
        TestHelper
        . assert_eq(
            _visible_patch_count(overlay),
            overlay._patch_in_use.size(),
            "rebuild 2: one visible instance per patch cell (no stacking)",
        )
    )
    _free_overlay(overlay)


func _visible_patch_count(overlay: PlacementGridOverlay) -> int:
    var count := 0
    for child in overlay.get_children():
        if child is MeshInstance3D and child.visible:
            count += 1
    return count
