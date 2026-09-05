extends Node

# TerrainArtData resolve() seam: per-element art owns glb/submesh/rotation and
# per-theater overrides; invalid resolution signals the pink placeholder path.


func _art(id: String) -> TerrainArtData:
    return load("res://games/ts/art/terrain/%s.tres" % id) as TerrainArtData


func test_resolve_default_model_and_submesh():
    var art := _art("cliff01")
    TestHelper.assert_true(art != null, "cliff01 art loads")
    if art == null:
        _finish()
        return
    var res := art.resolve("cliff01_n", "temperate")
    TestHelper.assert_true(res.valid, "cliff01_n resolves")
    TestHelper.assert_eq(res.submesh_id, "cliff01", "submesh defaults to element base id")
    TestHelper.assert_eq(res.glb_path, art.model_path, "no override uses model_path")
    TestHelper.assert_eq(res.rotation, 0.0, "n rotation 0")


func test_resolve_directional_rotation():
    var art := _art("cliff01")
    TestHelper.assert_true(art != null, "cliff01 art loads for rotation")
    if art == null:
        _finish()
        return
    TestHelper.assert_eq(art.resolve("cliff01_e", "temperate").rotation, 270.0, "e rotation 270")
    TestHelper.assert_eq(art.resolve("cliff01_s", "temperate").rotation, 180.0, "s rotation 180")
    TestHelper.assert_eq(art.resolve("cliff01_w", "temperate").rotation, 90.0, "w rotation 90")
    TestHelper.assert_eq(art.resolve("cliff01", "temperate").rotation, 0.0, "non-directional 0")


func test_resolve_alias_submesh():
    var art := _art("cliff12")
    TestHelper.assert_true(art != null, "cliff12 art loads")
    if art == null:
        _finish()
        return
    var res := art.resolve("cliff12_n", "temperate")
    TestHelper.assert_true(res.valid, "cliff12_n resolves")
    TestHelper.assert_eq(res.submesh_id, "cliff09", "cliff12 aliases to cliff09 submesh")


func test_resolve_theater_override_replaces_glb():
    var art := TerrainArtData.new()
    art.id = "snowtest"
    art.model_path = "res://default.glb"
    art.theater_overrides = {"snow": "res://snow.glb"}
    var res := art.resolve("snowtest_n", "snow")
    TestHelper.assert_true(res.valid, "override resolves")
    TestHelper.assert_eq(res.glb_path, "res://snow.glb", "snow override replaces glb")
    TestHelper.assert_eq(res.submesh_id, "snowtest", "submesh still defaults to base id")
    TestHelper.assert_eq(res.rotation, 0.0, "n rotation 0 with override")
    var temperate := art.resolve("snowtest_n", "temperate")
    TestHelper.assert_eq(temperate.glb_path, "res://default.glb", "no override uses default model")


func test_resolve_invalid_without_model():
    var art := TerrainArtData.new()
    var res := art.resolve("anything_n", "temperate")
    TestHelper.assert_true(not res.valid, "empty model_path yields invalid (pink)")


func test_mesh_rotation_public_api():
    var art := _art("cliff01")
    TestHelper.assert_true(art != null, "cliff01 art loads for mesh_rotation")
    if art == null:
        _finish()
        return
    TestHelper.assert_eq(art.mesh_rotation("cliff01_e"), 270.0, "mesh_rotation e 270")
    TestHelper.assert_eq(art.mesh_rotation("cliff01"), 0.0, "mesh_rotation non-directional 0")


func _finish() -> void:
    pass
