extends Node

# Map-editor slope classification must resolve through the catalog so the
# editor renders the exact same tile + rotation as the asset preview. The cell
# data carries the catalog object id; the renderer/collision resolve art via it.


func _ts() -> Node:
    return Engine.get_main_loop().root.get_node("TerrainSystem")


func _normalized(corners: Array) -> Array:
    var lo := 1 << 30
    for c in corners:
        lo = mini(lo, int(c))
    var out: Array = []
    for c in corners:
        out.append(int(c) - lo)
    return out


func test_slope_object_id_known_mappings():
    var cases := {
        "north_edge": {"h": [1, 1, 0, 0], "id": "slope01_w"},
        "east_edge": {"h": [0, 1, 0, 1], "id": "slope01_n"},
        "south_edge": {"h": [0, 0, 1, 1], "id": "slope01_e"},
        "west_edge": {"h": [1, 0, 1, 0], "id": "slope01_s"},
        "se_corner": {"h": [0, 0, 0, 1], "id": "slope05_n"},
        "sw_corner": {"h": [0, 0, 1, 0], "id": "slope05_e"},
        "nw_corner": {"h": [1, 0, 0, 0], "id": "slope05_s"},
        "ne_corner": {"h": [0, 1, 0, 0], "id": "slope05_w"},
        "tri_low_nw": {"h": [0, 1, 1, 1], "id": "slope09_n"},
        "tri_low_ne": {"h": [1, 0, 1, 1], "id": "slope09_e"},
        "tri_low_sw": {"h": [1, 1, 0, 1], "id": "slope09_w"},
        "tri_low_se": {"h": [1, 1, 1, 0], "id": "slope09_s"},
        "saddle_ne_sw": {"h": [0, 1, 1, 0], "id": "slope17_n"},
        "saddle_nw_se": {"h": [1, 0, 0, 1], "id": "slope_saddle2_n"},
    }
    for label in cases:
        var c: Dictionary = cases[label]
        TestHelper.assert_eq(
            TerrainSystem.slope_object_id(c["h"]), c["id"], "slope id for " + label
        )
    _finish()


func test_all_catalog_slope_shapes_resolve_to_matching_pattern():
    var all: Dictionary = TerrainCatalog.get_all_objects()
    for id in all:
        var id_str := String(id)
        var base := id_str.substr(0, id_str.rfind("_"))
        if not TerrainSystem.SLOPE_FAMILIES.has(base):
            continue
        var obj: TerrainObject = TerrainCatalog.get_object(id_str)
        var cat: Array = obj.corners_at("0,0")
        var map_h := [cat[0], cat[1], cat[3], cat[2]]
        var resolved := TerrainSystem.slope_object_id(map_h)
        TestHelper.assert_true(resolved != "", "slope shape resolves: " + id_str)
        if resolved != "":
            var r_obj: TerrainObject = TerrainCatalog.get_object(resolved)
            (
                TestHelper
                . assert_eq(
                    _normalized(r_obj.corners_at("0,0")),
                    _normalized(cat),
                    "resolved tile matches pattern: " + id_str,
                )
            )
    _finish()


func test_compute_cell_slope_carries_catalog_object():
    var ts := _ts()
    ts.init_grid(4, 4)
    # North edge of cell (1,1) raised: corners [1, 1, 0, 0].
    ts.set_vertex(1, 1, 1)
    ts.set_vertex(2, 1, 1)
    ts.set_vertex(1, 2, 0)
    ts.set_vertex(2, 2, 0)
    var data: Dictionary = ts._compute_cell_from_vertices(Vector2i(1, 1))
    TestHelper.assert_eq(data.get("type"), "slope", "classified as slope")
    TestHelper.assert_eq(data.get("object_id"), "slope01_w", "north edge resolves to slope01_w")
    var expected_rot := TerrainCatalog.resolve_art("slope01_w", "").rotation
    (
        TestHelper
        . assert_true(
            absf(float(data.get("rotation", -1.0)) - expected_rot) < 0.01,
            "cell rotation matches the catalog: " + str(data.get("rotation", -1.0)),
        )
    )
    _finish()


func test_renderer_resolves_catalog_slope_submesh():
    var renderer := Node.new()
    renderer.set_script(load("res://scripts/core/TerrainRenderer.gd"))
    Engine.get_main_loop().root.add_child(renderer)
    renderer.clear_all()
    var cell := Vector2i(1, 1)
    (
        renderer
        . render_cell(
            cell,
            {
                "type": "slope",
                "variant": 1,
                "rotation": 90.0,
                "height": 0,
                "object_id": "slope01_w",
            },
        )
    )
    var key := CellUtil.cell_key_str(cell)
    var entry: Dictionary = renderer._instance_data.get(key, {})
    TestHelper.assert_true(entry.has("mesh_name"), "slope instance recorded")
    if entry.has("mesh_name"):
        TestHelper.assert_eq(
            String(entry["mesh_name"]), "slope_edge", "north-edge slope uses the slope_edge submesh"
        )
    Engine.get_main_loop().root.remove_child(renderer)
    renderer.queue_free()
    _finish()


func _finish() -> void:
    pass
