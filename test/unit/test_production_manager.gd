extends Node

# ProductionManager tests — queue stacking, count param, cancel refund logic

var _test_passed := 0
var _test_failed := 0

# Injected by test runner (see run_tests.gd:_inject_autoloads)
var _em: Node = null


func _get_pm() -> Node:
    if _em == null:
        return null
    return _em.get_node_or_null("/root/ProductionManager")


func _make_infantry(id: String = "test_infantry", cost: int = 100) -> EntityData:
    var data := EntityData.new()
    data.id = id
    data.entity_type = EntityData.EntityType.INFANTRY
    data.display_name = "Test Infantry"
    data.cost = cost
    data.build_time = 5.0
    data.buildable_queue = "InfantryType"
    data.buildable = true
    return data


func _cleanup_queue(pm: Node, queue_key: String) -> void:
    if not pm._queues.has(queue_key):
        return
    var queue: Array = pm._queues[queue_key]
    for item in queue:
        var pq: ProductionQueue = item as ProductionQueue
        if pq and pq.is_paused:
            pq.is_paused = false
    pm._queues.erase(queue_key)
    pm._active_index.erase(queue_key)


# --- start_production count parameter ---


func test_start_production_default_count():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_default", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 1:
        _test_passed += 1
        print("    PASS: default count creates 1 item")
    else:
        _test_failed += 1
        print("    FAIL: expected 1 item, got %d" % items.size())
    _cleanup_queue(pm, key)


func test_start_production_count_5():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_count5", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data, 5)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    if pq.count == 5:
        _test_passed += 1
        print("    PASS: count=5 creates stack of 5")
    else:
        _test_failed += 1
        print("    FAIL: expected count 5, got %d" % pq.count)
    _cleanup_queue(pm, key)


func test_start_production_stacking_increments():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_stack", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data)
    pm.start_production(0, data)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    if items.size() == 1 and pq.count == 2:
        _test_passed += 1
        print("    PASS: stacking increments count to 2")
    else:
        _test_failed += 1
        print("    FAIL: expected 1 item count=2, got %d items count=%d" % [items.size(), pq.count])
    _cleanup_queue(pm, key)


func test_start_production_stacking_adds_5():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_stack5", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data, 3)
    pm.start_production(0, data, 5)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    if pq.count == 8:
        _test_passed += 1
        print("    PASS: stacking adds 3+5=8")
    else:
        _test_failed += 1
        print("    FAIL: expected count 8, got %d" % pq.count)
    _cleanup_queue(pm, key)


func test_start_production_stacking_caps_at_max():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_cap", 100)
    _em.add(0, 5000, "test")
    pm.start_production(0, data, 24)
    pm.start_production(0, data, 5)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    if pq.count == pm.MAX_STACK:
        _test_passed += 1
        print("    PASS: count capped at MAX_STACK")
    else:
        _test_failed += 1
        print("    FAIL: expected %d, got %d" % [pm.MAX_STACK, pq.count])
    _cleanup_queue(pm, key)


func test_start_production_different_entities_not_stacked():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data_a := _make_infantry("test_a", 100)
    var data_b := _make_infantry("test_b", 200)
    _em.add(0, 500, "test")
    pm.start_production(0, data_a)
    pm.start_production(0, data_b)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 2:
        _test_passed += 1
        print("    PASS: different entities create separate entries")
    else:
        _test_failed += 1
        print("    FAIL: expected 2 entries, got %d" % items.size())
    _cleanup_queue(pm, key)


# --- cancel_production refund logic ---


func test_cancel_single_item_refunds():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_refund", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 40.0
    var balance_before: int = _em.get_balance(0)
    pm.cancel_production(0, key, 0)
    var balance_after: int = _em.get_balance(0)
    if balance_after == balance_before + 40:
        _test_passed += 1
        print("    PASS: single item cancel refunds deducted amount")
    else:
        _test_failed += 1
        print("    FAIL: expected balance %d, got %d" % [balance_before + 40, balance_after])
    _cleanup_queue(pm, key)


func test_cancel_stacked_decrement_no_refund():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_norefund", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data, 5)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 50.0
    var balance_before: int = _em.get_balance(0)
    pm.cancel_production(0, key, 0, 1)
    var balance_after: int = _em.get_balance(0)
    if pq.count == 4 and balance_after == balance_before:
        _test_passed += 1
        print("    PASS: stacked decrement: count=4, no refund")
    else:
        _test_failed += 1
        var refund := balance_after - balance_before
        print("    FAIL: expected count=4 no refund, got count=%d refund=%d" % [pq.count, refund])
    _cleanup_queue(pm, key)


func test_cancel_stacked_by_5_no_refund():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_cancel5", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data, 10)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 80.0
    var balance_before: int = _em.get_balance(0)
    pm.cancel_production(0, key, 0, 5)
    var balance_after: int = _em.get_balance(0)
    if pq.count == 5 and balance_after == balance_before:
        _test_passed += 1
        print("    PASS: cancel 5 from 10: count=5, no refund")
    else:
        _test_failed += 1
        var refund := balance_after - balance_before
        print("    FAIL: expected count=5 no refund, got count=%d refund=%d" % [pq.count, refund])
    _cleanup_queue(pm, key)


func test_cancel_stacked_force_removes_and_refunds():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_force", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data, 3)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 60.0
    var balance_before: int = _em.get_balance(0)
    pm.cancel_production(0, key, 0, 5)
    var balance_after: int = _em.get_balance(0)
    var remaining: Array = pm.get_queue_items(key)
    if remaining.size() == 0 and balance_after == balance_before + 60:
        _test_passed += 1
        print("    PASS: force cancel (count>=item.count) removes and refunds")
    else:
        _test_failed += 1
        var refund := balance_after - balance_before
        var n_items := remaining.size()
        print("    FAIL: expected 0 items refund=60, got %d items refund=%d" % [n_items, refund])
    _cleanup_queue(pm, key)


func test_cancel_entire_queue_cleans_up():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_cleanup", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data)
    var key: String = pm.get_queue_key(0, "InfantryType")
    pm.cancel_production(0, key, 0)
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        _test_passed += 1
        print("    PASS: queue cleaned up after last item removed")
    else:
        _test_failed += 1
        print("    FAIL: expected 0 items, got %d" % items.size())
    _cleanup_queue(pm, key)


# --- pause / resume ---


func test_pause_and_resume():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_pauses", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    var ok := true
    if pq.is_paused:
        ok = false
    pm.pause_production(key, 0)
    if not pq.is_paused:
        ok = false
    pm.resume_production(key, 0)
    if pq.is_paused:
        ok = false
    if ok:
        _test_passed += 1
        print("    PASS: pause and resume toggle is_paused")
    else:
        _test_failed += 1
        print("    FAIL: pause/resume did not toggle correctly")
    _cleanup_queue(pm, key)


# --- cancel on paused items (right-click behavior) ---


func test_cancel_paused_single_removes():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_cancel_paused", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 30.0
    pm.pause_production(key, 0)
    var balance_before: int = _em.get_balance(0)
    pm.cancel_production(0, key, 0, 1)
    var balance_after: int = _em.get_balance(0)
    var remaining: Array = pm.get_queue_items(key)
    if remaining.size() == 0 and balance_after == balance_before + 30:
        _test_passed += 1
        print("    PASS: cancel paused single item removes and refunds")
    else:
        _test_failed += 1
        var refund := balance_after - balance_before
        var n_items := remaining.size()
        print("    FAIL: expected 0 items refund=30, got %d items refund=%d" % [n_items, refund])
    _cleanup_queue(pm, key)


func test_cancel_paused_stacked_decrements():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_cancel_paused_stack", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data, 5)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 40.0
    pm.pause_production(key, 0)
    var balance_before: int = _em.get_balance(0)
    pm.cancel_production(0, key, 0, 1)
    var balance_after: int = _em.get_balance(0)
    if pq.count == 4 and balance_after == balance_before:
        _test_passed += 1
        print("    PASS: cancel paused stacked item decrements count, no refund")
    else:
        _test_failed += 1
        var refund := balance_after - balance_before
        print("    FAIL: expected count=4 no refund, got count=%d refund=%d" % [pq.count, refund])
    _cleanup_queue(pm, key)


func test_cancel_active_single_removes():
    var pm := _get_pm()
    if pm == null or _em == null:
        _test_failed += 1
        print("    FAIL: autoloads not available")
        return
    var data := _make_infantry("test_cancel_active", 100)
    _em.add(0, 500, "test")
    pm.start_production(0, data)
    var key: String = pm.get_queue_key(0, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 25.0
    var balance_before: int = _em.get_balance(0)
    pm.cancel_production(0, key, 0, 1)
    var balance_after: int = _em.get_balance(0)
    var remaining: Array = pm.get_queue_items(key)
    if remaining.size() == 0 and balance_after == balance_before + 25:
        _test_passed += 1
        print("    PASS: cancel active single item removes and refunds")
    else:
        _test_failed += 1
        var refund := balance_after - balance_before
        var n_items := remaining.size()
        print("    FAIL: expected 0 items refund=25, got %d items refund=%d" % [n_items, refund])
    _cleanup_queue(pm, key)


func test_queue_key_format():
    var pm := _get_pm()
    if pm == null:
        _test_failed += 1
        print("    FAIL: ProductionManager not available")
        return
    var key: String = pm.get_queue_key(0, "InfantryType")
    if key == "0:InfantryType":
        _test_passed += 1
        print("    PASS: queue key format is player_id:factory_type")
    else:
        _test_failed += 1
        print("    FAIL: expected '0:InfantryType', got '%s'" % key)


func test_queue_key_different_players():
    var pm := _get_pm()
    if pm == null:
        _test_failed += 1
        print("    FAIL: ProductionManager not available")
        return
    var key0: String = pm.get_queue_key(0, "InfantryType")
    var key1: String = pm.get_queue_key(1, "InfantryType")
    if key0 != key1:
        _test_passed += 1
        print("    PASS: different players have different keys")
    else:
        _test_failed += 1
        print("    FAIL: player 0 and 1 have same key")
