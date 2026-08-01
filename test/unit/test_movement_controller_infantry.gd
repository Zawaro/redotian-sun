extends Node

# MovementController tests — crush mechanics, cursor resolution, and order generation

var _ts: Node = null
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


func test_is_moving_true_when_rotating():
    var mc := MovementController.new()
    mc.name = "MovementController"
    var entity := Node3D.new()
    entity.add_child(mc)
    mc._state = MovementController.State.ROTATING

    TestHelper.assert_eq(mc.is_moving(), true, "rotating state -> is_moving() = true")

    entity.queue_free()


func test_is_moving_true_when_moving():
    var mc := MovementController.new()
    mc.name = "MovementController"
    var entity := Node3D.new()
    entity.add_child(mc)
    mc._state = MovementController.State.MOVING

    TestHelper.assert_eq(mc.is_moving(), true, "moving state -> is_moving() = true")

    entity.queue_free()


func test_is_moving_true_when_wait():
    var mc := MovementController.new()
    mc.name = "MovementController"
    var entity := Node3D.new()
    entity.add_child(mc)
    mc._state = MovementController.State.WAIT

    TestHelper.assert_eq(mc.is_moving(), true, "wait state -> is_moving() = true")

    entity.queue_free()


func test_two_units_same_cell_get_distinct_slots():
    var cr := CellReservation.instance
    if cr == null:
        TestHelper.assert_true(false, "CellReservation not available")
        return
    cr.clear()
    var cell := Vector2i(30, 30)
    var entity_a := Node3D.new()
    var mc_a := MovementController.new()
    entity_a.add_child(mc_a)
    mc_a._parent = entity_a
    var entity_b := Node3D.new()
    var mc_b := MovementController.new()
    entity_b.add_child(mc_b)
    mc_b._parent = entity_b
    mc_a._assign_sub_slot_at_cell(cell)
    mc_b._assign_sub_slot_at_cell(cell)
    var distinct: bool = mc_a._assigned_slot != mc_b._assigned_slot
    var both_have: bool = mc_a._has_sub_slot and mc_b._has_sub_slot
    cr.clear()
    entity_a.queue_free()
    entity_b.queue_free()
    TestHelper.assert_true(distinct, "two units same cell get distinct sub-slots")
    TestHelper.assert_true(both_have, "both units hold a sub-slot")


func test_idle_occupant_slot_visible_to_new_arrival():
    var cr := CellReservation.instance
    var sh := SpatialHash.instance
    if cr == null or sh == null:
        TestHelper.assert_true(false, "CellReservation/SpatialHash not available")
        return
    cr.clear()
    sh._grid.clear()
    var cell := Vector2i(30, 30)
    var key := CellUtil.cell_key(cell)
    var idle_root := Node3D.new()
    var idle_mc := MovementController.new()
    idle_root.add_child(idle_mc)
    idle_mc._parent = idle_root
    idle_mc._assigned_slot = 0
    sh._grid[key] = [
        {
            "node": idle_root,
            "mc": idle_mc,
            "entity_type": EntityData.EntityType.INFANTRY,
            "player_id": 0,
        },
    ]
    var entity_b := Node3D.new()
    var mc_b := MovementController.new()
    entity_b.add_child(mc_b)
    mc_b._parent = entity_b
    mc_b._assign_sub_slot_at_cell(cell)
    var slot_b: int = mc_b._assigned_slot
    sh._grid.erase(key)
    cr.clear()
    idle_root.queue_free()
    entity_b.queue_free()
    TestHelper.assert_eq(slot_b, 1, "new arrival avoids idle occupant's slot")


func test_moving_occupant_does_not_block_slot():
    var cr := CellReservation.instance
    var sh := SpatialHash.instance
    if cr == null or sh == null:
        TestHelper.assert_true(false, "CellReservation/SpatialHash not available")
        return
    cr.clear()
    sh._grid.clear()
    var cell := Vector2i(30, 30)
    var key := CellUtil.cell_key(cell)
    var moving_root := Node3D.new()
    var moving_mc := MovementController.new()
    moving_root.add_child(moving_mc)
    moving_mc._parent = moving_root
    moving_mc._assigned_slot = 0
    moving_mc._state = MovementController.State.MOVING
    sh._grid[key] = [
        {
            "node": moving_root,
            "mc": moving_mc,
            "entity_type": EntityData.EntityType.INFANTRY,
            "player_id": 0,
        },
    ]
    var entity_b := Node3D.new()
    var mc_b := MovementController.new()
    entity_b.add_child(mc_b)
    mc_b._parent = entity_b
    mc_b._assign_sub_slot_at_cell(cell)
    var slot_b: int = mc_b._assigned_slot
    sh._grid.erase(key)
    cr.clear()
    moving_root.queue_free()
    entity_b.queue_free()
    TestHelper.assert_eq(slot_b, 0, "moving transit unit does not hold its slot")


func test_finish_stop_releases_sub_slot_claim():
    var cr := CellReservation.instance
    if cr == null:
        TestHelper.assert_true(false, "CellReservation not available")
        return
    cr.clear()
    var cell := Vector2i(30, 30)
    var entity := Node3D.new()
    var mc := MovementController.new()
    entity.add_child(mc)
    mc._parent = entity
    mc._assign_sub_slot_at_cell(cell)
    var before: int = cr.get_claim_count(cell)
    mc._finish_stop()
    var after: int = cr.get_claim_count(cell)
    cr.clear()
    entity.queue_free()
    TestHelper.assert_eq(before, 1, "move start holds a claim")
    TestHelper.assert_eq(after, 0, "finish stop releases the claim")


func test_full_cell_spreads_to_neighbor():
    var cr := CellReservation.instance
    if cr == null:
        TestHelper.assert_true(false, "CellReservation not available")
        return
    cr.clear()
    var target := Vector2i(30, 30)
    var owners: Array[Node3D] = []
    for i in CellSubPositions.get_slot_count():
        var owner := Node3D.new()
        add_child(owner)
        owners.append(owner)
        cr.reserve_sub_slot(target, owner)
    var entity := Node3D.new()
    var mc := MovementController.new()
    entity.add_child(mc)
    mc._parent = entity
    var free_cell := mc._find_nearest_free_sub_slot_cell(target)
    var spread: bool = free_cell != target
    cr.clear()
    for owner in owners:
        owner.queue_free()
    entity.queue_free()
    TestHelper.assert_true(spread, "full cell spreads to a neighbor")


func test_non_infantry_sharer_books_sub_slot():
    var cr := CellReservation.instance
    var sh := SpatialHash.instance
    if cr == null or sh == null or _ts == null:
        _test_failed += 1
        print("    FAIL: CellReservation/SpatialHash/TerrainSystem not available")
        return
    cr.clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(40, 40)
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.entity_type = EntityData.EntityType.VEHICLE
    entity.add_child(stats)
    var mc := MovementController.new()
    entity.add_child(mc)
    mc._parent = entity
    mc._shares_cell = true
    _ts.add_child(entity)
    mc.set_target_position(CellUtil.cell_to_world(cell))
    var claim: int = cr.get_claim_count(cell)
    cr.clear()
    _ts.remove_child(entity)
    entity.queue_free()
    if claim >= 1:
        _test_passed += 1
        print("    PASS: non-infantry shares_cell unit books a sub-slot")
    else:
        _test_failed += 1
        print("    FAIL: non-infantry shares_cell unit books a sub-slot")


func test_non_sharing_vehicle_does_not_book():
    var cr := CellReservation.instance
    if cr == null or SpatialHash.instance == null or _ts == null:
        _test_failed += 1
        print("    FAIL: CellReservation/SpatialHash/TerrainSystem not available")
        return
    cr.clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(45, 45)
    var entity := Node3D.new()
    var mc := MovementController.new()
    entity.add_child(mc)
    mc._parent = entity
    _ts.add_child(entity)
    mc.set_target_position(CellUtil.cell_to_world(cell))
    var claim: int = cr.get_claim_count(cell)
    cr.clear()
    _ts.remove_child(entity)
    entity.queue_free()
    if claim == 0:
        _test_passed += 1
        print("    PASS: non-sharing vehicle books no sub-slot")
    else:
        _test_failed += 1
        print("    FAIL: expected 0 claims, got %d" % claim)
