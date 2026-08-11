extends Node

# Vehicle crush tests — SpatialHash crush query logic

var _sh: Node = null


func _make_infantry_entry(
    cell: Vector2i, player_id: int, crushable: bool, entity_type: int = 0
) -> Dictionary:
    var node := Node3D.new()
    node.name = "TestInfantry_%d_%d" % [cell.x, cell.y]
    add_child(node)
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.entity_type = entity_type
    stats.player_id = player_id
    stats.crushable = crushable
    node.add_child(stats)
    # Force rebuild grid entry
    var key: int = CellUtil.cell_key(cell)
    if not _sh._grid.has(key):
        _sh._grid[key] = []
    (
        _sh
        . _grid[key]
        . append(
            {
                "node": node,
                "mc": null,
                "entity_type": entity_type,
                "player_id": player_id,
            }
        )
    )
    if entity_type == 0:  # INFANTRY = 0
        _sh._shared_cell_counts[key] = _sh._shared_cell_counts.get(key, 0) + 1
    return {"node": node, "key": key}


func _cleanup_entries():
    for key in _sh._grid:
        for entry in _sh._grid[key]:
            var node: Node3D = entry["node"]
            if is_instance_valid(node):
                node.queue_free()
    _sh._grid.clear()
    _sh._shared_cell_counts.clear()


func test_crushable_enemies_returns_enemy_infantry():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _cleanup_entries()
    var cell := Vector2i(10, 10)
    var entry := _make_infantry_entry(cell, 1, true)  # player 1, crushable
    var result: Array = _sh.get_crushable_enemies_on_cell(cell, 0)  # query from player 0
    _cleanup_entries()
    (
        TestHelper
        . assert_true(
            result.size() == 1 and result[0] == entry["node"],
            (
                "get_crushable_enemies returns enemy crushable infantry: expected 1 enemy, got %d"
                % result.size()
            ),
        )
    )


func test_crushable_enemies_excludes_friendly():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _cleanup_entries()
    var cell := Vector2i(10, 10)
    _make_infantry_entry(cell, 0, true)  # player 0 (same as query), crushable
    var result: Array = _sh.get_crushable_enemies_on_cell(cell, 0)
    _cleanup_entries()
    (
        TestHelper
        . assert_true(
            result.size() == 0,
            "get_crushable_enemies excludes friendly infantry: expected 0, got %d" % result.size(),
        )
    )


func test_crushable_enemies_excludes_non_crushable():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _cleanup_entries()
    var cell := Vector2i(10, 10)
    _make_infantry_entry(cell, 1, false)  # player 1, NOT crushable
    var result: Array = _sh.get_crushable_enemies_on_cell(cell, 0)
    _cleanup_entries()
    (
        TestHelper
        . assert_true(
            result.size() == 0,
            (
                "get_crushable_enemies excludes non-crushable infantry: expected 0, got %d"
                % result.size()
            ),
        )
    )


func test_crushable_enemies_excludes_vehicles():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _cleanup_entries()
    var cell := Vector2i(10, 10)
    _make_infantry_entry(cell, 1, true, 1)  # player 1, crushable, VEHICLE type
    var result: Array = _sh.get_crushable_enemies_on_cell(cell, 0)
    _cleanup_entries()
    (
        TestHelper
        . assert_true(
            result.size() == 0,
            (
                "get_crushable_enemies excludes non-infantry entities: expected 0, got %d"
                % result.size()
            ),
        )
    )


func test_crusher_blocking_includes_friendly():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _cleanup_entries()
    var cell := Vector2i(10, 10)
    _make_infantry_entry(cell, 0, true)  # player 0 (same as query), crushable
    var result: Dictionary = _sh.get_crusher_blocking_cells(0)
    _cleanup_entries()
    var key: int = CellUtil.cell_key(cell)
    (
        TestHelper
        . assert_true(
            result.has(key),
            "get_crusher_blocking_cells includes friendly infantry: expected cell in blocking dict",
        )
    )


func test_crusher_blocking_includes_non_crushable():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _cleanup_entries()
    var cell := Vector2i(10, 10)
    _make_infantry_entry(cell, 1, false)  # player 1 (enemy), NOT crushable
    var result: Dictionary = _sh.get_crusher_blocking_cells(0)
    _cleanup_entries()
    var key: int = CellUtil.cell_key(cell)
    (
        TestHelper
        . assert_true(
            result.has(key),
            (
                "get_crusher_blocking_cells includes non-crushable enemy: "
                + "expected cell in blocking dict"
            ),
        )
    )


func test_crusher_blocking_excludes_crushable_enemy():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _cleanup_entries()
    var cell := Vector2i(10, 10)
    _make_infantry_entry(cell, 1, true)  # player 1 (enemy), crushable
    var result: Dictionary = _sh.get_crusher_blocking_cells(0)
    _cleanup_entries()
    var key: int = CellUtil.cell_key(cell)
    (
        TestHelper
        . assert_true(
            not result.has(key),
            (
                "get_crusher_blocking_cells excludes crushable enemy: "
                + "expected cell NOT in blocking dict"
            ),
        )
    )


func test_empty_cell_returns_no_crushables():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _cleanup_entries()
    var cell := Vector2i(99, 99)
    var result: Array = _sh.get_crushable_enemies_on_cell(cell, 0)
    _cleanup_entries()
    TestHelper.assert_true(
        result.size() == 0, "empty cell returns no crushables: expected 0, got %d" % result.size()
    )


## A crusher with an unresolved player id (-1) must not crush anyone — a stale
## _player_id (e.g. DeployComponent setting player_id after add_child) previously
## made is_enemy(-1, friendly) true, killing friendlies.
func test_unknown_query_player_crushes_nothing():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _cleanup_entries()
    var cell := Vector2i(10, 10)
    _make_infantry_entry(cell, 0, true)  # friendly crushable infantry
    var result: Array = _sh.get_crushable_enemies_on_cell(cell, -1)
    _cleanup_entries()
    (
        TestHelper
        . assert_true(
            result.size() == 0,
            (
                "get_crushable_enemies with player_id -1 crushes nothing: "
                + "expected 0, got %d" % result.size()
            ),
        )
    )


## An unknown-id crusher must path around infantry cells rather than drive over
## friendlies (get_crusher_blocking_cells treats them as blocking).
func test_unknown_query_player_blocks_friendly_cell():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _cleanup_entries()
    var cell := Vector2i(10, 10)
    _make_infantry_entry(cell, 0, true)  # friendly crushable infantry
    var result: Dictionary = _sh.get_crusher_blocking_cells(-1)
    _cleanup_entries()
    var key: int = CellUtil.cell_key(cell)
    (
        TestHelper
        . assert_true(
            result.has(key),
            "get_crusher_blocking_cells with player_id -1 treats infantry " + "cell as blocking",
        )
    )
