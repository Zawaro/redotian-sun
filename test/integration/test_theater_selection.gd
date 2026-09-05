extends Node

# Theater selection flow: the map JSON is the authority — MapLoader ingests
# theater_id into TerrainCatalog, and the active theater drives art resolution
# (override-or-default).

const PLACEHOLDER_GLB: String = (
    "res://games/ts/assets/models/theater/placeholder/" + "placeholder_terrain01.gltf"
)


func test_map_loader_sets_active_theater_from_map():
    TerrainCatalog.set_active_theater("")
    MapLoader.load_map_into("res://test/fixtures/map_theater_test.json", self)
    TestHelper.assert_eq(
        TerrainCatalog.get_active_theater_id(), "temperate", "map theater_id applied on load"
    )
    _finish()


func test_active_theater_drives_default_resolution():
    TerrainCatalog.set_active_theater("temperate")
    var theater_id := TerrainCatalog.get_active_theater_id()
    var res := TerrainCatalog.resolve_art("clear01", theater_id)
    TestHelper.assert_true(res.valid, "clear01 resolves under the active theater")
    if res.valid:
        TestHelper.assert_eq(res.glb_path, PLACEHOLDER_GLB, "temperate uses the default model")
        TestHelper.assert_eq(res.submesh_id, "clear01", "temperate keeps the base submesh")
    _finish()


func test_snow_override_swaps_glb_vs_temperate_default():
    var injected := TerrainArtData.new()
    injected.id = "cliff01_snowtest"
    injected.model_path = PLACEHOLDER_GLB
    injected.theater_overrides = {"snow": "res://theaters/snow/terrain.glb"}
    TerrainCatalog.register_art(injected)
    var snow := TerrainCatalog.resolve_art("cliff01_snowtest", "snow")
    TestHelper.assert_eq(snow.glb_path, "res://theaters/snow/terrain.glb", "snow overrides glb")
    TestHelper.assert_eq(snow.submesh_id, "cliff01_snowtest", "snow keeps the base submesh")
    var temperate := TerrainCatalog.resolve_art("cliff01_snowtest", "temperate")
    TestHelper.assert_eq(temperate.glb_path, PLACEHOLDER_GLB, "temperate keeps the default glb")
    _finish()


func _finish() -> void:
    pass
