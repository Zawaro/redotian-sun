extends Node

# CellReservation tests — in-flight sub-slot registry, present/coming split, lifecycle

var _test_passed := 0
var _test_failed := 0


func _make_owner() -> Node3D:
    var node := Node3D.new()
    add_child(node)
    return node


func test_reserve_assigns_lowest_free_slot():
    var cr := CellReservation.instance
    if cr == null:
        _test_failed += 1
        print("    FAIL: CellReservation not available")
        return
    cr.clear()
    var cell := Vector2i(10, 10)
    var a := _make_owner()
    var b := _make_owner()
    var slot_a: int = cr.reserve_sub_slot(cell, a)
    var slot_b: int = cr.reserve_sub_slot(cell, b)
    cr.clear()
    a.queue_free()
    b.queue_free()
    if slot_a == 0 and slot_b == 1:
        _test_passed += 1
        print("    PASS: reserve assigns lowest free slots 0,1")
    else:
        _test_failed += 1
        print("    FAIL: slots a=%d b=%d, expected 0,1" % [slot_a, slot_b])


func test_reserve_three_slots_deterministic_order():
    var cr := CellReservation.instance
    if cr == null:
        _test_failed += 1
        print("    FAIL: CellReservation not available")
        return
    cr.clear()
    var cell := Vector2i(10, 10)
    var owners: Array[Node3D] = []
    for i in CellReservation.NUM_SLOTS:
        owners.append(_make_owner())
    var slots: Array[int] = []
    for owner in owners:
        slots.append(cr.reserve_sub_slot(cell, owner))
    cr.clear()
    for owner in owners:
        owner.queue_free()
    if slots == [0, 1, 2]:
        _test_passed += 1
        print("    PASS: 3 reserves in order yield slots 0,1,2")
    else:
        _test_failed += 1
        print("    FAIL: slots=%s, expected [0,1,2]" % [slots])


func test_reserve_full_cell_returns_minus_one():
    var cr := CellReservation.instance
    if cr == null:
        _test_failed += 1
        print("    FAIL: CellReservation not available")
        return
    cr.clear()
    var cell := Vector2i(10, 10)
    var owners: Array[Node3D] = []
    for i in CellReservation.NUM_SLOTS:
        owners.append(_make_owner())
        cr.reserve_sub_slot(cell, owners[i])
    var fourth := _make_owner()
    var result: int = cr.reserve_sub_slot(cell, fourth)
    cr.clear()
    for owner in owners:
        owner.queue_free()
    fourth.queue_free()
    if result == -1:
        _test_passed += 1
        print("    PASS: reserve on full cell returns -1")
    else:
        _test_failed += 1
        print("    FAIL: expected -1, got %d" % result)


func test_release_frees_slot():
    var cr := CellReservation.instance
    if cr == null:
        _test_failed += 1
        print("    FAIL: CellReservation not available")
        return
    cr.clear()
    var cell := Vector2i(10, 10)
    var a := _make_owner()
    cr.reserve_sub_slot(cell, a)
    cr.release_sub_slot(cell, a)
    var available: int = cr.get_available_sub_slot(cell)
    cr.clear()
    a.queue_free()
    if available == 0:
        _test_passed += 1
        print("    PASS: release makes slot available again")
    else:
        _test_failed += 1
        print("    FAIL: available=%d, expected 0" % available)


func test_idempotent_same_cell_retention():
    var cr := CellReservation.instance
    if cr == null:
        _test_failed += 1
        print("    FAIL: CellReservation not available")
        return
    cr.clear()
    var cell := Vector2i(10, 10)
    var a := _make_owner()
    var first: int = cr.reserve_sub_slot(cell, a)
    var second: int = cr.reserve_sub_slot(cell, a)
    var claims: int = cr.get_claim_count(cell)
    cr.clear()
    a.queue_free()
    if first == second and claims == 1:
        _test_passed += 1
        print("    PASS: re-reserve same cell returns existing claim unchanged")
    else:
        _test_failed += 1
        print("    FAIL: first=%d second=%d claims=%d" % [first, second, claims])


func test_re_reserve_different_cell_releases_prior():
    var cr := CellReservation.instance
    if cr == null:
        _test_failed += 1
        print("    FAIL: CellReservation not available")
        return
    cr.clear()
    var cell_a := Vector2i(10, 10)
    var cell_b := Vector2i(20, 20)
    var a := _make_owner()
    cr.reserve_sub_slot(cell_a, a)
    var slot_b: int = cr.reserve_sub_slot(cell_b, a)
    var remaining_a: int = cr.get_claim_count(cell_a)
    var remaining_b: int = cr.get_claim_count(cell_b)
    cr.clear()
    a.queue_free()
    if slot_b == 0 and remaining_a == 0 and remaining_b == 1:
        _test_passed += 1
        print("    PASS: moving to new cell releases the prior claim")
    else:
        _test_failed += 1
        var msg := "FAIL: slot_b=%d remaining_a=%d remaining_b=%d"
        print(msg % [slot_b, remaining_a, remaining_b])


func test_present_occupant_slot_counts_toward_capacity():
    var cr := CellReservation.instance
    var sh := SpatialHash.instance
    if cr == null or sh == null:
        _test_failed += 1
        print("    FAIL: CellReservation or SpatialHash not available")
        return
    cr.clear()
    sh._grid.clear()
    var cell := Vector2i(10, 10)
    var key := CellUtil.cell_key(cell)
    var present_root := _make_owner()
    var present_mc := MovementController.new()
    present_mc._parent = present_root
    present_mc._assigned_slot = 0
    sh._grid[key] = [
        {
            "node": present_root,
            "mc": present_mc,
            "entity_type": EntityData.EntityType.INFANTRY,
            "player_id": 0,
        },
    ]
    sh._shared_cell_counts[key] = 1
    var a := _make_owner()
    var b := _make_owner()
    var slot_a: int = cr.reserve_sub_slot(cell, a)
    var slot_b: int = cr.reserve_sub_slot(cell, b)
    var full: bool = cr.is_cell_full(cell)
    sh._grid.erase(key)
    sh._shared_cell_counts.erase(key)
    cr.clear()
    present_mc.queue_free()
    present_root.queue_free()
    a.queue_free()
    b.queue_free()
    if slot_a == 1 and slot_b == 2 and full:
        _test_passed += 1
        print("    PASS: present occupant + 2 claims fills cell; slots 1,2 assigned")
    else:
        _test_failed += 1
        print("    FAIL: slot_a=%d slot_b=%d full=%s" % [slot_a, slot_b, full])


func test_tree_exited_releases_claims():
    var cr := CellReservation.instance
    if cr == null:
        _test_failed += 1
        print("    FAIL: CellReservation not available")
        return
    cr.clear()
    var cell := Vector2i(10, 10)
    var a := _make_owner()
    cr.reserve_sub_slot(cell, a)
    a.free()
    var claims: int = cr.get_claim_count(cell)
    cr.clear()
    if claims == 0:
        _test_passed += 1
        print("    PASS: owner free releases its claims")
    else:
        _test_failed += 1
        print("    FAIL: claims=%d after free, expected 0" % claims)


func test_stale_owner_pruned_on_read():
    var cr := CellReservation.instance
    if cr == null:
        _test_failed += 1
        print("    FAIL: CellReservation not available")
        return
    cr.clear()
    var cell := Vector2i(10, 10)
    var stale := Node3D.new()
    stale.free()
    cr._claims[CellUtil.cell_key(cell)] = [stale, null, null]
    var available: int = cr.get_available_sub_slot(cell)
    cr.clear()
    if available == 0:
        _test_passed += 1
        print("    PASS: stale owner pruned, slot reported available")
    else:
        _test_failed += 1
        print("    FAIL: available=%d, expected 0" % available)
