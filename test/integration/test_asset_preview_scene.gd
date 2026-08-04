extends Node

# Asset preview scene integration: headless load, mesh state matches the
# resolved art, full 140-variant cycle, and camera/spin/state toggles.

var _scene: Node = null
var _controller: Node = null
var _theater: TheaterData = null


func _ensure_scene() -> bool:
    if _scene != null:
        return _controller != null
    _theater = load("res://resources/theaters/temperate.tres") as TheaterData
    var packed := load("res://scenes/AssetPreview.tscn") as PackedScene
    if packed == null:
        TestHelper.assert_true(false, "AssetPreview.tscn loads")
        return false
    var tree := Engine.get_main_loop() as SceneTree
    _scene = packed.instantiate()
    tree.root.add_child(_scene)
    _controller = _scene
    return _controller != null


func test_scene_loads_and_selects_first_family():
    if not _ensure_scene():
        _finish()
        return
    var id: String = _controller.current_object_id()
    TestHelper.assert_eq(id, "clat01_n", "first family _n auto-loaded")
    TestHelper.assert_true(_controller.get_family_count() > 0, "families enumerated")
    TestHelper.assert_true(_controller.get_theater() != null, "controller holds theater")
    _finish()


func test_mesh_state_matches_resolved_art():
    if not _ensure_scene():
        _finish()
        return
    var id: String = _controller.current_object_id()
    var art: TerrainArtData = _theater.art_data
    var expected := art.mesh_name(id)
    var mesh_node := _controller.get_mesh_node() as MeshInstance3D
    TestHelper.assert_true(mesh_node != null, "mesh state yields a MeshInstance3D for " + id)
    if mesh_node != null:
        TestHelper.assert_true(mesh_node.mesh != null, "mesh has geometry")
        TestHelper.assert_eq(
            mesh_node.rotation_degrees.y, 0.0, "mesh node itself carries no facing rotation"
        )
        TestHelper.assert_true(_controller.get_state(0), "mesh state on by default")
    var pivot: Node3D = _controller.get_mesh_pivot()
    TestHelper.assert_true(pivot != null, "mesh pivot exists for facing check")
    if pivot != null:
        (
            TestHelper
            . assert_eq(
                pivot.rotation_degrees.y,
                art.mesh_rotation(id),
                "pivot rotates mesh to variant facing around the footprint center",
            )
        )
    _finish()


func test_mesh_pivot_is_footprint_centered():
    if not _ensure_scene():
        _finish()
        return
    var root: Node3D = _controller.get_object_root()
    var pivot: Node3D = _controller.get_mesh_pivot()
    TestHelper.assert_true(pivot != null, "mesh pivot exists")
    if pivot == null:
        _finish()
        return
    TestHelper.assert_true(pivot.get_parent() == root, "mesh pivot is a child of the object root")
    var obj: TerrainObject = _controller.current_object()
    var bounds := TerrainObject.footprint_bounds(obj)
    var center := Vector3(
        bounds.size.x * CellUtil.CELL_SIZE * 0.5,
        bounds.size.y * TerrainSystem.HEIGHT_STEP * 0.5,
        bounds.size.z * CellUtil.CELL_SIZE * 0.5
    )
    TestHelper.assert_eq(pivot.position, center, "mesh pivot sits at the footprint center")
    var mesh_node: Node3D = _controller.get_mesh_node()
    TestHelper.assert_true(mesh_node != null, "mesh node exists for pivot check")
    if mesh_node != null:
        TestHelper.assert_true(mesh_node.get_parent() == pivot, "mesh is a child of the pivot")
        (
            TestHelper
            . assert_eq(
                mesh_node.position,
                -center,
                "mesh offset so its origin lands on the footprint corner",
            )
        )
    _finish()


func test_all_variants_cycle_without_errors():
    if not _ensure_scene():
        _finish()
        return
    var theater := _theater
    var visited: Array[String] = []
    var family_count: int = _controller.get_family_count()
    TestHelper.assert_eq(
        family_count * 4, theater.terrain_objects.size(), "families x 4 == registered variants"
    )
    for f in family_count:
        _controller.select_family(f)
        for d in ["n", "e", "s", "w"]:
            _controller.select_direction(d)
            var id: String = _controller.current_object_id()
            (
                TestHelper
                . assert_true(
                    theater.terrain_objects.has(id),
                    "variant registered in theater: " + id,
                )
            )
            if not visited.has(id):
                visited.append(id)
    TestHelper.assert_eq(visited.size(), theater.terrain_objects.size(), "all variants reachable")
    _finish()


func test_camera_and_spin_toggles():
    if not _ensure_scene():
        _finish()
        return
    _controller.toggle_camera_mode()
    TestHelper.assert_true(_controller.is_orbit_active(), "camera toggles to orbit")
    _controller.toggle_camera_mode()
    TestHelper.assert_true(not _controller.is_orbit_active(), "camera toggles back to iso")
    _controller.toggle_spin()
    TestHelper.assert_true(_controller.is_spin_enabled(), "spin toggles on")
    _controller.toggle_spin()
    TestHelper.assert_true(not _controller.is_spin_enabled(), "spin toggles off")
    _finish()


func test_state_toggles_and_cell_highlight():
    if not _ensure_scene():
        _finish()
        return
    for state in [1, 2, 3]:
        _controller.set_state(state, true)
        TestHelper.assert_true(_controller.get_state(state), "state %d enables" % state)
        _controller.set_state(state, false)
        TestHelper.assert_true(not _controller.get_state(state), "state %d disables" % state)
    _controller.cycle_state()
    TestHelper.assert_true(
        _controller.get_state(_controller.get_state_focus()), "state cycle flips focus state"
    )
    var root: Node3D = _controller.get_object_root()
    var highlight := root.get_node_or_null("CellHighlight")
    TestHelper.assert_true(highlight == null, "no highlight before cell click")
    var obj: TerrainObject = _controller.current_object()
    if obj != null and not obj.cells.is_empty():
        var cell_key: String = String(obj.cells.keys()[0])
        _controller._highlight_cell(cell_key)
        highlight = root.get_node_or_null("CellHighlight")
        TestHelper.assert_true(highlight != null, "cell click creates highlight for " + cell_key)
        if highlight != null:
            var immesh := (highlight as MeshInstance3D).mesh as ImmediateMesh
            TestHelper.assert_true(immesh != null, "highlight has geometry")
        root.remove_child(highlight)
        highlight.queue_free()
    else:
        TestHelper.assert_true(false, "current object has cells to highlight")
    _controller.cycle_state()  # reset focus toggle
    _finish()


func test_cleanup_frees_scene():
    if _scene != null:
        var tree := Engine.get_main_loop() as SceneTree
        tree.root.remove_child(_scene)
        _scene.queue_free()
        _scene = null
        _controller = null
        TestHelper.assert_true(true, "preview scene freed")
    else:
        TestHelper.assert_true(true, "no scene to free")
    _finish()


func _finish() -> void:
    pass
