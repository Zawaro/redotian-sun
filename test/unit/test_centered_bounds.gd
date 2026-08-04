extends Node

# Bounds tests exercise geometric properties, generated meshes, and terrain prefill.

const EDITOR_SCRIPT: GDScript = preload("res://scripts/editor/MapEditor.gd")

var _ts: Node = null


func test_diamond_vertices_enforce_mirrored_quadrants_and_right_angles() -> void:
    var bounds: Node = _get_bounds_system()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    var map_sizes: Array[Vector2i] = [
        Vector2i(24, 20),
        Vector2i(20, 24),
        Vector2i(50, 50),
        Vector2i(51, 50),
        Vector2i(50, 51),
        Vector2i(51, 51),
        Vector2i(21, 33),
    ]
    # Diamond is centered on the cell diamond, which uses half-open [-N, N)
    # centered at -0.5 in each axis. Offset in world x = -CS/2.
    var offset := Vector3(-CellUtil.CELL_SIZE * 0.5, 0.0, 0.0)
    for grid_cells: Vector2i in map_sizes:
        var vertices: Array[Vector3] = bounds._compute_diamond_vertices(grid_cells)
        var north: Vector3 = vertices[0]
        var east: Vector3 = vertices[1]
        var south: Vector3 = vertices[2]
        var west: Vector3 = vertices[3]
        # Mirror around offset, not origin: south == -north + 2*offset
        _assert_vec3_approx(south, -north + offset * 2.0, "%s north/south mirror" % grid_cells)
        _assert_vec3_approx(west, -east + offset * 2.0, "%s east/west mirror" % grid_cells)

        var north_east := Vector2(east.x - north.x, east.z - north.z)
        var east_south := Vector2(south.x - east.x, south.z - east.z)
        _assert_true(
            is_equal_approx(absf(north_east.x), absf(north_east.y)),
            "%s north-east edge is 45 degrees" % grid_cells
        )
        _assert_true(
            is_equal_approx(absf(east_south.x), absf(east_south.y)),
            "%s east-south edge is 45 degrees" % grid_cells
        )
        _assert_true(
            is_zero_approx(north_east.dot(east_south)),
            "%s adjacent edges form a 90 degree corner" % grid_cells
        )
        _assert_true(
            is_equal_approx(
                north_east.length(), float(grid_cells.y) * CellUtil.CELL_SIZE * CellUtil.SQRT2
            ),
            "%s first edge length represents H" % grid_cells
        )
        _assert_true(
            is_equal_approx(
                east_south.length(), float(grid_cells.x) * CellUtil.CELL_SIZE * CellUtil.SQRT2
            ),
            "%s second edge length represents W" % grid_cells
        )


func test_clamp_is_centered_and_mirrors_all_quadrants() -> void:
    var bounds: Node = _get_bounds_system()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    var map_sizes: Array[Vector2i] = [
        Vector2i(24, 20), Vector2i(20, 24), Vector2i(51, 50), Vector2i(51, 51)
    ]
    var outside_points: Array[Vector3] = [
        Vector3(500.0, 7.0, 500.0),
        Vector3(500.0, 7.0, -500.0),
        Vector3(320.0, 7.0, 90.0),
    ]
    for grid_cells: Vector2i in map_sizes:
        bounds.grid_cells = grid_cells
        _assert_vec3_approx(
            bounds.clamp_to_map_diamond(Vector3.ZERO),
            Vector3.ZERO,
            "%s world origin remains fixed" % grid_cells
        )
        for point: Vector3 in outside_points:
            var clamped: Vector3 = bounds.clamp_to_map_diamond(point)
            var mirrored: Vector3 = bounds.clamp_to_map_diamond(-point)
            _assert_vec3_approx(
                mirrored, -clamped, "%s clamp mirrors opposite quadrants" % grid_cells
            )
            var sum_axis: float = (clamped.x + clamped.z) / CellUtil.CELL_SIZE
            var difference_axis: float = (clamped.x - clamped.z) / CellUtil.CELL_SIZE
            _assert_true(
                absf(sum_axis) <= float(grid_cells.y) + 0.001,
                "%s clamped point satisfies H axis" % grid_cells
            )
            _assert_true(
                absf(difference_axis) <= float(grid_cells.x) + 0.001,
                "%s clamped point satisfies W axis" % grid_cells
            )


func test_map_and_zero_inset_play_masks_are_identical() -> void:
    var bounds: Node = _get_bounds_system()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    var map_sizes: Array[Vector2i] = [
        Vector2i(20, 20), Vector2i(21, 20), Vector2i(20, 21), Vector2i(21, 21)
    ]
    for grid_cells: Vector2i in map_sizes:
        bounds.grid_cells = grid_cells
        bounds.visible_offset_x = 0
        bounds.visible_offset_z = 0
        var extent: int = grid_cells.x + grid_cells.y
        var masks_match: bool = true
        for x: int in extent:
            for z: int in extent:
                var cell := Vector2i(x, z)
                if bounds.is_in_map_bounds(cell) != bounds.is_in_play_area(cell):
                    masks_match = false
                    break
            if not masks_match:
                break
        _assert_true(masks_match, "%s map and zero-inset play masks match" % grid_cells)


func test_visible_size_controls_play_mask_outline_and_clamp() -> void:
    var bounds: Node = _get_bounds_system()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    bounds.grid_cells = Vector2i(24, 20)
    bounds.set_visible_bounds_size(Vector2i(14, 12))
    _assert_eq(bounds.visible_offset_x, 5, "visible width converts to five-cell X inset")
    _assert_eq(bounds.visible_offset_z, 4, "visible height converts to four-cell Z inset")
    _assert_eq(
        bounds._get_visible_draw_cells(),
        Vector2(19.0, 16.0),
        "blue outline includes the outer cell boundary"
    )

    var extent: int = bounds.grid_cells.x + bounds.grid_cells.y
    var play_count: int = 0
    for x: int in extent:
        for z: int in extent:
            if bounds.is_in_play_area(Vector2i(x, z)):
                play_count += 1
    _assert_eq(
        play_count,
        2 * (bounds.grid_cells.x - 5) * (bounds.grid_cells.y - 4),
        "play mask uses the same configured insets"
    )

    var point := Vector3(1000.0, 0.0, 1000.0)
    var clamped: Vector3 = bounds.clamp_to_visible_diamond(point)
    var sum_axis: float = (clamped.x + clamped.z) / CellUtil.CELL_SIZE
    _assert_true(absf(sum_axis) <= 16.0 + 0.001, "visible clamp uses the blue outline H axis")


func test_editor_grid_generates_symmetric_centered_geometry() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    _ts.clear()
    _ts.init_grid(21, 33)
    var editor := Node3D.new()
    var grid_script: GDScript = load("res://scripts/editor/EditorGrid.gd")
    var grid: Node = grid_script.new()
    grid.editor = editor
    grid.setup()

    var mesh: ImmediateMesh = grid._grid_overlay.mesh
    var arrays: Array = mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var w: float = 21.0
    var h: float = 33.0
    var cs: float = CellUtil.CELL_SIZE
    var all_inside: bool = true
    for vertex: Vector3 in vertices:
        var sum_axis: float = vertex.x + vertex.z
        var difference_axis: float = vertex.x - vertex.z
        if (
            sum_axis < -(h + 0.5) * cs - 0.001
            or sum_axis > (h - 0.5) * cs + 0.001
            or difference_axis < -(w + 0.5) * cs - 0.001
            or difference_axis > (w - 0.5) * cs + 0.001
        ):
            all_inside = false

    _assert_true(not vertices.is_empty(), "editor grid emits real mesh vertices")
    _assert_true(all_inside, "editor grid vertices stay inside diamond bounds")
    grid.free()
    editor.free()
    _ts.clear()
    _ts.init_grid(50, 50)


func test_map_editor_prefill_creates_every_real_terrain_cell_once() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    _ts.clear()
    _ts.init_grid(21, 33)
    var map_editor: Node3D = EDITOR_SCRIPT.new()
    map_editor._prefill_terrain()
    _assert_eq(
        _ts.get_all_cells().size(),
        2 * 21 * 33,
        "21x33 map prefill creates the independent 2*W*H terrain count"
    )
    map_editor.free()
    _ts.clear()
    _ts.init_grid(50, 50)


func test_prefill_every_diamond_cell_exists() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var map_sizes: Array[Vector2i] = [
        Vector2i(50, 50),
        Vector2i(51, 50),
        Vector2i(21, 33),
        Vector2i(20, 20),
        Vector2i(21, 20),
        Vector2i(5, 5)
    ]
    for grid_cells: Vector2i in map_sizes:
        _ts.clear()
        _ts.init_grid(grid_cells.x, grid_cells.y)
        var editor: Node3D = EDITOR_SCRIPT.new()
        editor._prefill_terrain()
        var extent: Vector2i = CellUtil.get_diamond_extent(grid_cells)
        var missing_count: int = 0
        var first_missing: Vector2i = Vector2i(-1, -1)
        for x: int in extent.x:
            for z: int in extent.y:
                var cell := Vector2i(x, z)
                if not CellUtil.is_in_diamond(cell, grid_cells):
                    continue
                if _ts.get_cell(cell).is_empty():
                    missing_count += 1
                    if first_missing.x < 0:
                        first_missing = cell
        editor.free()
        (
            TestHelper
            . assert_true(
                missing_count == 0,
                (
                    "%s prefill has every diamond cell" % grid_cells
                    + ": "
                    + "%s missing %d cells, first=%s" % [grid_cells, missing_count, first_missing]
                ),
            )
        )
        _ts.clear()
    _ts.init_grid(50, 50)


func test_prefill_no_cells_outside_diamond() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var map_sizes: Array[Vector2i] = [
        Vector2i(50, 50),
        Vector2i(51, 50),
        Vector2i(21, 33),
        Vector2i(20, 20),
        Vector2i(21, 20),
        Vector2i(5, 5)
    ]
    for grid_cells: Vector2i in map_sizes:
        _ts.clear()
        _ts.init_grid(grid_cells.x, grid_cells.y)
        var editor: Node3D = EDITOR_SCRIPT.new()
        editor._prefill_terrain()
        var cells: Dictionary = _ts.get_all_cells()
        var ghost_count: int = 0
        var first_ghost: String = ""
        for key: String in cells:
            var parts := key.split(",")
            if parts.size() != 2:
                continue
            var cell := Vector2i(int(parts[0]), int(parts[1]))
            if not CellUtil.is_in_diamond(cell, grid_cells):
                ghost_count += 1
                if first_ghost.is_empty():
                    first_ghost = key
        editor.free()
        (
            TestHelper
            . assert_true(
                ghost_count == 0,
                (
                    "%s prefill has no cells outside diamond" % grid_cells
                    + ": "
                    + "%s has %d ghost cells, first=%s" % [grid_cells, ghost_count, first_ghost]
                ),
            )
        )
        _ts.clear()
    _ts.init_grid(50, 50)


func test_prefill_cell_world_roundtrip() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var map_sizes: Array[Vector2i] = [
        Vector2i(50, 50), Vector2i(51, 50), Vector2i(21, 33), Vector2i(21, 20), Vector2i(5, 5)
    ]
    for grid_cells: Vector2i in map_sizes:
        _ts.clear()
        _ts.init_grid(grid_cells.x, grid_cells.y)
        var editor: Node3D = EDITOR_SCRIPT.new()
        editor._prefill_terrain()
        var extent: Vector2i = CellUtil.get_diamond_extent(grid_cells)
        var all_roundtrip: bool = true
        var bad_cell: Vector2i = Vector2i.ZERO
        var bad_back: Vector2i = Vector2i.ZERO
        for x: int in extent.x:
            for z: int in extent.y:
                var cell := Vector2i(x, z)
                if not CellUtil.is_in_diamond(cell, grid_cells):
                    continue
                if _ts.get_cell(cell).is_empty():
                    continue
                var world: Vector3 = CellUtil.cell_to_world(cell, grid_cells)
                var back: Vector2i = CellUtil.world_to_cell(world, grid_cells)
                if back != cell:
                    all_roundtrip = false
                    bad_cell = cell
                    bad_back = back
                    break
            if not all_roundtrip:
                break
        editor.free()
        (
            TestHelper
            . assert_true(
                all_roundtrip,
                (
                    "%s every cell roundtrips through world space" % grid_cells
                    + ": "
                    + "%s cell %s -> world -> cell %s" % [grid_cells, bad_cell, bad_back]
                ),
            )
        )
        _ts.clear()
    _ts.init_grid(50, 50)


func test_prefill_no_duplicate_world_positions() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var map_sizes: Array[Vector2i] = [
        Vector2i(50, 50), Vector2i(51, 50), Vector2i(21, 33), Vector2i(21, 20), Vector2i(5, 5)
    ]
    for grid_cells: Vector2i in map_sizes:
        _ts.clear()
        _ts.init_grid(grid_cells.x, grid_cells.y)
        var editor: Node3D = EDITOR_SCRIPT.new()
        editor._prefill_terrain()
        var seen: Dictionary = {}
        var duplicate_found: bool = false
        var dup_key: String = ""
        var cells: Dictionary = _ts.get_all_cells()
        for key: String in cells:
            var parts := key.split(",")
            if parts.size() != 2:
                continue
            var cell := Vector2i(int(parts[0]), int(parts[1]))
            var world: Vector3 = CellUtil.cell_to_world(cell, grid_cells)
            var pos_key := "%d,%d" % [int(world.x), int(world.z)]
            if seen.has(pos_key):
                duplicate_found = true
                dup_key = "%s and %s both at %s" % [seen[pos_key], cell, pos_key]
                break
            seen[pos_key] = cell
        editor.free()
        (
            TestHelper
            . assert_true(
                not duplicate_found,
                (
                    "%s no duplicate world positions" % grid_cells
                    + ": "
                    + "%s %s" % [grid_cells, dup_key]
                ),
            )
        )
        _ts.clear()
    _ts.init_grid(50, 50)


func test_prefill_adjacent_cells_differ_by_cell_size() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var map_sizes: Array[Vector2i] = [
        Vector2i(50, 50), Vector2i(51, 50), Vector2i(21, 33), Vector2i(21, 20), Vector2i(5, 5)
    ]
    for grid_cells: Vector2i in map_sizes:
        _ts.clear()
        _ts.init_grid(grid_cells.x, grid_cells.y)
        var editor: Node3D = EDITOR_SCRIPT.new()
        editor._prefill_terrain()
        var extent: Vector2i = CellUtil.get_diamond_extent(grid_cells)
        var all_even: bool = true
        var bad_msg: String = ""
        for x: int in extent.x:
            for z: int in extent.y:
                var cell := Vector2i(x, z)
                if not CellUtil.is_in_diamond(cell, grid_cells):
                    continue
                if _ts.get_cell(cell).is_empty():
                    continue
                var pos_a: Vector3 = CellUtil.cell_to_world(cell, grid_cells)
                # Check right neighbor
                var right := Vector2i(cell.x + 1, cell.y)
                if CellUtil.is_in_diamond(right, grid_cells) and not _ts.get_cell(right).is_empty():
                    var pos_b: Vector3 = CellUtil.cell_to_world(right, grid_cells)
                    var dx := absf(pos_a.x - pos_b.x)
                    if not is_equal_approx(dx, CellUtil.CELL_SIZE):
                        all_even = false
                        bad_msg = (
                            "%s: %s<->%s dx=%.4f != %.4f"
                            % [grid_cells, cell, right, dx, CellUtil.CELL_SIZE]
                        )
                        break
                # Check down neighbor
                var down := Vector2i(cell.x, cell.y + 1)
                if CellUtil.is_in_diamond(down, grid_cells) and not _ts.get_cell(down).is_empty():
                    var pos_b: Vector3 = CellUtil.cell_to_world(down, grid_cells)
                    var dz := absf(pos_a.z - pos_b.z)
                    if not is_equal_approx(dz, CellUtil.CELL_SIZE):
                        all_even = false
                        bad_msg = (
                            "%s: %s<->%s dz=%.4f != %.4f"
                            % [grid_cells, cell, down, dz, CellUtil.CELL_SIZE]
                        )
                        break
            if not all_even:
                break
        editor.free()
        (
            TestHelper
            . assert_true(
                all_even,
                "%s adjacent cells are CELL_SIZE apart" % grid_cells + ": " + "%s" % bad_msg,
            )
        )
        _ts.clear()
    _ts.init_grid(50, 50)


func test_prefill_cell_count_exactly_matches_formula() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var cases: Array[Array] = [
        [Vector2i(50, 50), 2 * 50 * 50],
        [Vector2i(51, 50), 2 * 51 * 50],
        [Vector2i(21, 33), 2 * 21 * 33],
        [Vector2i(21, 20), 2 * 21 * 20],
        [Vector2i(5, 5), 2 * 5 * 5],
    ]
    var editor_script: GDScript = EDITOR_SCRIPT
    for pair: Array in cases:
        var grid_cells: Vector2i = pair[0] as Vector2i
        var expected: int = pair[1] as int
        _ts.clear()
        _ts.init_grid(grid_cells.x, grid_cells.y)
        var editor: Node3D = editor_script.new()
        editor._prefill_terrain()
        var actual: int = _ts.get_all_cells().size()
        editor.free()
        (
            TestHelper
            . assert_true(
                actual == expected,
                (
                    "%s cell count = %d (2*W*H)" % [grid_cells, expected]
                    + ": "
                    + "%s cell count = %d, expected %d" % [grid_cells, actual, expected]
                ),
            )
        )
        _ts.clear()
    _ts.init_grid(50, 50)


func test_prefill_cell_spacing_minimum_is_cell_size() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var map_sizes: Array[Vector2i] = [
        Vector2i(50, 50), Vector2i(51, 50), Vector2i(21, 33), Vector2i(21, 20), Vector2i(5, 5)
    ]
    for grid_cells: Vector2i in map_sizes:
        _ts.clear()
        _ts.init_grid(grid_cells.x, grid_cells.y)
        var editor: Node3D = EDITOR_SCRIPT.new()
        editor._prefill_terrain()
        var positions: Array[Vector3] = []
        var cells: Dictionary = _ts.get_all_cells()
        for key: String in cells:
            var parts := key.split(",")
            if parts.size() != 2:
                continue
            var cell := Vector2i(int(parts[0]), int(parts[1]))
            positions.append(CellUtil.cell_to_world(cell, grid_cells))
        var min_gap: float = 999999.0
        var bad_a: Vector3 = Vector3.ZERO
        var bad_b: Vector3 = Vector3.ZERO
        for i: int in range(positions.size()):
            for j: int in range(i + 1, positions.size()):
                var gap_x: float = absf(positions[i].x - positions[j].x)
                var gap_z: float = absf(positions[i].z - positions[j].z)
                var chebyshev: float = maxf(gap_x, gap_z)
                if chebyshev < min_gap:
                    min_gap = chebyshev
                    bad_a = positions[i]
                    bad_b = positions[j]
        editor.free()
        (
            TestHelper
            . assert_true(
                is_equal_approx(min_gap, CellUtil.CELL_SIZE),
                (
                    "%s minimum cell spacing = CELL_SIZE (%.1f)" % [grid_cells, min_gap]
                    + ": "
                    + (
                        "%s minimum spacing = %.4f (expected %.1f), cells at %s and %s"
                        % [grid_cells, min_gap, CellUtil.CELL_SIZE, bad_a, bad_b]
                    )
                ),
            )
        )
        _ts.clear()
    _ts.init_grid(50, 50)


func test_prefill_no_half_cell_offset_positions() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var map_sizes: Array[Vector2i] = [
        Vector2i(50, 50), Vector2i(51, 50), Vector2i(21, 33), Vector2i(21, 20), Vector2i(5, 5)
    ]
    for grid_cells: Vector2i in map_sizes:
        _ts.clear()
        _ts.init_grid(grid_cells.x, grid_cells.y)
        var editor: Node3D = EDITOR_SCRIPT.new()
        editor._prefill_terrain()
        var half_cell_count: int = 0
        var first_bad_key: String = ""
        var first_bad_pos: Vector3 = Vector3.ZERO
        var cells: Dictionary = _ts.get_all_cells()
        for key: String in cells:
            var parts := key.split(",")
            if parts.size() != 2:
                continue
            var cell := Vector2i(int(parts[0]), int(parts[1]))
            var world_pos: Vector3 = CellUtil.cell_to_world(cell, grid_cells)
            # cell_to_world = (cell + 0.5 - center) * CELL_SIZE
            # center is integer or half-integer, so all positions are integers.
            # If a position is NOT an integer, the cell is at a half-cell offset.
            var round_x: float = roundf(world_pos.x)
            var round_z: float = roundf(world_pos.z)
            if (
                not is_equal_approx(world_pos.x, round_x)
                or not is_equal_approx(world_pos.z, round_z)
            ):
                half_cell_count += 1
                if first_bad_key.is_empty():
                    first_bad_key = key
                    first_bad_pos = world_pos
        editor.free()
        (
            TestHelper
            . assert_true(
                half_cell_count == 0,
                (
                    "%s no half-cell offset positions" % grid_cells
                    + ": "
                    + (
                        "%s has %d half-cell positions, first=%s at %s"
                        % [grid_cells, half_cell_count, first_bad_key, first_bad_pos]
                    )
                ),
            )
        )
        _ts.clear()
    _ts.init_grid(50, 50)


func test_prefill_21x20_boundary_cells() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    _ts.clear()
    _ts.init_grid(21, 20)
    var grid_cells := Vector2i(21, 20)
    var editor: Node3D = EDITOR_SCRIPT.new()
    editor._prefill_terrain()
    # Verify that every cell in _cells satisfies is_in_diamond
    # and every cell satisfying is_in_diamond exists in _cells.
    # This is the definitive boundary check.
    var extent: Vector2i = CellUtil.get_diamond_extent(grid_cells)
    var missing: int = 0
    var ghost: int = 0
    var first_missing: Vector2i = Vector2i(-1, -1)
    var first_ghost: String = ""
    for x: int in extent.x:
        for z: int in extent.y:
            var cell := Vector2i(x, z)
            var in_diamond: bool = CellUtil.is_in_diamond(cell, grid_cells)
            var has_cell: bool = not _ts.get_cell(cell).is_empty()
            if in_diamond and not has_cell:
                missing += 1
                if first_missing.x < 0:
                    first_missing = cell
            elif has_cell and not in_diamond:
                ghost += 1
                if first_ghost.is_empty():
                    first_ghost = CellUtil.cell_key_str(cell)
    editor.free()
    (
        TestHelper
        . assert_true(
            missing == 0 and ghost == 0,
            (
                "21x20 boundary cells match is_in_diamond exactly"
                + ": "
                + (
                    "21x20 missing=%d first=%s ghost=%d first=%s"
                    % [missing, first_missing, ghost, first_ghost]
                )
            ),
        )
    )
    _ts.clear()
    _ts.init_grid(50, 50)


# ========================================
# End-to-end apply_new_map tests
# ========================================
# These test the full pipeline as the user triggers it:
# clear → init_grid → set_visible_bounds_size → prefill → cell_changed → TerrainRenderer


func _apply_map_for_test(w: int, h: int, ox: int = 0, oz: int = 0) -> Node3D:
    # Simulate _apply_new_map without requiring UI/scene tree.
    # This is the exact code path from MapEditor._apply_new_map.
    _ts.clear()
    _ts.init_grid(w, h)
    BoundsSystem.set_visible_bounds_size(Vector2i(ox, oz))
    var editor: Node3D = EDITOR_SCRIPT.new()
    editor._prefill_terrain()
    return editor


func test_apply_new_map_cell_count() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var cases: Array[Array] = [
        [21, 20, 11, 12, 2 * 21 * 20],
        [5, 5, 0, 0, 2 * 5 * 5],
        [50, 50, 40, 42, 2 * 50 * 50],
        [51, 50, 41, 42, 2 * 51 * 50],
    ]
    for c: Array in cases:
        var w: int = c[0] as int
        var h: int = c[1] as int
        var ox: int = c[2] as int
        var oz: int = c[3] as int
        var expected: int = c[4] as int
        var editor: Node3D = _apply_map_for_test(w, h, ox, oz)
        var actual: int = _ts.get_all_cells().size()
        editor.free()
        _ts.clear()
        (
            TestHelper
            . assert_true(
                actual == expected,
                (
                    "apply_new_map %dx%d cell count = %d" % [w, h, expected]
                    + ": "
                    + "apply_new_map %dx%d cell count = %d, expected %d" % [w, h, actual, expected]
                ),
            )
        )
    _ts.init_grid(50, 50)


func test_apply_new_map_no_ghost_cells() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var cases: Array[Array] = [
        [21, 20, 11, 12],
        [5, 5, 0, 0],
        [50, 50, 40, 42],
    ]
    for c: Array in cases:
        var w: int = c[0] as int
        var h: int = c[1] as int
        var ox: int = c[2] as int
        var oz: int = c[3] as int
        var grid_cells := Vector2i(w, h)
        var editor: Node3D = _apply_map_for_test(w, h, ox, oz)
        var cells: Dictionary = _ts.get_all_cells()
        var ghost_count: int = 0
        var first_ghost: String = ""
        for key: String in cells:
            var parts := key.split(",")
            if parts.size() != 2:
                continue
            var cell := Vector2i(int(parts[0]), int(parts[1]))
            if not CellUtil.is_in_diamond(cell, grid_cells):
                ghost_count += 1
                if first_ghost.is_empty():
                    first_ghost = key
        editor.free()
        _ts.clear()
        (
            TestHelper
            . assert_true(
                ghost_count == 0,
                (
                    "apply_new_map %dx%d no ghost cells" % [w, h]
                    + ": "
                    + (
                        "apply_new_map %dx%d has %d ghost cells, first=%s"
                        % [w, h, ghost_count, first_ghost]
                    )
                ),
            )
        )
    _ts.init_grid(50, 50)


func test_apply_new_map_spacing_minimum() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var cases: Array[Array] = [
        [21, 20, 11, 12],
        [5, 5, 0, 0],
        [50, 50, 40, 42],
    ]
    for c: Array in cases:
        var w: int = c[0] as int
        var h: int = c[1] as int
        var ox: int = c[2] as int
        var oz: int = c[3] as int
        var grid_cells := Vector2i(w, h)
        var editor: Node3D = _apply_map_for_test(w, h, ox, oz)
        var positions: Array[Vector3] = []
        var cells: Dictionary = _ts.get_all_cells()
        for key: String in cells:
            var parts := key.split(",")
            if parts.size() != 2:
                continue
            var cell := Vector2i(int(parts[0]), int(parts[1]))
            positions.append(CellUtil.cell_to_world(cell, grid_cells))
        var min_gap: float = 999999.0
        var bad_a: Vector3 = Vector3.ZERO
        var bad_b: Vector3 = Vector3.ZERO
        for i: int in range(positions.size()):
            for j: int in range(i + 1, positions.size()):
                var gap_x: float = absf(positions[i].x - positions[j].x)
                var gap_z: float = absf(positions[i].z - positions[j].z)
                var chebyshev: float = maxf(gap_x, gap_z)
                if chebyshev < min_gap:
                    min_gap = chebyshev
                    bad_a = positions[i]
                    bad_b = positions[j]
        editor.free()
        _ts.clear()
        (
            TestHelper
            . assert_true(
                is_equal_approx(min_gap, CellUtil.CELL_SIZE),
                (
                    "apply_new_map %dx%d min spacing = CELL_SIZE" % [w, h]
                    + ": "
                    + (
                        "apply_new_map %dx%d min spacing = %.4f (expected %.1f), at %s and %s"
                        % [w, h, min_gap, CellUtil.CELL_SIZE, bad_a, bad_b]
                    )
                ),
            )
        )
    _ts.init_grid(50, 50)


func test_apply_new_map_no_half_cell_offsets() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var cases: Array[Array] = [
        [21, 20, 11, 12],
        [5, 5, 0, 0],
        [50, 50, 40, 42],
    ]
    for c: Array in cases:
        var w: int = c[0] as int
        var h: int = c[1] as int
        var ox: int = c[2] as int
        var oz: int = c[3] as int
        var grid_cells := Vector2i(w, h)
        var editor: Node3D = _apply_map_for_test(w, h, ox, oz)
        var half_cell_count: int = 0
        var first_bad_key: String = ""
        var first_bad_pos: Vector3 = Vector3.ZERO
        var cells: Dictionary = _ts.get_all_cells()
        for key: String in cells:
            var parts := key.split(",")
            if parts.size() != 2:
                continue
            var cell := Vector2i(int(parts[0]), int(parts[1]))
            var world_pos: Vector3 = CellUtil.cell_to_world(cell, grid_cells)
            var round_x: float = roundf(world_pos.x)
            var round_z: float = roundf(world_pos.z)
            if (
                not is_equal_approx(world_pos.x, round_x)
                or not is_equal_approx(world_pos.z, round_z)
            ):
                half_cell_count += 1
                if first_bad_key.is_empty():
                    first_bad_key = key
                    first_bad_pos = world_pos
        editor.free()
        _ts.clear()
        (
            TestHelper
            . assert_true(
                half_cell_count == 0,
                (
                    "apply_new_map %dx%d no half-cell offsets" % [w, h]
                    + ": "
                    + (
                        "apply_new_map %dx%d has %d half-cell positions, first=%s at %s"
                        % [w, h, half_cell_count, first_bad_key, first_bad_pos]
                    )
                ),
            )
        )
    _ts.init_grid(50, 50)


func _has_xz_vertex(vertices: PackedVector3Array, expected: Vector3) -> bool:
    for vertex: Vector3 in vertices:
        if is_equal_approx(vertex.x, expected.x) and is_equal_approx(vertex.z, expected.z):
            return true
    return false


func _get_bounds_system() -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    return tree.root.get_node_or_null("BoundsSystem") if tree else null


func _assert_true(value: bool, message: String) -> void:
    TestHelper.assert_true(value, message)


func _assert_eq(got: Variant, expected: Variant, message: String) -> void:
    TestHelper.assert_eq(got, expected, message)


func _assert_vec3_approx(got: Vector3, expected: Vector3, message: String) -> void:
    (
        TestHelper
        . assert_true(
            (
                is_equal_approx(got.x, expected.x)
                and is_equal_approx(got.y, expected.y)
                and is_equal_approx(got.z, expected.z)
            ),
            message,
        )
    )
