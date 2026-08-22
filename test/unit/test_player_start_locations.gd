extends Node

# Player start cluster default and camera framing tests.

const PLAYER_START_TOOL: GDScript = preload("res://scripts/editor/PlayerStartTool.gd")

var _ts: Node = null


func _bounds() -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    return tree.root.get_node_or_null("BoundsSystem") if tree else null


func _assert_true(value: bool, message: String) -> void:
    TestHelper.assert_true(value, message)


func _assert_eq(got: Variant, expected: Variant, message: String) -> void:
    TestHelper.assert_eq(got, expected, message)


func test_default_start_in_diamond_even_odd_asymmetric() -> void:
    var bounds := _bounds()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    var grid_sizes: Array[Vector2i] = [
        Vector2i(50, 50),
        Vector2i(51, 51),
        Vector2i(51, 50),
        Vector2i(50, 51),
        Vector2i(30, 40),
        Vector2i(40, 30),
        Vector2i(21, 33),
    ]
    for grid_cells in grid_sizes:
        bounds.grid_cells = grid_cells
        for player_id in range(8):
            var cell: Vector2i = bounds.default_start_cell(player_id)
            _assert_true(
                CellUtil.is_in_diamond(cell, grid_cells),
                "start inside diamond: %s p%d %s" % [grid_cells, player_id, cell],
            )


func test_cluster_offsets_distinct_per_player() -> void:
    var bounds := _bounds()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    bounds.grid_cells = Vector2i(50, 50)
    var seen: Dictionary = {}
    for player_id in range(8):
        var cell: Vector2i = bounds.default_start_cell(player_id)
        _assert_true(not seen.has(cell), "player %d start %s not already taken" % [player_id, cell])
        seen[cell] = true


func test_reset_returns_to_default_cluster() -> void:
    var bounds := _bounds()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    var saved_grid: Vector2i = bounds.grid_cells
    bounds.grid_cells = Vector2i(50, 50)
    var tool: Node = PLAYER_START_TOOL.new()
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    tree.root.add_child(tool)
    var player_id: int = 3
    var alternative: Vector2i = bounds.default_start_cell(player_id) + Vector2i(7, -3)
    tool.assign(player_id, alternative)
    tool.reset(player_id)
    var effective: Vector2i = tool.effective_cell(player_id)
    tree.root.remove_child(tool)
    tool.free()
    bounds.grid_cells = saved_grid
    _assert_eq(
        effective, bounds.default_start_cell(player_id), "reset returns to default cluster cell"
    )


func test_center_camera_on_cell_preserves_height() -> void:
    var bounds := _bounds()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    var saved_grid: Vector2i = bounds.grid_cells
    var pivot := Node3D.new()
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    tree.root.add_child(pivot)
    bounds.camera_pivot = pivot
    pivot.global_position = Vector3(100.0, 42.0, -100.0)
    bounds.grid_cells = Vector2i(50, 50)
    var cell := Vector2i(28, 34)
    bounds.center_camera_on_cell(cell)
    var world: Vector3 = CellUtil.cell_to_world(cell)
    _assert_true(
        (
            is_equal_approx(pivot.global_position.x, world.x)
            and is_equal_approx(pivot.global_position.z, world.z)
        ),
        "center_camera_on_cell sets x/z to cell world position",
    )
    _assert_eq(pivot.global_position.y, 42.0, "center_camera_on_cell preserves pivot height")
    bounds.grid_cells = saved_grid
    bounds.camera_pivot = null
    tree.root.remove_child(pivot)
    pivot.free()


func test_camera_pivot_resolves_from_scene_hierarchy() -> void:
    var bounds := _bounds()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    var saved_grid: Vector2i = bounds.grid_cells

    var map_root := Node3D.new()
    map_root.name = "TestMapRoot"
    tree.root.add_child(map_root)
    var pivot := Node3D.new()
    pivot.name = "Camera"
    map_root.add_child(pivot)
    var cam: Camera3D = Camera3D.new()
    cam.name = "Camera3D"
    pivot.add_child(cam)

    TerrainSystem.init_grid(50, 50)
    bounds.camera_pivot = null
    var path := "user://test_start_resolve.json"
    var data: Dictionary = {
        "version": 4,
        "grid_cells": [50, 50],
        "map_size": [50, 50],
        "vertices": {},
        "cells": {},
        "start_locations": [{"player_id": 0, "cell": "28,34"}],
    }
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
        file.close()

    MapLoader.load_map_into(path, map_root)

    _assert_true(bounds.camera_pivot != null, "load_map_into resolves camera pivot")
    if bounds.camera_pivot == null:
        TerrainSystem.clear()
        return
    var expected: Vector3 = CellUtil.cell_to_world(Vector2i(28, 34))
    _assert_true(
        (
            is_equal_approx(bounds.camera_pivot.global_position.x, expected.x)
            and is_equal_approx(bounds.camera_pivot.global_position.z, expected.z)
        ),
        (
            "start-location framing reaches the resolved pivot: got=%s expected=%s"
            % [bounds.camera_pivot.global_position, expected]
        ),
    )

    map_root.free()
    bounds.camera_pivot = null
    bounds.grid_cells = saved_grid
    TerrainSystem.clear()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _make_tool() -> Node:
    var tool: Node = PLAYER_START_TOOL.new()
    tool.set_player_count(2)
    return tool


func test_save_writes_only_overrides() -> void:
    var bounds := _bounds()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    var saved_grid: Vector2i = bounds.grid_cells
    bounds.grid_cells = Vector2i(50, 50)
    var tool: Node = _make_tool()
    var default_p0: Vector2i = bounds.default_start_cell(0)
    var tool_root := Node3D.new()
    var tree_root: SceneTree = Engine.get_main_loop() as SceneTree
    tree_root.root.add_child(tool_root)
    tool.setup(tool_root)
    tool.assign(1, default_p0 + Vector2i(7, -3))
    var entries: Array = tool.save_data()
    tree_root.root.remove_child(tool_root)
    tool_root.free()
    bounds.grid_cells = saved_grid
    _assert_eq(entries.size(), 1, "only one true override serialized")
    if entries.size() == 1:
        var entry: Dictionary = entries[0]
        _assert_eq(int(entry.get("player_id", -999)), 1, "override entry is for player 1")
        _assert_eq(String(entry.get("cell", "")), "57,47", "override cell serialized as x,y string")


func test_load_data_applies_overrides_and_uses_defaults_for_rest() -> void:
    var bounds := _bounds()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    var saved_grid: Vector2i = bounds.grid_cells
    bounds.grid_cells = Vector2i(50, 50)
    var tool: Node = _make_tool()
    tool.load_data([{"player_id": 2, "cell": "41,37"}])
    _assert_eq(tool.effective_cell(2), Vector2i(41, 37), "override applied from loaded data")
    _assert_eq(tool.effective_cell(0), bounds.default_start_cell(0), "unlisted player uses default")
    bounds.grid_cells = saved_grid


func test_load_data_absent_key_clears_overrides() -> void:
    var bounds := _bounds()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    var saved_grid: Vector2i = bounds.grid_cells
    bounds.grid_cells = Vector2i(50, 50)
    var tool: Node = _make_tool()
    tool.assign(0, Vector2i(10, 10))
    tool.load_data([])
    _assert_eq(tool.effective_cell(0), bounds.default_start_cell(0), "empty data clears override")
    bounds.grid_cells = saved_grid


func test_round_trip_preserves_override() -> void:
    var bounds := _bounds()
    if bounds == null:
        _assert_true(false, "BoundsSystem autoload exists")
        return
    var saved_grid: Vector2i = bounds.grid_cells
    bounds.grid_cells = Vector2i(50, 50)
    var tool: Node = _make_tool()
    var default_p0: Vector2i = bounds.default_start_cell(0)
    tool.assign(0, default_p0 + Vector2i(3, 5))
    var entries: Array = tool.save_data()
    var tool2: Node = _make_tool()
    tool2.load_data(entries)
    _assert_eq(
        tool2.effective_cell(0), default_p0 + Vector2i(3, 5), "round-trip preserves override"
    )
    bounds.grid_cells = saved_grid
