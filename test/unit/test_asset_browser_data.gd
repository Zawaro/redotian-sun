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


func _write_tres(path: String, cls: String, id: String) -> void:
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string(
        (
            (
                '[gd_resource type="Resource" script_class="%s" load_steps=1 format=3]\n\n'
                + '[resource]\nid = "%s"\n'
            )
            % [cls, id]
        )
    )
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
