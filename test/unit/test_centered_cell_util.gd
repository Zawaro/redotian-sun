extends Node

# Coordinate-system tests use independent geometric invariants and gameplay lookups.

var _ts: Node = null


func test_world_origin_for_all_map_parities() -> void:
    var map_sizes: Array[Vector2i] = [
        Vector2i(50, 50),
        Vector2i(51, 50),
        Vector2i(50, 51),
        Vector2i(51, 51),
        Vector2i(24, 20),
        Vector2i(21, 33),
    ]
    for grid_cells: Vector2i in map_sizes:
        var center: float = float(grid_cells.x + grid_cells.y) * 0.5
        var expected_cell := Vector2i(floori(center), floori(center))
        var origin_cell: Vector2i = CellUtil.world_to_cell(Vector3.ZERO, grid_cells)
        _assert_eq(origin_cell, expected_cell, "%s origin cell" % grid_cells)

        var selected_center: Vector3 = CellUtil.cell_to_world(origin_cell, grid_cells)
        if (grid_cells.x + grid_cells.y) % 2 == 1:
            _assert_vec3_approx(
                selected_center,
                Vector3.ZERO,
                "%s mixed parity has a cell centered at origin" % grid_cells
            )
        else:
            var half_cell := Vector3(CellUtil.CELL_SIZE * 0.5, 0.0, CellUtil.CELL_SIZE * 0.5)
            _assert_vec3_approx(
                selected_center,
                half_cell,
                "%s same parity has origin at a four-cell corner" % grid_cells
            )


func test_cell_world_coordinates_mirror_about_origin() -> void:
    var map_sizes: Array[Vector2i] = [
        Vector2i(24, 20), Vector2i(20, 24), Vector2i(51, 50), Vector2i(51, 51)
    ]
    for grid_cells: Vector2i in map_sizes:
        var extent: int = grid_cells.x + grid_cells.y
        var samples: Array[Vector2i] = [
            Vector2i(0, 0),
            Vector2i(extent - 1, 0),
            Vector2i(7, 11),
            Vector2i(extent / 2, extent / 3),
        ]
        for cell: Vector2i in samples:
            var mirror := Vector2i(extent - 1 - cell.x, extent - 1 - cell.y)
            var world: Vector3 = CellUtil.cell_to_world(cell, grid_cells)
            var mirrored_world: Vector3 = CellUtil.cell_to_world(mirror, grid_cells)
            _assert_vec3_approx(
                mirrored_world,
                -world,
                "%s cell %s mirrors through world origin" % [grid_cells, cell]
            )


func test_world_cell_roundtrip_across_real_map_area() -> void:
    var map_sizes: Array[Vector2i] = [
        Vector2i(20, 20), Vector2i(21, 20), Vector2i(20, 21), Vector2i(21, 21)
    ]
    for grid_cells: Vector2i in map_sizes:
        var extent: int = grid_cells.x + grid_cells.y
        var all_roundtrip: bool = true
        for x: int in range(0, extent, 3):
            for z: int in range(0, extent, 3):
                var cell := Vector2i(x, z)
                if not CellUtil.is_in_diamond(cell, grid_cells):
                    continue
                var world: Vector3 = CellUtil.cell_to_world(cell, grid_cells)
                if CellUtil.world_to_cell(world, grid_cells) != cell:
                    all_roundtrip = false
                    break
            if not all_roundtrip:
                break
        _assert_true(all_roundtrip, "%s playable cells round-trip through world space" % grid_cells)


func test_foundation_center_is_average_of_corner_cells() -> void:
    var map_sizes: Array[Vector2i] = [
        Vector2i(50, 50), Vector2i(51, 50), Vector2i(50, 51), Vector2i(51, 51)
    ]
    var footprints: Array[Vector2i] = [
        Vector2i(1, 1), Vector2i(2, 3), Vector2i(3, 2), Vector2i(4, 4)
    ]
    var origin := Vector2i(17, 23)
    for grid_cells: Vector2i in map_sizes:
        for footprint: Vector2i in footprints:
            var first_center: Vector3 = CellUtil.cell_to_world(origin, grid_cells)
            var last_cell := origin + footprint - Vector2i.ONE
            var last_center: Vector3 = CellUtil.cell_to_world(last_cell, grid_cells)
            var expected_center: Vector3 = (first_center + last_center) * 0.5
            var actual_center: Vector3 = CellUtil.cell_origin_to_world(
                origin, footprint, grid_cells
            )
            _assert_vec3_approx(
                actual_center,
                expected_center,
                "%s footprint %s center is geometric average" % [grid_cells, footprint]
            )
            _assert_eq(
                CellUtil.world_to_cell_origin(actual_center, footprint, grid_cells),
                origin,
                "%s footprint %s origin round-trip" % [grid_cells, footprint]
            )


func test_one_cell_foundation_matches_cell_center() -> void:
    var grid_cells := Vector2i(51, 50)
    var cells: Array[Vector2i] = [Vector2i(50, 50), Vector2i(25, 75), Vector2i(75, 25)]
    for cell: Vector2i in cells:
        _assert_vec3_approx(
            CellUtil.cell_origin_to_world(cell, Vector2i.ONE, grid_cells),
            CellUtil.cell_to_world(cell, grid_cells),
            "1x1 foundation at %s uses the cell center" % cell
        )


func test_half_open_raster_has_exact_real_map_cell_count() -> void:
    var map_sizes: Array[Vector2i] = [
        Vector2i(20, 20),
        Vector2i(21, 20),
        Vector2i(20, 21),
        Vector2i(21, 21),
        Vector2i(24, 20),
        Vector2i(20, 24),
        Vector2i(21, 33),
        Vector2i(51, 50),
        Vector2i(50, 51),
        Vector2i(51, 51),
    ]
    for grid_cells: Vector2i in map_sizes:
        var extent: int = grid_cells.x + grid_cells.y
        var inside_count: int = 0
        for x: int in extent:
            for z: int in extent:
                if CellUtil.is_in_diamond(Vector2i(x, z), grid_cells):
                    inside_count += 1
        _assert_eq(
            inside_count,
            2 * grid_cells.x * grid_cells.y,
            "%s raster contains exactly 2*W*H cells" % grid_cells
        )


func test_raster_cells_follow_centered_rotated_axes() -> void:
    var map_sizes: Array[Vector2i] = [
        Vector2i(24, 20), Vector2i(20, 24), Vector2i(21, 33), Vector2i(51, 50)
    ]
    for grid_cells: Vector2i in map_sizes:
        var extent: int = grid_cells.x + grid_cells.y
        var all_inside_axes: bool = true
        for x: int in extent:
            for z: int in extent:
                var cell := Vector2i(x, z)
                if not CellUtil.is_in_diamond(cell, grid_cells):
                    continue
                var world: Vector3 = CellUtil.cell_to_world(cell, grid_cells)
                var sum_axis: float = (world.x + world.z) / CellUtil.CELL_SIZE
                var difference_axis: float = (world.x - world.z) / CellUtil.CELL_SIZE
                if (
                    sum_axis < -float(grid_cells.y)
                    or sum_axis >= float(grid_cells.y)
                    or difference_axis < -float(grid_cells.x)
                    or difference_axis >= float(grid_cells.x)
                ):
                    all_inside_axes = false
                    break
            if not all_inside_axes:
                break
        _assert_true(
            all_inside_axes, "%s raster stays inside its centered rotated axes" % grid_cells
        )


func test_terrain_lookup_at_world_origin_uses_centered_cell() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    var grid_cells := Vector2i(51, 50)
    _ts.clear()
    _ts.init_grid(grid_cells.x, grid_cells.y)
    var origin_cell: Vector2i = CellUtil.world_to_cell(Vector3.ZERO, grid_cells)
    var key: String = CellUtil.cell_key_str(origin_cell)
    _ts._cells[key] = {"height": 3, "type": "clear"}

    _assert_eq(
        _ts.get_cell_at_world(Vector3.ZERO).get("type", ""),
        "clear",
        "terrain lookup at world origin resolves the centered cell"
    )
    _assert_true(
        is_equal_approx(_ts.get_height_at_world(Vector3.ZERO), 3.0 * _ts.HEIGHT_STEP),
        "terrain height at world origin comes from the centered cell"
    )
    _ts.clear()
    _ts.init_grid(50, 50)


func test_grid_cache_invalidates_on_init() -> void:
    if _ts == null:
        _assert_true(false, "TerrainSystem is injected")
        return
    _ts.init_grid(51, 50)
    var origin_odd: Vector2i = CellUtil.world_to_cell(Vector3.ZERO)
    _assert_eq(origin_odd, Vector2i(50, 50), "51x50 grid centers origin at cell (50, 50)")

    _ts.init_grid(20, 20)
    var origin_even: Vector2i = CellUtil.world_to_cell(Vector3.ZERO)
    _assert_eq(origin_even, Vector2i(20, 20), "20x20 grid centers origin at cell (20, 20)")
    _ts.clear()
    _ts.init_grid(50, 50)


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
