extends Node

# MapLoader placement math — buildings anchor at footprint center so derived
# dock/foundation cells match the visual building (regression for pre-placed
# refinery dock offset).


func _make_building_data(foundation: Vector2i) -> EntityData:
    var data := EntityData.new()
    data.foundation = foundation
    data.entity_type = EntityData.EntityType.BUILDING
    return data


func test_building_placed_at_footprint_center():
    TerrainSystem.init_grid(50, 50)
    var data := _make_building_data(Vector2i(4, 3))
    var pos: Vector3 = MapLoader.placement_position(Vector2i(66, 58), data)
    var origin: Vector2i = CellUtil.world_to_cell_origin(pos, data.foundation)
    TerrainSystem.clear()
    (
        TestHelper
        . assert_true(
            origin == Vector2i(66, 58),
            (
                "building placed at footprint center, origin round-trips: origin=%s "
                + "(expected (66,58))" % origin
            ),
        )
    )


func test_building_dock_cell_alignment():
    TerrainSystem.init_grid(50, 50)
    var data := _make_building_data(Vector2i(4, 3))
    var pos: Vector3 = MapLoader.placement_position(Vector2i(66, 58), data)
    var origin: Vector2i = CellUtil.world_to_cell_origin(pos, data.foundation)
    # dock_position (6,0,2) = 3 cells x, 1 cell z from the origin.
    var dock_world := CellUtil.cell_to_world(origin) + Vector3(6.0, 0.0, 2.0)
    var dock_cell := CellUtil.world_to_cell(dock_world)
    var expected := origin + Vector2i(3, 1)
    TerrainSystem.clear()
    (
        TestHelper
        . assert_true(
            dock_cell == expected,
            (
                "dock cell lands at origin+(3,1), no offset: dock_cell=%s expected=%s"
                % [dock_cell, expected]
            ),
        )
    )


func test_unit_placed_at_cell_center():
    TerrainSystem.init_grid(50, 50)
    var data := EntityData.new()
    data.entity_type = EntityData.EntityType.VEHICLE
    var pos: Vector3 = MapLoader.placement_position(Vector2i(66, 58), data)
    var expected: Vector3 = CellUtil.cell_to_world(Vector2i(66, 58))
    TerrainSystem.clear()
    (
        TestHelper
        . assert_true(
            pos == expected,
            "non-building placed at cell center: pos=%s expected=%s" % [pos, expected],
        )
    )


func test_building_placement_without_data_defaults_cell_center():
    TerrainSystem.init_grid(50, 50)
    var pos: Vector3 = MapLoader.placement_position(Vector2i(66, 58), null)
    var expected: Vector3 = CellUtil.cell_to_world(Vector2i(66, 58))
    TerrainSystem.clear()
    (
        TestHelper
        . assert_true(
            pos == expected,
            "missing data falls back to cell center: pos=%s expected=%s" % [pos, expected],
        )
    )


func _write_map_json(path: String, include_starts: bool) -> void:
    var data: Dictionary = {
        "version": 4,
        "grid_cells": [50, 50],
        "map_size": [50, 50],
        "vertices": {},
        "cells": {},
    }
    if include_starts:
        data["start_locations"] = [{"player_id": 0, "cell": "28,34"}]
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
        file.close()


func _get_bounds() -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    return tree.root.get_node_or_null("BoundsSystem") if tree else null


func _common_camera_setup() -> Array:
    var bounds := _get_bounds()
    var pivot := Node3D.new()
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    tree.root.add_child(pivot)
    if bounds:
        bounds.camera_pivot = pivot
    pivot.global_position = Vector3(0.0, 7.0, 0.0)
    return [bounds, pivot]


func _teardown_camera(bounds: Node, pivot: Node3D) -> void:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if bounds:
        bounds.camera_pivot = null
    tree.root.remove_child(pivot)
    pivot.free()
    if bounds:
        bounds.grid_cells = Vector2i(50, 50)


func test_camera_frames_local_player_override():
    TerrainSystem.init_grid(50, 50)
    var setup: Array = _common_camera_setup()
    var bounds: Node = setup[0] as Node
    var pivot := setup[1] as Node3D
    if bounds == null:
        TestHelper.assert_true(false, "BoundsSystem autoload exists")
        return
    var tree: SceneTree = Engine.get_main_loop() as SceneTree

    var path := "user://test_map_loader_start.json"
    _write_map_json(path, true)
    var parent := Node3D.new()
    tree.root.add_child(parent)
    MapLoader.load_map_into(path, parent)

    var expected: Vector3 = CellUtil.cell_to_world(Vector2i(28, 34))
    (
        TestHelper
        . assert_true(
            (
                is_equal_approx(pivot.global_position.x, expected.x)
                and is_equal_approx(pivot.global_position.z, expected.z)
            ),
            (
                "camera framed on local player start override: pivot=%s expected=%s"
                % [pivot.global_position, expected]
            ),
        )
    )
    TestHelper.assert_eq(pivot.global_position.y, 7.0, "camera framing preserves pivot height")

    parent.free()
    _teardown_camera(bounds, pivot)
    TerrainSystem.clear()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_camera_untouched_without_start_locations():
    TerrainSystem.init_grid(50, 50)
    var setup: Array = _common_camera_setup()
    var bounds: Node = setup[0] as Node
    var pivot := setup[1] as Node3D
    if bounds == null:
        TestHelper.assert_true(false, "BoundsSystem autoload exists")
        return
    var tree: SceneTree = Engine.get_main_loop() as SceneTree

    var path := "user://test_map_loader_no_start.json"
    _write_map_json(path, false)
    var parent := Node3D.new()
    tree.root.add_child(parent)
    MapLoader.load_map_into(path, parent)

    (
        TestHelper
        . assert_true(
            is_zero_approx(pivot.global_position.x) and is_zero_approx(pivot.global_position.z),
            (
                "absent start_locations keeps existing centered behavior: pivot=%s"
                % pivot.global_position
            ),
        )
    )

    parent.free()
    _teardown_camera(bounds, pivot)
    TerrainSystem.clear()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
