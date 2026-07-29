extends Node

# MovementController tests — crush mechanics, cursor resolution, and order generation

var _test_passed := 0
var _test_failed := 0


func test_crush_kills_enemy():
    var sh := SpatialHash.instance
    if sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not available")
        return
    sh._grid.clear()
    var cell := Vector2i(5, 5)
    var key: int = CellUtil.cell_key(cell)
    var enemy := Node3D.new()
    var enemy_stats := StatsComponent.new()
    enemy_stats.entity_type = EntityData.EntityType.INFANTRY
    enemy_stats.player_id = 1
    enemy_stats.crushable = true
    enemy_stats.current_health = 100
    enemy.add_child(enemy_stats)
    add_child(enemy)
    var entry := {
        "node": enemy,
        "mc": null,
        "entity_type": EntityData.EntityType.INFANTRY,
        "player_id": 1,
    }
    sh._grid[key] = [entry]
    # get_crushable_enemies returns the enemy for a crusher on player 0
    var enemies: Array = sh.get_crushable_enemies_on_cell(cell, 0)
    sh._grid.erase(key)
    if enemies.size() == 1 and enemies[0] == enemy:
        _test_passed += 1
        print("    PASS: crusher identifies enemy infantry for crush")
    else:
        _test_failed += 1
        print("    FAIL: expected 1 enemy, got %d" % enemies.size())
    remove_child(enemy)
    enemy.free()


func test_crush_does_not_kill_friendly():
    var sh := SpatialHash.instance
    if sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not available")
        return
    sh._grid.clear()
    var cell := Vector2i(5, 5)
    var key: int = CellUtil.cell_key(cell)
    var friendly := Node3D.new()
    var friendly_stats := StatsComponent.new()
    friendly_stats.entity_type = EntityData.EntityType.INFANTRY
    friendly_stats.player_id = 0
    friendly_stats.crushable = true
    friendly.add_child(friendly_stats)
    var entry := {
        "node": friendly,
        "mc": null,
        "entity_type": EntityData.EntityType.INFANTRY,
        "player_id": 0,
    }
    sh._grid[key] = [entry]
    var enemies: Array = sh.get_crushable_enemies_on_cell(cell, 0)
    sh._grid.erase(key)
    if enemies.is_empty():
        _test_passed += 1
        print("    PASS: crusher does not identify friendly infantry as crushable")
    else:
        _test_failed += 1
        print("    FAIL: friendly infantry returned as crushable enemy")
    friendly.free()


func test_crush_does_not_affect_non_crushable():
    var sh := SpatialHash.instance
    if sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not available")
        return
    sh._grid.clear()
    var cell := Vector2i(5, 5)
    var key: int = CellUtil.cell_key(cell)
    var enemy := Node3D.new()
    var enemy_stats := StatsComponent.new()
    enemy_stats.entity_type = EntityData.EntityType.INFANTRY
    enemy_stats.player_id = 1
    enemy_stats.crushable = false
    enemy.add_child(enemy_stats)
    var entry := {
        "node": enemy,
        "mc": null,
        "entity_type": EntityData.EntityType.INFANTRY,
        "player_id": 1,
    }
    sh._grid[key] = [entry]
    var enemies: Array = sh.get_crushable_enemies_on_cell(cell, 0)
    sh._grid.erase(key)
    if enemies.is_empty():
        _test_passed += 1
        print("    PASS: crush does not affect non-crushable infantry")
    else:
        _test_failed += 1
        print("    FAIL: non-crushable infantry returned as crushable enemy")
    enemy.free()


# --- get_cursor_for_target tests ---


func test_cursor_always_returns_move():
    var mc := MovementController.new()
    mc.name = "MovementController"
    var entity := Node3D.new()
    entity.add_child(mc)

    var cursor := mc.get_cursor_for_target(null, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.MOVE, "null target -> MOVE")

    var target := Node3D.new()
    target.name = "SomeTarget"
    cursor = mc.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.MOVE, "any target -> MOVE")

    entity.queue_free()
    target.queue_free()


# --- get_order_for_target tests ---


func test_order_no_target_returns_move_order():
    var mc := MovementController.new()
    mc.name = "MovementController"
    var entity := Node3D.new()
    entity.add_child(mc)

    var target_pos := Vector3(10.0, 0.0, 20.0)
    var order := mc.get_order_for_target(null, Vector2i.ZERO, target_pos, {})

    TestHelper.assert_true(order != null, "no target -> order not null")
    TestHelper.assert_eq(order.cursor, CursorState.Type.MOVE, "cursor -> MOVE")
    TestHelper.assert_eq(order.priority, 5, "priority -> 5")
    TestHelper.assert_eq(order.target_pos, target_pos, "stores target_pos")

    entity.queue_free()


func test_order_with_target_returns_null():
    var mc := MovementController.new()
    mc.name = "MovementController"
    var entity := Node3D.new()
    entity.add_child(mc)

    var target := Node3D.new()
    target.name = "SomeTarget"
    var order := mc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})

    TestHelper.assert_true(order == null, "click target -> null (not a move order)")

    entity.queue_free()
    target.queue_free()


func test_order_queued_modifier():
    var mc := MovementController.new()
    mc.name = "MovementController"
    var entity := Node3D.new()
    entity.add_child(mc)

    var modifiers := {OrderResult.MOD_QUEUED: true}
    var order := mc.get_order_for_target(null, Vector2i.ZERO, Vector3.ZERO, modifiers)

    TestHelper.assert_true(order != null, "queued modifier -> order not null")
    TestHelper.assert_true(order.queued, "queued modifier -> order.queued = true")

    entity.queue_free()


# --- is_moving() tests ---


func test_is_moving_false_when_idle():
    var mc := MovementController.new()
    mc.name = "MovementController"
    var entity := Node3D.new()
    entity.add_child(mc)

    TestHelper.assert_eq(mc.is_moving(), false, "idle state -> is_moving() = false")

    entity.queue_free()
