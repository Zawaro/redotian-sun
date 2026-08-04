extends Node

# Asset preview data contracts: art seam resolves to existing GLB submeshes,
# mesh rotation matches the direction table, and footprint AABB math.

var _test_passed := 0
var _test_failed := 0

var _theater: TheaterData = null


func _temperate() -> TheaterData:
    if _theater == null:
        _theater = load("res://resources/theaters/temperate.tres") as TheaterData
    return _theater


func _glb_mesh_names() -> Array[String]:
    var theater := _temperate()
    if theater == null or theater.art_data == null:
        return []
    var scene := load(theater.art_data.glb_path) as PackedScene
    if scene == null:
        return []
    var instance := scene.instantiate()
    var names: Array[String] = []
    _collect_glb_names(instance, names)
    instance.free()
    return names


func _collect_glb_names(node: Node, names: Array[String]) -> void:
    if node is MeshInstance3D:
        names.append(String(node.name).trim_suffix("_3D"))
    for child in node.get_children():
        _collect_glb_names(child, names)


func test_mesh_names_resolve_to_glb_submeshes():
    var theater := _temperate()
    TestHelper.assert_true(
        theater != null and theater.art_data != null, "temperate theater + art load"
    )
    if theater == null or theater.art_data == null:
        _finish()
        return
    var names := _glb_mesh_names()
    TestHelper.assert_true(not names.is_empty(), "GLB has submesh node names")
    var missing: Array[String] = []
    for object_id in theater.terrain_objects:
        var resolved := theater.art_data.mesh_name(String(object_id))
        if not names.has(resolved):
            missing.append("%s -> %s" % [object_id, resolved])
    TestHelper.assert_eq(
        missing.size(), 0, "every theater variant resolves to an existing GLB submesh"
    )
    for entry in missing:
        print("    missing: " + entry)
    _finish()


func test_mesh_rotation_matches_direction_table():
    var theater := _temperate()
    TestHelper.assert_true(
        theater != null and theater.art_data != null, "theater + art load for rotation"
    )
    if theater == null or theater.art_data == null:
        _finish()
        return
    # Ground truth from the catalog corner progression (see slope01):
    # _n keeps the base shape, _e rotates it -90 deg (CW) to the south edge,
    # _s by 180, _w by +90 (CCW) to the north edge.
    var want := {"n": 0.0, "e": 270.0, "s": 180.0, "w": 90.0}
    for id in ["cliff01_n", "cliff01_e", "cliff01_s", "cliff01_w"]:
        var suffix := String(id).right(1)
        TestHelper.assert_eq(theater.art_data.mesh_rotation(id), want[suffix], "rotation for " + id)
    TestHelper.assert_eq(
        theater.art_data.mesh_rotation("cliff01"), 0.0, "non-directional id rotation 0"
    )
    TestHelper.assert_eq(
        theater.art_data.mesh_name("cliff01_e"), "cliff01", "directional suffix stripped"
    )
    (
        TestHelper
        . assert_eq(
            theater.art_data.mesh_name("cliff_straight_n"),
            "cliff23",
            "suffixed seed id resolves via fallback table",
        )
    )
    _finish()


func test_footprint_bounds_known_tiles():
    var cliff := load("res://resources/terrain_objects/cliff01_n.tres") as TerrainObject
    TestHelper.assert_true(cliff != null, "cliff01_n loads")
    if cliff == null:
        _finish()
        return
    var b := TerrainObject.footprint_bounds(cliff)
    TestHelper.assert_eq(b.position, Vector3(0, 0, 0), "cliff01_n min cell/min height at origin")
    TestHelper.assert_eq(b.size, Vector3(2, 4, 3), "cliff01_n spans 2x4x3 lattice units")
    for key in cliff.cells:
        var parts: PackedStringArray = String(key).split(",")
        var x := int(parts[0])
        var z := int(parts[1])
        (
            TestHelper
            . assert_true(
                x >= int(b.position.x) and x < int(b.position.x + b.size.x),
                "cliff01_n cell x within bounds: " + key,
            )
        )
        (
            TestHelper
            . assert_true(
                z >= int(b.position.z) and z < int(b.position.z + b.size.z),
                "cliff01_n cell z within bounds: " + key,
            )
        )
    var ramp := load("res://resources/terrain_objects/ramp01_n.tres") as TerrainObject
    TestHelper.assert_true(ramp != null, "ramp01_n loads")
    if ramp == null:
        _finish()
        return
    var rb := TerrainObject.footprint_bounds(ramp)
    TestHelper.assert_eq(rb.position.y, 0, "ramp01_n min height 0")
    TestHelper.assert_true(rb.size.y > 0, "ramp01_n has a height span")
    TestHelper.assert_true(
        rb.size.x >= 3 and rb.size.z >= 3, "ramp01_n footprint spans multiple cells"
    )
    _finish()


func _finish() -> void:
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
