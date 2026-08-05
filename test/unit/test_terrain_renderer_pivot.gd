extends Node

# Corner-pivot terrain tiles must be placed and rotated about the foundation
# center, not the mesh's corner pivot. Verifies CellUtil.tile_transform keeps a
# tile's footprint centered on its cell at any rotation (pure math — MultiMesh
# instance transforms aren't readable in headless), and that the renderer routes
# through it.

const RENDERER_SCRIPT := "res://scripts/core/TerrainRenderer.gd"


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _make_node(script_path: String) -> Node:
    var node := Node.new()
    node.set_script(load(script_path))
    _tree().root.add_child(node)
    return node


func _cleanup(node: Node) -> void:
    if is_instance_valid(node):
        _tree().root.remove_child(node)
        node.queue_free()


func _assert_centered(xform: Transform3D, center: Vector3, aabb: AABB, label: String) -> void:
    var world_center := (xform * aabb).get_center()
    TestHelper.assert_true(absf(world_center.x - center.x) < 0.01, "%s centered x" % label)
    TestHelper.assert_true(absf(world_center.z - center.z) < 0.01, "%s centered z" % label)


func test_tile_transform_centers_footprint_unrotated():
    var center := CellUtil.cell_to_world(Vector2i(0, 0))
    var half := Vector3(1.0, 0.0, 1.0)
    var aabb := AABB(Vector3.ZERO, Vector3(2.0, 0.1, 2.0))
    _assert_centered(CellUtil.tile_transform(center, 0.0, half), center, aabb, "unrotated")
    _finish()


func test_tile_transform_rotates_about_foundation_center():
    var center := CellUtil.cell_to_world(Vector2i(2, 1))
    var half := Vector3(1.0, 0.0, 1.0)
    var aabb := AABB(Vector3.ZERO, Vector3(2.0, 0.815, 2.0))
    for rot in [90.0, 180.0, 270.0]:
        _assert_centered(
            CellUtil.tile_transform(center, rot, half), center, aabb, "rotated %d" % rot
        )
    var basis := Basis(Vector3.UP, deg_to_rad(90.0))
    var expected_origin := center - basis * half
    var x90 := CellUtil.tile_transform(center, 90.0, half)
    TestHelper.assert_true(
        x90.origin.distance_to(expected_origin) < 0.01, "origin offset by rotated half"
    )
    TestHelper.assert_true(
        x90.basis.is_equal_approx(basis), "rotation applied about the foundation center"
    )
    _finish()


func test_tile_transform_generalizes_to_multicell_half():
    # A 3x3 tile has half (3,0,3); its footprint must still center on the cell.
    var center := Vector3(10.0, 0.0, 10.0)
    var half := Vector3(3.0, 0.0, 3.0)
    var aabb := AABB(Vector3.ZERO, Vector3(6.0, 3.26, 6.0))
    _assert_centered(CellUtil.tile_transform(center, 90.0, half), center, aabb, "multicell 90")
    _finish()


func test_renderer_resolves_corner_pivot_submesh():
    var renderer := _make_node(RENDERER_SCRIPT)
    renderer.clear_all()
    var cell := Vector2i(0, 0)
    renderer.render_cell(cell, {"type": "clear", "variant": 1, "height": 0, "rotation": 0.0})
    var key := CellUtil.cell_key_str(cell)
    var entry: Dictionary = renderer._instance_data.get(key, {})
    TestHelper.assert_true(entry.has("mesh_name"), "clear cell instance recorded")
    if entry.has("mesh_name"):
        TestHelper.assert_eq(String(entry["mesh_name"]), "clear01", "resolves clear01 submesh")
    _cleanup(renderer)
    _finish()


func _finish() -> void:
    pass
