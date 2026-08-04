extends Node

# TerrainCatalog autoload: directory-scanned registries for TerrainObjects,
# per-element TerrainArtData, and light TheaterData; active theater selection;
# resolve_art delegation with pink (invalid) fallback.


func test_objects_scanned_and_cached():
    var obj := TerrainCatalog.get_object("cliff01_n")
    TestHelper.assert_true(obj != null, "cliff01_n scanned")
    if obj != null:
        TestHelper.assert_eq(obj.cell_type, "cliff", "cliff01_n cell_type")
    TestHelper.assert_eq(TerrainCatalog.get_object("not_a_tile"), null, "unknown object null")
    var all: Dictionary = TerrainCatalog.get_all_objects()
    TestHelper.assert_true(all.size() >= 144, "full 4-direction catalog registered")


func test_art_scanned_and_cached():
    var art := TerrainCatalog.get_art("cliff01")
    TestHelper.assert_true(art != null, "cliff01 art scanned")
    if art != null:
        TestHelper.assert_eq(art.submesh_id, "", "cliff01 art uses default submesh (base id)")
    TestHelper.assert_eq(TerrainCatalog.get_art("not_art"), null, "unknown art null")
    var art12 := TerrainCatalog.get_art("cliff12")
    if art12 != null:
        TestHelper.assert_eq(art12.submesh_id, "cliff09", "cliff12 art aliases to cliff09")


func test_theaters_scanned_and_cached():
    var theater := TerrainCatalog.get_theater("temperate")
    TestHelper.assert_true(theater != null, "temperate theater scanned")
    if theater != null:
        TestHelper.assert_eq(theater.id, "temperate", "theater id")
    TestHelper.assert_eq(TerrainCatalog.get_theater("not_a_theater"), null, "unknown theater null")


func test_active_theater_defaults_to_first_registered():
    TerrainCatalog.set_active_theater("")
    var theater := TerrainCatalog.get_active_theater()
    TestHelper.assert_true(theater != null, "active theater defaults to a registered theater")
    if theater != null:
        TestHelper.assert_eq(theater.id, "temperate", "only registered theater is selected")


func test_set_active_theater_selects_registered():
    TerrainCatalog.set_active_theater("temperate")
    TestHelper.assert_eq(TerrainCatalog.get_active_theater_id(), "temperate", "selects temperate")


func test_unknown_theater_falls_back():
    TerrainCatalog.set_active_theater("not_a_theater")
    TestHelper.assert_eq(
        TerrainCatalog.get_active_theater_id(), "temperate", "unknown falls back to first"
    )


func test_resolve_art_object_reference():
    var res := TerrainCatalog.resolve_art("cliff01_e", "temperate")
    TestHelper.assert_true(res.valid, "cliff01_e resolves via object art_data")
    if res.valid:
        TestHelper.assert_eq(res.submesh_id, "cliff01", "shared art submesh")
        TestHelper.assert_eq(res.rotation, 270.0, "e rotation from object suffix")
    var res12 := TerrainCatalog.resolve_art("cliff12_n", "temperate")
    TestHelper.assert_true(res12.valid, "cliff12_n resolves")
    if res12.valid:
        TestHelper.assert_eq(res12.submesh_id, "cliff09", "alias object resolves to cliff09")


func test_resolve_art_by_family_id():
    var res := TerrainCatalog.resolve_art("slope02", "temperate")
    TestHelper.assert_true(res.valid, "runtime slope family resolves")
    if res.valid:
        TestHelper.assert_eq(res.submesh_id, "slope_corner", "slope02 maps to slope_corner")
    var clear := TerrainCatalog.resolve_art("clear01", "temperate")
    TestHelper.assert_true(clear.valid, "clear01 resolves")
    if clear.valid:
        TestHelper.assert_eq(clear.submesh_id, "clear01", "clear01 submesh")


func test_resolve_art_missing_is_invalid():
    var res := TerrainCatalog.resolve_art("not_a_tile", "temperate")
    TestHelper.assert_true(not res.valid, "unknown id yields invalid resolution (pink)")


func test_resolve_cell_art_uses_object_id():
    var data := {"type": "slope", "variant": 1, "object_id": "slope01_w"}
    var res: TerrainArtData.ArtResolution = TerrainCatalog.resolve_cell_art(data)
    TestHelper.assert_true(res.valid, "cell with object_id resolves via catalog")
    if res.valid:
        TestHelper.assert_eq(res.submesh_id, "slope_edge", "object_id drives submesh")
        TestHelper.assert_eq(res.rotation, 90.0, "w suffix rotation")


func test_resolve_cell_art_legacy_family_fallback():
    var data := {"type": "clear", "variant": 1}
    var res: TerrainArtData.ArtResolution = TerrainCatalog.resolve_cell_art(data)
    TestHelper.assert_true(res.valid, "legacy clear01 cell resolves via family fallback")
    if res.valid:
        TestHelper.assert_eq(res.submesh_id, "clear01", "type/variant fallback submesh")


func test_resolve_cell_art_missing_is_invalid():
    var data := {"type": "cliff", "variant": 99}
    var res: TerrainArtData.ArtResolution = TerrainCatalog.resolve_cell_art(data)
    TestHelper.assert_true(not res.valid, "unknown family yields invalid resolution (pink)")


func test_theater_override_through_catalog():
    var injected := TerrainArtData.new()
    injected.id = "cliff01_snowtest"
    injected.model_path = "res://default.glb"
    injected.theater_overrides = {"snow": "res://snow.glb"}
    TerrainCatalog.register_art(injected)
    var snow := TerrainCatalog.resolve_art("cliff01_snowtest", "snow")
    TestHelper.assert_true(snow.valid, "override resolves")
    if snow.valid:
        TestHelper.assert_eq(snow.glb_path, "res://snow.glb", "snow override glb")
    var temperate := TerrainCatalog.resolve_art("cliff01_snowtest", "temperate")
    TestHelper.assert_eq(temperate.glb_path, "res://default.glb", "no override uses default")


func _finish() -> void:
    pass
