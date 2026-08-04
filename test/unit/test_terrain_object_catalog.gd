extends Node

# TS-derived TerrainObject catalog: baked 4-direction variants, per-cell
# corners/crease, and registration in the temperate theater.

var _test_passed := 0
var _test_failed := 0


func _catalog_obj(object_id: String) -> TerrainObject:
    return load("res://resources/terrain_objects/%s.tres" % object_id) as TerrainObject


var _theater: TheaterData = null


func _temperate() -> TheaterData:
    if _theater == null:
        _theater = load("res://resources/theaters/temperate.tres") as TheaterData
    return _theater


func _cell_of(obj: TerrainObject, key: String) -> Dictionary:
    var entry: Variant = obj.cells.get(key, {})
    return entry if entry is Dictionary else {}


func _corners_of(obj: TerrainObject, key: String) -> Array:
    var cell: Dictionary = _cell_of(obj, key)
    return cell.get("corners", []) as Array


func test_cliff01_n_matches_ts_footprint():
    var cliff := _catalog_obj("cliff01_n")
    TestHelper.assert_true(cliff != null, "cliff01_n.tres loads")
    if cliff == null:
        _finish()
        return
    TestHelper.assert_eq(cliff.id, "cliff01_n", "cliff01_n id")
    TestHelper.assert_eq(cliff.cell_type, "cliff", "cliff01_n cell_type")
    TestHelper.assert_eq(cliff.cells.size(), 4, "cliff01_n has the TS tile's 4 occupied cells")
    TestHelper.assert_eq(cliff.land_type_at("0,0"), "rock", "cliff01_n (0,0) rock")
    TestHelper.assert_eq(cliff.land_type_at("0,1"), "rock", "cliff01_n (0,1) rock")
    TestHelper.assert_eq(cliff.land_type_at("1,1"), "rock", "cliff01_n (1,1) rock")
    TestHelper.assert_eq(cliff.land_type_at("1,2"), "rock", "cliff01_n (1,2) rock")
    TestHelper.assert_eq(_corners_of(cliff, "0,0"), [4, 4, 4, 4], "cliff01_n (0,0) flat height 4")
    TestHelper.assert_eq(_corners_of(cliff, "0,1"), [0, 0, 0, 0], "cliff01_n (0,1) flat height 0")
    TestHelper.assert_eq(_corners_of(cliff, "1,1"), [4, 4, 4, 4], "cliff01_n (1,1) flat height 4")
    TestHelper.assert_eq(_corners_of(cliff, "1,2"), [0, 0, 0, 0], "cliff01_n (1,2) flat height 0")
    _finish()


func test_ramp01_n_has_sloped_corners():
    var ramp := _catalog_obj("ramp01_n")
    TestHelper.assert_true(ramp != null, "ramp01_n.tres loads")
    if ramp == null:
        _finish()
        return
    TestHelper.assert_eq(ramp.cell_type, "ramp", "ramp01_n cell_type")
    TestHelper.assert_eq(ramp.cells.size(), 10, "ramp01_n has the TS ramp's 10 cells")
    # Climbing column descends 3 -> 0; each cell's corners follow height + slope.
    TestHelper.assert_true(_corners_of(ramp, "2,0").size() == 4, "ramp01_n (2,0) has 4 corners")
    var c20: Array = _corners_of(ramp, "2,0")
    TestHelper.assert_eq(int(c20[0]), 4, "ramp01_n (2,0) NW corner 4")
    TestHelper.assert_eq(int(c20[3]), 3, "ramp01_n (2,0) SW corner 3")
    TestHelper.assert_eq(ramp.land_type_at("2,0"), "clear", "ramp01_n (2,0) climb surface clear")
    TestHelper.assert_eq(ramp.land_type_at("0,1"), "rock", "ramp01_n (0,1) wall rock")
    _finish()


func test_variant_corners_pre_rotated_per_facing():
    # _e must be _n rotated 90 degrees: cell positions rotate, corner tuples cycle.
    # cliff01_n occupies (0,0),(0,1),(1,1),(1,2); 90deg CW maps them to
    # (2,0),(1,0),(1,1),(0,1) on a 2x3 tile.
    var north := _catalog_obj("cliff01_n")
    var east := _catalog_obj("cliff01_e")
    TestHelper.assert_true(north != null and east != null, "cliff01 n/e variants load")
    if north == null or east == null:
        _finish()
        return
    TestHelper.assert_eq(north.cells.size(), east.cells.size(), "n/e variants same cell count")
    TestHelper.assert_eq(
        east.land_type_at("2,0"), "rock", "cliff01_e (2,0) rock (rotated footprint)"
    )
    TestHelper.assert_eq(
        east.land_type_at("0,1"), "rock", "cliff01_e (0,1) rock (rotated footprint)"
    )
    TestHelper.assert_eq(east.land_type_at("0,0"), "", "cliff01_e (0,0) unoccupied after rotation")
    TestHelper.assert_eq(_corners_of(east, "2,0"), [4, 4, 4, 4], "cliff01_e (2,0) flat height 4")
    TestHelper.assert_eq(_corners_of(east, "0,1"), [0, 0, 0, 0], "cliff01_e (0,1) flat height 0")
    _finish()


func _crease_for_corners(corners: Array) -> String:
    var lo: int = corners[0]
    var hi: int = corners[0]
    for c in corners:
        lo = mini(lo, int(c))
        hi = maxi(hi, int(c))
    if hi == lo:
        return "flat"
    var high: Array[int] = []
    for i in 4:
        if int(corners[i]) == hi:
            high.append(i)
    if high.size() == 2:
        if (high[0] - high[1]) % 2 == 0:
            return "y"
        return "flat"
    return "x"


func test_crease_values_valid():
    for path in [
        "res://resources/terrain_objects/cliff01_n.tres",
        "res://resources/terrain_objects/ramp01_n.tres",
        "res://resources/terrain_objects/ramp01_e.tres",
        "res://resources/terrain_objects/slope01_n.tres",
        "res://resources/terrain_objects/wcliff01_n.tres",
        "res://resources/terrain_objects/dcliff01_n.tres",
    ]:
        var obj: TerrainObject = load(path)
        TestHelper.assert_true(obj != null, "catalog tile loads: " + path)
        if obj:
            for key in obj.cells:
                var cell: Dictionary = _cell_of(obj, key)
                var crease: String = String(cell.get("crease", ""))
                TestHelper.assert_true(
                    ["flat", "x", "y"].has(crease), "crease valid in " + path + " @" + key
                )
                var corners: Array = cell.get("corners", [])
                TestHelper.assert_true(
                    corners.size() == 4, "corners has 4 entries in " + path + " @" + key
                )
                if corners.size() == 4:
                    (
                        TestHelper
                        . assert_eq(
                            crease,
                            _crease_for_corners(corners),
                            "crease matches corners in " + path + " @" + key,
                        )
                    )
    _finish()


func test_connections_consistent_with_cells():
    var offsets := {
        "north": Vector2i(0, -1),
        "south": Vector2i(0, 1),
        "west": Vector2i(-1, 0),
        "east": Vector2i(1, 0),
    }
    for path in [
        "res://resources/terrain_objects/cliff01_n.tres",
        "res://resources/terrain_objects/ramp01_n.tres",
    ]:
        var obj: TerrainObject = load(path)
        if obj == null:
            TestHelper.assert_true(false, "tile loads for seam check: " + path)
            continue
        for cell_key in obj.cells:
            var parts: PackedStringArray = cell_key.split(",")
            var x := int(parts[0])
            var y := int(parts[1])
            var cell: Dictionary = _cell_of(obj, cell_key)
            var conns: Dictionary = cell.get("connections", {})
            for edge in conns:
                var entry: Dictionary = conns.get(edge, {})
                var role := String(entry.get("role", ""))
                if role == "ramp":
                    var offset: Vector2i = offsets.get(edge, Vector2i.ZERO)
                    var neighbor_key := "%d,%d" % [x + offset.x, y + offset.y]
                    var neighbor: Dictionary = _cell_of(obj, neighbor_key)
                    var neighbor_corners: Array = neighbor.get("corners", [])
                    var cell_corners: Array = cell.get("corners", [])
                    (
                        TestHelper
                        . assert_true(
                            not neighbor_corners.is_empty() and not cell_corners.is_empty(),
                            "ramp edge %s has corner data" % edge,
                        )
                    )
                else:
                    (
                        TestHelper
                        . assert_true(
                            ["cliff", "ground", "water"].has(role),
                            "boundary role is valid: " + role,
                        )
                    )
    _finish()


func test_temperate_theater_registers_catalog():
    var theater := _temperate()
    TestHelper.assert_true(theater != null, "temperate.tres loads")
    if theater == null:
        _finish()
        return
    TestHelper.assert_eq(theater.id, "temperate", "temperate theater id")
    TestHelper.assert_eq(theater.default_land_type, "clear", "temperate default land type")
    TestHelper.assert_true(theater.art_data != null, "temperate has art_data")
    # Count must match the generated catalog: every registered id is a
    # directional variant (<base>_<dir>) and every variant is registered, so the
    # count is derived rather than a hardcoded magic number.
    var expected_count := 0
    for object_id in theater.terrain_objects:
        if String(object_id).ends_with("_n"):
            expected_count += 4
    TestHelper.assert_eq(
        theater.terrain_objects.size(), expected_count, "variants registered in 4s"
    )
    TestHelper.assert_true(expected_count > 0, "expected_count derived from catalog is non-zero")
    for tile_id in [
        "cliff01_n",
        "cliff01_e",
        "cliff01_s",
        "cliff01_w",
        "ramp01_n",
        "ramp02_n",
        "wcliff01_n",
        "slope01_n",
        "clear01_n",
        "dcliff01_n",
    ]:
        var obj := theater.get_terrain_object(tile_id)
        TestHelper.assert_true(obj != null, "catalog variant registered: " + tile_id)
    var missing := theater.get_terrain_object("not_a_tile")
    TestHelper.assert_eq(missing, null, "unknown object id returns null")
    _finish()


func test_all_catalog_tiles_load_with_valid_cells():
    var theater := _temperate()
    TestHelper.assert_true(theater != null, "temperate.tres loads for full scan")
    if theater == null:
        _finish()
        return
    var scanned := 0
    for object_id in theater.terrain_objects:
        var obj: TerrainObject = theater.get_terrain_object(String(object_id))
        TestHelper.assert_true(obj != null, "registered object loads: " + String(object_id))
        if obj == null:
            continue
        TestHelper.assert_true(not obj.cells.is_empty(), "object has cells: " + String(object_id))
        for key in obj.cells:
            var cell: Dictionary = _cell_of(obj, key)
            var corners: Array = cell.get("corners", [])
            var crease: String = String(cell.get("crease", ""))
            TestHelper.assert_true(
                corners.size() == 4, "4 corners: " + String(object_id) + " @" + key
            )
            TestHelper.assert_true(
                ["flat", "x", "y"].has(crease), "valid crease: " + String(object_id) + " @" + key
            )
            scanned += 1
    TestHelper.assert_true(scanned > 0, "scanned at least one cell")
    _finish()


func test_art_seam_suffix_and_rotation():
    var art: TerrainArtData = load("res://resources/art/terrain/placeholder_terrain_art.tres")
    TestHelper.assert_true(art != null, "placeholder art loads")
    if art == null:
        _finish()
        return
    TestHelper.assert_true(art.is_placeholder, "placeholder art flagged as placeholder")
    TestHelper.assert_eq(art.mesh_name("cliff01_n"), "cliff01", "_n strips suffix to base mesh")
    TestHelper.assert_eq(art.mesh_name("cliff01_e"), "cliff01", "_e strips suffix to base mesh")
    TestHelper.assert_eq(art.mesh_name("ramp01_s"), "ramp01", "_s strips suffix to base mesh")
    TestHelper.assert_eq(art.mesh_name("wcliff23_w"), "wcliff23", "_w strips suffix to base mesh")
    TestHelper.assert_eq(art.base_mesh_id("cliff01_n"), "cliff01", "base_mesh_id strips suffix")
    TestHelper.assert_eq(art.base_mesh_id("cliff01"), "cliff01", "base_mesh_id passes through")
    TestHelper.assert_eq(art.mesh_rotation("cliff01_n"), 0.0, "n rotation 0")
    TestHelper.assert_eq(
        art.mesh_rotation("cliff01_e"), 270.0, "e rotation 270 (CW to match catalog corners)"
    )
    TestHelper.assert_eq(art.mesh_rotation("cliff01_s"), 180.0, "s rotation 180")
    TestHelper.assert_eq(
        art.mesh_rotation("cliff01_w"), 90.0, "w rotation 90 (CCW to match catalog corners)"
    )
    TestHelper.assert_eq(art.mesh_rotation("cliff01"), 0.0, "non-directional rotation 0")
    TestHelper.assert_eq(art.mesh_name("cliff12_n"), "cliff09", "fallback table resolves base id")
    TestHelper.assert_eq(art.mesh_name("ramp06_e"), "ramp01", "fallback applies after suffix strip")
    _finish()


func _finish() -> void:
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
