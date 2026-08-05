extends Node

# ProductionManager tests — queue stacking, count param, cancel refund logic

# Injected by test runner (see run_tests.gd:_inject_autoloads)
var _em: Node = null

# FactoryComponent nodes created by speed-cache tests (cleaned up per test)
var _test_factories: Array = []

# Unique player ID to avoid state leakage
const PID := 200


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


func _make_factory() -> EntityData:
    var data := EntityData.new()
    data.id = "test_barracks"
    data.entity_type = EntityData.EntityType.BUILDING
    data.display_name = "Test Barracks"
    data.factory = "InfantryType"
    data.buildable = true
    return data


func _ensure_factory() -> void:
    if _em == null:
        return
    var ps := _em.get_node_or_null("/root/PrerequisiteSystem")
    if ps and ps.get_build_count(PID, "test_barracks") > 0:
        return
    var factory_data := _make_factory()
    var ef := _em.get_node_or_null("/root/EntityFactory")
    if ef:
        ef._entity_cache["test_barracks"] = factory_data
    if ps:
        ps.register_building(PID, factory_data)


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


# --- production speed cache (D5) ---


## Create a real FactoryComponent in the scene tree so _ready joins the group.
func _make_factory_node() -> FactoryComponent:
    var factory := FactoryComponent.new()
    factory.name = "TestFactory"
    factory.produces = ["InfantryType"]
    factory.player_id = PID
    _em.get_tree().root.add_child(factory)
    _test_factories.append(factory)
    return factory


func _free_test_factories() -> void:
    for factory in _test_factories:
        if is_instance_valid(factory):
            factory.free()
    _test_factories.clear()


## Expected speed for a given factory count per the multiple-factory rule.
func _expected_speed(factory_count: int) -> float:
    var multiple_factory: float = 0.5
    var rules := GlobalRules.get_current()
    if rules:
        multiple_factory = rules.multiple_factory
    return 1.0 + (factory_count - 1) * multiple_factory


func test_production_speed_cached_until_invalidated():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    pm._speed_cache.clear()
    var key: String = pm.get_queue_key(PID, "InfantryType")
    _make_factory_node()
    var speed_one: float = pm._get_production_speed(key)
    if not pm._speed_cache.has(key):
        TestHelper.fail("first speed lookup should populate the cache")
        _free_test_factories()
        return
    # Cache hit reuses the value without re-scanning the group.
    var cached_speed: float = pm._get_production_speed(key)
    var cache_hit: bool = cached_speed == speed_one
    # Any factory added through the tree invalidates the cached speed.
    _make_factory_node()
    var recomputed_speed: float = pm._get_production_speed(key)
    var recomputed_after_add: bool = recomputed_speed == _expected_speed(2)
    (
        TestHelper
        . assert_true(
            cache_hit and recomputed_after_add,
            (
                "cache hit reuses the value, factory add invalidates: "
                + (
                    "expected %f then %f, got %f then %f"
                    % [_expected_speed(1), _expected_speed(2), cached_speed, recomputed_speed]
                )
            ),
        )
    )
    _free_test_factories()


func test_production_speed_recomputed_after_factory_added():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    pm._speed_cache.clear()
    var key: String = pm.get_queue_key(PID, "InfantryType")
    _make_factory_node()
    var speed_before: float = pm._get_production_speed(key)
    _make_factory_node()
    # Factories are buildings placed via BuildingManager, which unblocks the queue
    pm.clear_waiting_for_placement(PID)
    var speed_after: float = pm._get_production_speed(key)
    (
        TestHelper
        . assert_true(
            speed_before == _expected_speed(1) and speed_after == _expected_speed(2),
            (
                "speed recomputed when a factory is placed: expected %f/%f, got %f/%f"
                % [_expected_speed(1), _expected_speed(2), speed_before, speed_after]
            ),
        )
    )
    _free_test_factories()


func test_production_speed_recomputed_after_factory_destroyed():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    pm._speed_cache.clear()
    var key: String = pm.get_queue_key(PID, "InfantryType")
    _make_factory_node()
    var factory_b := _make_factory_node()
    var speed_before: float = pm._get_production_speed(key)
    factory_b.free()
    var cache_cleared: bool = pm._speed_cache.is_empty()
    var speed_after: float = pm._get_production_speed(key)
    (
        TestHelper
        . assert_true(
            (
                speed_before == _expected_speed(2)
                and cache_cleared
                and speed_after == _expected_speed(1)
            ),
            (
                "destroying a factory invalidates the cache: expected %f then %f, "
                + (
                    "got %f then %f"
                    % [_expected_speed(2), _expected_speed(1), speed_before, speed_after]
                )
            ),
        )
    )
    _free_test_factories()


func test_set_primary_invalidates_speed_cache():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    pm._speed_cache.clear()
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var factory_a := _make_factory_node()
    _make_factory_node()
    pm._get_production_speed(key)
    if pm._speed_cache.is_empty():
        TestHelper.fail("cache should be populated")
        _free_test_factories()
        return
    factory_a.set_primary()
    (
        TestHelper
        . assert_true(
            pm._speed_cache.is_empty(),
            "set_primary emits factories_changed and clears the speed cache",
        )
    )
    _free_test_factories()


# --- start_production count parameter ---


func test_start_production_default_count():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_default", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    (
        TestHelper
        . assert_true(
            items.size() == 1,
            "default count creates 1 item: expected 1 item, got %d" % items.size(),
        )
    )
    _cleanup_queue(pm, key)


func test_start_production_count_5():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_count5", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data, 5)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        _cleanup_queue(pm, key)
        return
    var pq: ProductionQueue = items[0] as ProductionQueue
    (
        TestHelper
        . assert_true(
            pq.count == 5,
            "count=5 creates stack of 5: expected count 5, got %d" % pq.count,
        )
    )
    _cleanup_queue(pm, key)


func test_start_production_stacking_increments():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_stack", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data)
    pm.start_production(PID, data)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        _cleanup_queue(pm, key)
        return
    var pq: ProductionQueue = items[0] as ProductionQueue
    (
        TestHelper
        . assert_true(
            items.size() == 1 and pq.count == 2,
            (
                "stacking increments count to 2: expected 1 item count=2, got %d items count=%d"
                % [items.size(), pq.count]
            ),
        )
    )
    _cleanup_queue(pm, key)


func test_start_production_stacking_adds_5():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_stack5", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data, 3)
    pm.start_production(PID, data, 5)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        _cleanup_queue(pm, key)
        return
    var pq: ProductionQueue = items[0] as ProductionQueue
    (
        TestHelper
        . assert_true(
            pq.count == 8,
            "stacking adds 3+5=8: expected count 8, got %d" % pq.count,
        )
    )
    _cleanup_queue(pm, key)


func test_start_production_stacking_caps_at_max():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_cap", 100)
    _em.add(PID, 5000, "test")
    pm.start_production(PID, data, 24)
    pm.start_production(PID, data, 5)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        _cleanup_queue(pm, key)
        return
    var pq: ProductionQueue = items[0] as ProductionQueue
    (
        TestHelper
        . assert_true(
            pq.count == pm.MAX_STACK,
            "count capped at MAX_STACK: expected %d, got %d" % [pm.MAX_STACK, pq.count],
        )
    )
    _cleanup_queue(pm, key)


func test_start_production_different_entities_not_stacked():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data_a := _make_infantry("test_a", 100)
    var data_b := _make_infantry("test_b", 200)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data_a)
    pm.start_production(PID, data_b)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    (
        TestHelper
        . assert_true(
            items.size() == 2,
            "different entities create separate entries: expected 2 entries, got %d" % items.size(),
        )
    )
    _cleanup_queue(pm, key)


# --- cancel_production refund logic ---


func test_cancel_single_item_refunds():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_refund", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        return
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 40.0
    var balance_before: int = _em.get_balance(PID)
    pm.cancel_production(PID, key, 0)
    var balance_after: int = _em.get_balance(PID)
    (
        TestHelper
        . assert_true(
            balance_after == balance_before + 40,
            (
                "single item cancel refunds deducted amount: expected balance %d, got %d"
                % [balance_before + 40, balance_after]
            ),
        )
    )
    _cleanup_queue(pm, key)


func test_cancel_stacked_decrement_no_refund():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_norefund", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data, 5)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        return
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 50.0
    var balance_before: int = _em.get_balance(PID)
    pm.cancel_production(PID, key, 0, 1)
    var balance_after: int = _em.get_balance(PID)
    var refund := balance_after - balance_before
    (
        TestHelper
        . assert_true(
            pq.count == 4 and balance_after == balance_before,
            (
                "stacked decrement: count=4, no refund: expected count=4 "
                + "no refund, got count=%d refund=%d" % [pq.count, refund]
            ),
        )
    )
    _cleanup_queue(pm, key)


func test_cancel_stacked_by_5_no_refund():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_cancel5", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data, 10)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        return
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 80.0
    var balance_before: int = _em.get_balance(PID)
    pm.cancel_production(PID, key, 0, 5)
    var balance_after: int = _em.get_balance(PID)
    var refund := balance_after - balance_before
    (
        TestHelper
        . assert_true(
            pq.count == 5 and balance_after == balance_before,
            (
                "cancel 5 from 10: count=5, no refund: expected count=5 "
                + "no refund, got count=%d refund=%d" % [pq.count, refund]
            ),
        )
    )
    _cleanup_queue(pm, key)


func test_cancel_stacked_force_removes_and_refunds():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_force", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data, 3)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        return
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 60.0
    var balance_before: int = _em.get_balance(PID)
    pm.cancel_production(PID, key, 0, 5)
    var balance_after: int = _em.get_balance(PID)
    var remaining: Array = pm.get_queue_items(key)
    var refund := balance_after - balance_before
    var n_items := remaining.size()
    (
        TestHelper
        . assert_true(
            remaining.size() == 0 and balance_after == balance_before + 60,
            (
                "force cancel (count>=item.count) removes and refunds: expected 0 items "
                + "refund=60, got %d items refund=%d" % [n_items, refund]
            ),
        )
    )
    _cleanup_queue(pm, key)


func test_cancel_entire_queue_cleans_up():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_cleanup", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    pm.cancel_production(PID, key, 0)
    var items: Array = pm.get_queue_items(key)
    (
        TestHelper
        . assert_true(
            items.size() == 0,
            "queue cleaned up after last item removed: expected 0 items, got %d" % items.size(),
        )
    )
    _cleanup_queue(pm, key)


# --- pause / resume ---


func test_pause_and_resume():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_pauses", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        return
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
    (
        TestHelper
        . assert_true(
            ok,
            "pause and resume toggle is_paused: pause/resume did not toggle correctly",
        )
    )
    _cleanup_queue(pm, key)


# --- cancel on paused items (right-click behavior) ---


func test_cancel_paused_single_removes():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_cancel_paused", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        return
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 30.0
    pm.pause_production(key, 0)
    var balance_before: int = _em.get_balance(PID)
    pm.cancel_production(PID, key, 0, 1)
    var balance_after: int = _em.get_balance(PID)
    var remaining: Array = pm.get_queue_items(key)
    var refund := balance_after - balance_before
    var n_items := remaining.size()
    (
        TestHelper
        . assert_true(
            remaining.size() == 0 and balance_after == balance_before + 30,
            (
                "cancel paused single item removes and refunds: expected 0 items "
                + "refund=30, got %d items refund=%d" % [n_items, refund]
            ),
        )
    )
    _cleanup_queue(pm, key)


func test_cancel_paused_stacked_decrements():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_cancel_paused_stack", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data, 5)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        return
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 40.0
    pm.pause_production(key, 0)
    var balance_before: int = _em.get_balance(PID)
    pm.cancel_production(PID, key, 0, 1)
    var balance_after: int = _em.get_balance(PID)
    var refund := balance_after - balance_before
    (
        TestHelper
        . assert_true(
            pq.count == 4 and balance_after == balance_before,
            (
                "cancel paused stacked item decrements count, no refund: expected count=4 "
                + "no refund, got count=%d refund=%d" % [pq.count, refund]
            ),
        )
    )
    _cleanup_queue(pm, key)


func test_cancel_active_single_removes():
    var pm := _get_pm()
    if pm == null or _em == null:
        TestHelper.fail("autoloads not available")
        return
    _ensure_factory()
    var data := _make_infantry("test_cancel_active", 100)
    _em.add(PID, 500, "test")
    pm.start_production(PID, data)
    var key: String = pm.get_queue_key(PID, "InfantryType")
    var items: Array = pm.get_queue_items(key)
    if items.size() == 0:
        TestHelper.fail("expected 1 item, got 0")
        return
    var pq: ProductionQueue = items[0] as ProductionQueue
    pq.deducted = 25.0
    var balance_before: int = _em.get_balance(PID)
    pm.cancel_production(PID, key, 0, 1)
    var balance_after: int = _em.get_balance(PID)
    var remaining: Array = pm.get_queue_items(key)
    var refund := balance_after - balance_before
    var n_items := remaining.size()
    (
        TestHelper
        . assert_true(
            remaining.size() == 0 and balance_after == balance_before + 25,
            (
                "cancel active single item removes and refunds: expected 0 items "
                + "refund=25, got %d items refund=%d" % [n_items, refund]
            ),
        )
    )
    _cleanup_queue(pm, key)


func test_queue_key_format():
    var pm := _get_pm()
    if pm == null:
        TestHelper.fail("ProductionManager not available")
        return
    var key: String = pm.get_queue_key(0, "InfantryType")
    (
        TestHelper
        . assert_true(
            key == "0:InfantryType",
            "queue key format is player_id:factory_type: expected '0:InfantryType', got '%s'" % key,
        )
    )


func test_queue_key_different_players():
    var pm := _get_pm()
    if pm == null:
        TestHelper.fail("ProductionManager not available")
        return
    var key0: String = pm.get_queue_key(0, "InfantryType")
    var key1: String = pm.get_queue_key(1, "InfantryType")
    (
        TestHelper
        . assert_true(
            key0 != key1,
            "different players have different keys: player 0 and 1 have same key",
        )
    )
