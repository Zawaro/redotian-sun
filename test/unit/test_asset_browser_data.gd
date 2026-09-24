extends Node

# Asset browser data contracts: the category registry resolves at least one
# asset per in-scope category, the lazy header reader classifies resources, and
# asset scanning honors data-set root ordering (later roots win).

const CONTROLLER_PATH: String = "res://scripts/editor/AssetBrowserController.gd"
const LAYER_FIXTURE: String = "user://ab_test_layering"

var _ctrl: Node3D = null


func _make_controller() -> Node3D:
    if _ctrl == null:
        var script: GDScript = load(CONTROLLER_PATH)
        _ctrl = script.new() as Node3D
    return _ctrl


func _registry() -> Array:
    var script: GDScript = load(CONTROLLER_PATH)
    return script.get_script_constant_map()["CATEGORIES"]


func _write_tres(path: String, cls: String, id: String, etype: int = -1) -> void:
    var header := '[gd_resource type="Resource" script_class="%s" load_steps=1 format=3]\n' % cls
    var body := header + '\n[resource]\nid = "%s"\n' % id
    if etype >= 0:
        body += "entity_type = %d\n" % etype
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string(body)
    f.close()


func _rmrf(path: String) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if not dir.current_is_dir():
            DirAccess.remove_absolute(path.path_join(name))
        name = dir.get_next()
    dir.list_dir_end()
    DirAccess.remove_absolute(path)


# --- Registry coverage -------------------------------------------------------


func test_registry_resolves_an_asset_per_sourced_category():
    var ctrl := _make_controller()
    var checked := 0
    for row in _registry():
        var cat: Dictionary = row
        if not ctrl._category_has_source(cat):
            continue
        checked += 1
        var assets: Array = ctrl._scan_category(cat)
        TestHelper.assert_true(
            assets.size() > 0, "category '%s' resolves at least one asset" % cat["label"]
        )
    TestHelper.assert_true(checked >= 10, "registry exposes the in-scope categories (%d)" % checked)


func test_in_scope_categories_present():
    var labels: Array[String] = []
    for row in _registry():
        labels.append(String(row["label"]))
    for expected in [
        "Terrain Objects",
        "Buildings",
        "Infantry",
        "Vehicles",
        "Aircraft",
        "Terrain Props",
        "Overlays",
        "Smudges",
        "Art Entries",
        "Terrain Art",
        "SFX",
        "Voices",
        "Cameos / UI",
    ]:
        TestHelper.assert_true(labels.has(expected), "registry contains '%s'" % expected)


# --- Header reader / path helpers -------------------------------------------


func test_tres_header_reads_class_and_id():
    var ctrl := _make_controller()
    var path := "res://games/ts/terrain_objects/cliff01_n.tres"
    TestHelper.assert_eq(ctrl._tres_class(path), "TerrainObject", "reads script_class from header")
    TestHelper.assert_eq(ctrl._tres_id(path), "cliff01_n", "reads id from header")


func test_tres_id_falls_back_to_filename():
    var ctrl := _make_controller()
    var path := "res://games/ts/theaters/temperate.tres"
    TestHelper.assert_eq(ctrl._tres_id(path), "temperate", "id from file when header id absent")


func test_join_normalizes_slashes():
    var ctrl := _make_controller()
    TestHelper.assert_eq(
        ctrl._join("res://games/ts/", "/entities/"), "res://games/ts/entities/", "joins cleanly"
    )


# --- Layering ----------------------------------------------------------------


func test_scanner_later_root_wins():
    var ctrl := _make_controller()
    _rmrf(LAYER_FIXTURE)
    DirAccess.make_dir_recursive_absolute(LAYER_FIXTURE + "/a")
    DirAccess.make_dir_recursive_absolute(LAYER_FIXTURE + "/b")
    _write_tres(LAYER_FIXTURE + "/a/dup.tres", "Thing", "dup")
    _write_tres(LAYER_FIXTURE + "/b/dup.tres", "Thing", "dup")
    var found: Dictionary = {}
    ctrl._scan_tres(LAYER_FIXTURE + "/a/", "Thing", found)
    ctrl._scan_tres(LAYER_FIXTURE + "/b/", "Thing", found)
    TestHelper.assert_eq(
        String(found["dup"]["path"]), LAYER_FIXTURE + "/b/dup.tres", "later root overrides"
    )
    _rmrf(LAYER_FIXTURE)


func test_scanner_class_filter_excludes_other_classes():
    var ctrl := _make_controller()
    _rmrf(LAYER_FIXTURE)
    DirAccess.make_dir_recursive_absolute(LAYER_FIXTURE + "/a")
    _write_tres(LAYER_FIXTURE + "/a/keep.tres", "Thing", "keep")
    _write_tres(LAYER_FIXTURE + "/a/drop.tres", "Other", "drop")
    var found: Dictionary = {}
    ctrl._scan_tres(LAYER_FIXTURE + "/a/", "Thing", found)
    TestHelper.assert_true(found.has("keep"), "matching class included")
    TestHelper.assert_true(not found.has("drop"), "non-matching class excluded")
    _rmrf(LAYER_FIXTURE)


func test_scanner_etype_filter_matches_entity_type():
    var ctrl := _make_controller()
    _rmrf(LAYER_FIXTURE)
    DirAccess.make_dir_recursive_absolute(LAYER_FIXTURE + "/a")
    _write_tres(LAYER_FIXTURE + "/a/veh.tres", "EntityData", "veh", EntityData.EntityType.VEHICLE)
    _write_tres(LAYER_FIXTURE + "/a/inf.tres", "EntityData", "inf", EntityData.EntityType.INFANTRY)
    var found: Dictionary = {}
    ctrl._scan_tres(LAYER_FIXTURE + "/a/", "EntityData", found, EntityData.EntityType.VEHICLE)
    TestHelper.assert_true(found.has("veh"), "matching entity_type included")
    TestHelper.assert_true(not found.has("inf"), "non-matching entity_type excluded")
    _rmrf(LAYER_FIXTURE)


func test_scanner_accepts_tres_remap_names():
    var ctrl := _make_controller()
    _rmrf(LAYER_FIXTURE)
    DirAccess.make_dir_recursive_absolute(LAYER_FIXTURE + "/a")
    _write_tres(LAYER_FIXTURE + "/a/thing.tres.remap", "Thing", "thing")
    var found: Dictionary = {}
    ctrl._scan_tres(LAYER_FIXTURE + "/a/", "Thing", found)
    TestHelper.assert_true(found.has("thing"), "remap-suffixed file is listed")
    (
        TestHelper
        . assert_eq(
            String(found["thing"]["path"]),
            LAYER_FIXTURE + "/a/thing.tres",
            "stored load path strips .remap",
        )
    )
    _rmrf(LAYER_FIXTURE)


func test_tres_entity_type_reads_header():
    var ctrl := _make_controller()
    var path := "res://games/ts/entities/structures/gdi/gdi_power_plant.tres"
    (
        TestHelper
        . assert_eq(
            ctrl._tres_entity_type(path),
            EntityData.EntityType.BUILDING,
            "building entity_type from header",
        )
    )
    var no_type := "res://games/ts/terrain_objects/cliff01_n.tres"
    TestHelper.assert_eq(ctrl._tres_entity_type(no_type), -1, "absent entity_type is -1")


func test_terrain_footprint_bounds_known_real_tile():
    var cliff := load("res://games/ts/terrain_objects/cliff01_n.tres") as TerrainObject
    TestHelper.assert_true(cliff != null, "cliff01_n loads")
    if cliff == null:
        return
    var b := TerrainObject.footprint_bounds(cliff)
    TestHelper.assert_eq(b.position, Vector3(0, 0, 0), "cliff01_n min cell/min height at origin")
    TestHelper.assert_eq(b.size, Vector3(2, 4, 3), "cliff01_n spans 2x4x3 lattice units")
    var ramp := load("res://games/ts/terrain_objects/ramp01_n.tres") as TerrainObject
    TestHelper.assert_true(ramp != null, "ramp01_n loads")
    if ramp == null:
        return
    var rb := TerrainObject.footprint_bounds(ramp)
    TestHelper.assert_eq(rb.position.y, 0, "ramp01_n min height 0")
    TestHelper.assert_true(rb.size.y > 0, "ramp01_n has a height span")
    TestHelper.assert_true(
        rb.size.x >= 3 and rb.size.z >= 3, "ramp01_n footprint spans multiple cells"
    )


func test_all_theater_variants_resolve_to_glb_submeshes():
    var resolution := TerrainCatalog.resolve_art(
        "cliff01_n", TerrainCatalog.get_active_theater_id()
    )
    TestHelper.assert_true(
        resolution.valid and not resolution.glb_path.is_empty(), "cliff01 resolves"
    )
    if not resolution.valid or resolution.glb_path.is_empty():
        return
    var scene := load(resolution.glb_path) as PackedScene
    TestHelper.assert_true(scene != null, "GLB loads")
    if scene == null:
        return
    var instance := scene.instantiate()
    var names: Array[String] = []
    _collect_glb_names(instance, names)
    instance.free()
    TestHelper.assert_true(not names.is_empty(), "GLB has submesh node names")
    var missing: Array[String] = []
    for object_id in TerrainCatalog.get_all_objects():
        var res := TerrainCatalog.resolve_art(String(object_id), "temperate")
        if res.valid and not names.has(res.submesh_id):
            missing.append("%s -> %s" % [object_id, res.submesh_id])
    TestHelper.assert_eq(
        missing.size(), 0, "every catalog variant resolves to an existing GLB submesh"
    )
    for entry in missing:
        print("    missing: " + entry)


func _collect_glb_names(node: Node, names: Array[String]) -> void:
    if node is MeshInstance3D:
        names.append(String((node as MeshInstance3D).name).trim_suffix("_3D"))
    for child in node.get_children():
        _collect_glb_names(child, names)


# --- Terrain footprint / overlay geometry ------------------------------------


func test_terrain_footprint_bounds_span_and_height():
    var obj := TerrainObject.new()
    obj.cells = {
        "0,0": {"corners": [0, 1, 1, 0]},
        "1,0": {"corners": [1, 3, 3, 1]},
        "0,1": {"corners": [0, 2, 2, 0]},
        "1,1": {"corners": [2, 4, 4, 2]},
    }
    var bounds := TerrainObject.footprint_bounds(obj)
    TestHelper.assert_eq(bounds.position, Vector3(0.0, 0.0, 0.0), "min cell at origin")
    TestHelper.assert_eq(bounds.size, Vector3(2.0, 4.0, 2.0), "spans 2x2 cells, heights 0..4")


func test_cell_corner_local_orders_corners_clockwise():
    var ctrl := _make_controller()
    var cs := CellUtil.CELL_SIZE
    (
        TestHelper
        . assert_eq(
            ctrl._cell_corner_local(1, 2, 0, 0.0),
            Vector3(float(cs), 0.0, 2.0 * float(cs)),
            "corner 0 is the north-west cell corner",
        )
    )
    (
        TestHelper
        . assert_eq(
            ctrl._cell_corner_local(1, 2, 2, 0.0),
            Vector3(2.0 * float(cs), 0.0, 3.0 * float(cs)),
            "corner 2 is the south-east cell corner",
        )
    )
    (
        TestHelper
        . assert_eq(
            ctrl._cell_corner_local(0, 0, 0, 1.5),
            Vector3(0.0, 1.5, 0.0),
            "height is applied on the Y axis",
        )
    )
