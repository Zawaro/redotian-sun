extends Node

# SpatialHash tests — cell reservation logic

var _sh: Node = null
var _test_passed := 0
var _test_failed := 0


func test_reserve_cell_succeeds():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh.clear_reservations()
    var cell := Vector2i(10, 10)
    var result: bool = _sh.reserve_cell(cell)
    _sh.clear_reservations()
    if result == true:
        _test_passed += 1
        print("    PASS: reserve_cell succeeds on empty cell")
    else:
        _test_failed += 1
        print("    FAIL: expected true, got false")


func test_reserve_cell_fails_when_taken():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh.clear_reservations()
    var cell := Vector2i(10, 10)
    _sh.reserve_cell(cell)
    var result: bool = _sh.reserve_cell(cell)
    _sh.clear_reservations()
    if result == false:
        _test_passed += 1
        print("    PASS: reserve_cell fails on already reserved cell")
    else:
        _test_failed += 1
        print("    FAIL: expected false, got true")


func test_release_cell_frees():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh.clear_reservations()
    var cell := Vector2i(10, 10)
    _sh.reserve_cell(cell)
    _sh.release_cell(cell)
    var result: bool = _sh.reserve_cell(cell)
    _sh.clear_reservations()
    if result == true:
        _test_passed += 1
        print("    PASS: release_cell frees the cell")
    else:
        _test_failed += 1
        print("    FAIL: expected true after release, got false")


func test_is_cell_blocked_reflects_blocked():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh.clear_reservations()
    _sh._blocked_cells.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    _sh._blocked_cells[key] = true
    var idle: bool = _sh.is_cell_blocked(cell)
    var reserved: bool = _sh.reserve_cell(cell)
    _sh._blocked_cells.erase(key)
    if idle == true and reserved == false:
        _test_passed += 1
        print("    PASS: is_cell_blocked reflects blocked state")
    else:
        _test_failed += 1
        print("    FAIL: idle=%s, reserved=%s" % [idle, reserved])


func test_register_building_cells():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh._building_cells.clear()
    var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6), Vector2i(6, 6)]
    _sh.register_building_cells(cells)
    var all_registered: bool = (
        _sh._building_cells.has(CellUtil.cell_key(Vector2i(5, 5)))
        and _sh._building_cells.has(CellUtil.cell_key(Vector2i(6, 5)))
        and _sh._building_cells.has(CellUtil.cell_key(Vector2i(5, 6)))
        and _sh._building_cells.has(CellUtil.cell_key(Vector2i(6, 6)))
    )
    _sh._building_cells.clear()
    if all_registered:
        _test_passed += 1
        print("    PASS: register_building_cells adds all cells")
    else:
        _test_failed += 1
        print("    FAIL: not all cells registered")


func test_unregister_building_cells():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh._building_cells.clear()
    var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5)]
    _sh.register_building_cells(cells)
    _sh.unregister_building_cells(cells)
    var has_55: bool = _sh._building_cells.has(CellUtil.cell_key(Vector2i(5, 5)))
    var has_65: bool = _sh._building_cells.has(CellUtil.cell_key(Vector2i(6, 5)))
    var all_removed: bool = not has_55 and not has_65
    if all_removed:
        _test_passed += 1
        print("    PASS: unregister_building_cells removes all cells")
    else:
        _test_failed += 1
        print("    FAIL: cells still present after unregister")


func test_get_blocked_cells_merges_building_and_blocked():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh._blocked_cells.clear()
    _sh._building_cells.clear()
    _sh._blocked_cells[CellUtil.cell_key(Vector2i(10, 10))] = true
    var building_cells: Array[Vector2i] = [Vector2i(20, 20), Vector2i(21, 20)]
    _sh.register_building_cells(building_cells)
    var blocked: Dictionary = _sh.get_blocked_cells()
    var has_blocked: bool = blocked.has(CellUtil.cell_key(Vector2i(10, 10)))
    var has_building1: bool = blocked.has(CellUtil.cell_key(Vector2i(20, 20)))
    var has_building2: bool = blocked.has(CellUtil.cell_key(Vector2i(21, 20)))
    _sh._blocked_cells.clear()
    _sh._building_cells.clear()
    if has_blocked and has_building1 and has_building2:
        _test_passed += 1
        print("    PASS: get_blocked_cells merges building and blocked cells")
    else:
        _test_failed += 1
        print("    FAIL: blocked=%s, b1=%s, b2=%s" % [has_blocked, has_building1, has_building2])


func test_reserve_cell_fails_on_building_cell():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh.clear_reservations()
    _sh._building_cells.clear()
    var cell := Vector2i(50, 50)
    var cells: Array[Vector2i] = [cell]
    _sh.register_building_cells(cells)
    var result: bool = _sh.reserve_cell(cell)
    _sh.clear_reservations()
    _sh._building_cells.clear()
    if result == false:
        _test_passed += 1
        print("    PASS: reserve_cell fails on building cell")
    else:
        _test_failed += 1
        print("    FAIL: expected false for building cell, got true")


func _test_entity_on_cell(
    cell: Vector2i, mc: MovementController, expected: bool, label: String
) -> void:
    _sh._grid.clear()
    var key: int = CellUtil.cell_key(cell)
    if mc != null:
        _sh._grid[key] = [{"node": Node3D.new(), "mc": mc}]
    var result: bool = _sh.is_any_entity_on_cell(cell)
    _sh._grid.erase(key)
    if mc != null:
        mc.queue_free()
    if result == expected:
        _test_passed += 1
        print("    PASS: is_any_entity_on_cell %s" % label)
    else:
        _test_failed += 1
        var msg := "is_any_entity_on_cell %s — expected %s, got %s"
        print("    FAIL: %s" % msg % [label, expected, result])


func test_is_any_entity_on_cell_empty():
    _test_entity_on_cell(Vector2i(99, 99), null, false, "returns false for empty cell")


func test_is_any_entity_on_cell_with_idle_unit():
    var mc := MovementController.new()
    mc._state = MovementController.State.IDLE
    _test_entity_on_cell(Vector2i(10, 10), mc, true, "returns true for idle unit")


func test_is_any_entity_on_cell_with_moving_unit():
    var mc := MovementController.new()
    mc._state = MovementController.State.MOVING
    _test_entity_on_cell(Vector2i(10, 10), mc, true, "returns true for moving unit")


func test_is_any_entity_on_cell_resource_only():
    _sh._grid.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    _sh._grid[key] = [{"node": Node3D.new(), "mc": null}]
    var result: bool = _sh.is_any_entity_on_cell(cell)
    _sh._grid.erase(key)
    if result == false:
        _test_passed += 1
        print("    PASS: is_any_entity_on_cell returns false for resource-only cell")
    else:
        _test_failed += 1
        print("    FAIL: expected false for resource-only cell, got true")


func test_get_infantry_count_empty():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh._infantry_cell_counts.clear()
    var cell := Vector2i(50, 50)
    var count: int = _sh.get_infantry_count(cell)
    if count == 0:
        _test_passed += 1
        print("    PASS: get_infantry_count returns 0 for empty cell")
    else:
        _test_failed += 1
        print("    FAIL: expected 0, got %d" % count)


func test_get_infantry_count_with_entries():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh._infantry_cell_counts.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    _sh._infantry_cell_counts[key] = 2
    var count: int = _sh.get_infantry_count(cell)
    _sh._infantry_cell_counts.erase(key)
    if count == 2:
        _test_passed += 1
        print("    PASS: get_infantry_count returns correct count")
    else:
        _test_failed += 1
        print("    FAIL: expected 2, got %d" % count)


func test_is_cell_full_for_infantry():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh._infantry_cell_counts.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    _sh._infantry_cell_counts[key] = 3
    var full: bool = _sh.is_cell_full_for_infantry(cell)
    _sh._infantry_cell_counts.erase(key)
    if full == true:
        _test_passed += 1
        print("    PASS: is_cell_full_for_infantry returns true at capacity")
    else:
        _test_failed += 1
        print("    FAIL: expected true at capacity, got false")


func test_is_cell_not_full_for_infantry():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh._infantry_cell_counts.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    _sh._infantry_cell_counts[key] = 2
    var full: bool = _sh.is_cell_full_for_infantry(cell)
    _sh._infantry_cell_counts.erase(key)
    if full == false:
        _test_passed += 1
        print("    PASS: is_cell_full_for_infantry returns false below capacity")
    else:
        _test_failed += 1
        print("    FAIL: expected false below capacity, got true")


func test_get_crushable_enemies_empty():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh._grid.clear()
    var cell := Vector2i(10, 10)
    var enemies: Array = _sh.get_crushable_enemies_on_cell(cell, 0)
    if enemies.is_empty():
        _test_passed += 1
        print("    PASS: get_crushable_enemies returns empty for empty cell")
    else:
        _test_failed += 1
        print("    FAIL: expected empty array, got %d entries" % enemies.size())


func test_get_crushable_enemies_filters_by_player():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._grid.clear()
    _sh._infantry_cell_counts.clear()
    var cell := Vector2i(10, 10)
    var cell_world := CellUtil.cell_to_world(cell)
    var key: int = CellUtil.cell_key(cell)
    var friendly := Node3D.new()
    friendly.name = "Friendly"
    var friendly_stats := StatsComponent.new()
    friendly_stats.name = "StatsComponent"
    friendly_stats.entity_type = EntityData.EntityType.INFANTRY
    friendly_stats.player_id = 0
    friendly_stats.crushable = true
    friendly.add_child(friendly_stats)
    add_child(friendly)
    var enemy := Node3D.new()
    enemy.name = "Enemy"
    var enemy_stats := StatsComponent.new()
    enemy_stats.name = "StatsComponent"
    enemy_stats.entity_type = EntityData.EntityType.INFANTRY
    enemy_stats.player_id = 1
    enemy_stats.crushable = true
    enemy.add_child(enemy_stats)
    add_child(enemy)
    _sh._grid[key] = [
        {
            "node": friendly, "mc": null,
            "entity_type": EntityData.EntityType.INFANTRY,
            "player_id": 0,
        },
        {
            "node": enemy, "mc": null,
            "entity_type": EntityData.EntityType.INFANTRY,
            "player_id": 1,
        },
    ]
    var enemies: Array = _sh.get_crushable_enemies_on_cell(cell, 0)
    _sh._grid.erase(key)
    _sh.set_process(true)
    _sh.set_physics_process(true)
    if enemies.size() == 1 and enemies[0] == enemy:
        _test_passed += 1
        print("    PASS: get_crushable_enemies filters by player_id")
    else:
        _test_failed += 1
        print("    FAIL: expected 1 enemy, got %d" % enemies.size())
    remove_child(friendly)
    remove_child(enemy)
    friendly.free()
    enemy.free()


func test_get_crushable_enemies_skips_non_crushable():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._grid.clear()
    _sh._infantry_cell_counts.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    var enemy := Node3D.new()
    enemy.name = "Enemy"
    var enemy_stats := StatsComponent.new()
    enemy_stats.name = "StatsComponent"
    enemy_stats.entity_type = EntityData.EntityType.INFANTRY
    enemy_stats.player_id = 1
    enemy_stats.crushable = false
    enemy.add_child(enemy_stats)
    add_child(enemy)
    _sh._grid[key] = [
        {"node": enemy, "mc": null, "entity_type": EntityData.EntityType.INFANTRY, "player_id": 1},
    ]
    var enemies: Array = _sh.get_crushable_enemies_on_cell(cell, 0)
    _sh._grid.erase(key)
    _sh.set_process(true)
    _sh.set_physics_process(true)
    if enemies.is_empty():
        _test_passed += 1
        print("    PASS: get_crushable_enemies skips non-crushable")
    else:
        _test_failed += 1
        print("    FAIL: non-crushable enemy was returned")
    remove_child(enemy)
    enemy.free()
