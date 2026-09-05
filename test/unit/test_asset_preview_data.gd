extends Node

# Asset preview data contracts: the art seam resolves to existing GLB submeshes,
# mesh rotation matches the direction table, and footprint AABB math.


func _glb_mesh_names() -> Array[String]:
    var resolution := TerrainCatalog.resolve_art(
        "cliff01_n", TerrainCatalog.get_active_theater_id()
    )
    if not resolution.valid or resolution.glb_path.is_empty():
        return []
    var scene := load(resolution.glb_path) as PackedScene
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
    var names := _glb_mesh_names()
    TestHelper.assert_true(not names.is_empty(), "GLB has submesh node names")
    var missing: Array[String] = []
    for object_id in TerrainCatalog.get_all_objects():
        var resolution := TerrainCatalog.resolve_art(String(object_id), "temperate")
        if resolution.valid and not names.has(resolution.submesh_id):
            missing.append("%s -> %s" % [object_id, resolution.submesh_id])
    TestHelper.assert_eq(
        missing.size(), 0, "every catalog variant resolves to an existing GLB submesh"
    )
    for entry in missing:
        print("    missing: " + entry)
    _finish()


func test_mesh_rotation_matches_direction_table():
    # Ground truth from the catalog corner progression (see slope01):
    # _n keeps the base shape, _e rotates it -90 deg (CW) to the south edge,
    # _s by 180, _w by +90 (CCW) to the north edge.
    var want := {"n": 0.0, "e": 270.0, "s": 180.0, "w": 90.0}
    for id in ["cliff01_n", "cliff01_e", "cliff01_s", "cliff01_w"]:
        var suffix := String(id).right(1)
        var resolution := TerrainCatalog.resolve_art(String(id), "temperate")
        TestHelper.assert_eq(resolution.rotation, want[suffix], "rotation for " + id)
    var plain := TerrainCatalog.resolve_art("cliff01", "temperate")
    TestHelper.assert_eq(plain.rotation, 0.0, "non-directional id rotation 0")
    var e := TerrainCatalog.resolve_art("cliff01_e", "temperate")
    TestHelper.assert_eq(e.submesh_id, "cliff01", "directional suffix strips to base submesh")
    var alias := TerrainCatalog.resolve_art("cliff12_n", "temperate")
    TestHelper.assert_eq(alias.submesh_id, "cliff09", "alias object resolves via art submesh")
    _finish()


func test_footprint_bounds_known_tiles():
    var cliff := load("res://games/ts/terrain_objects/cliff01_n.tres") as TerrainObject
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
    var ramp := load("res://games/ts/terrain_objects/ramp01_n.tres") as TerrainObject
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
    pass
