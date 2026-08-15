extends Node

# EconomyManager unit tests — credit tracking, add/deduct, signals
# Each test uses a unique player ID to avoid state leakage between tests.

var _em: Node = null
var _last_credits_changed: Array = []
var _last_insufficient: Array = []
var _last_credits_full: Array = []


func _ready() -> void:
    _em = get_node("/root/EconomyManager")


func _on_credits_changed(player_id: int, balance: int, reason: String) -> void:
    _last_credits_changed = [player_id, balance, reason]


func _on_credits_changed_full(
    player_id: int, balance: int, reason: String, category: String
) -> void:
    _last_credits_full = [player_id, balance, reason, category]


func _on_insufficient_funds(player_id: int, cost: int, balance: int) -> void:
    _last_insufficient = [player_id, cost, balance]


func test_add_credits():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 100
    _em.add(pid, 500, "harvest")
    var balance: int = _em.get_balance(pid)
    TestHelper.assert_true(
        balance == 500, "add_credits increases balance: expected balance == 500, got %d" % balance
    )


func test_deduct_success():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 101
    _em.add(pid, 1000, "test")
    var result: bool = _em.deduct(pid, 300, "build")
    TestHelper.assert_true(
        result, "deduct returns true when sufficient funds: deduct returned false"
    )


func test_deduct_insufficient():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 102
    _em.add(pid, 100, "test")
    var result: bool = _em.deduct(pid, 9999, "build")
    TestHelper.assert_true(
        not result, "deduct returns false when insufficient: deduct returned true"
    )


func test_deduct_decreases_balance():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 106
    _em.add(pid, 500, "test")
    _em.deduct(pid, 200, "build")
    var balance: int = _em.get_balance(pid)
    TestHelper.assert_true(
        balance == 300, "deduct decreases balance by cost: expected 300, got %d" % balance
    )


func test_can_afford():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 103
    _em.add(pid, 500, "test")
    TestHelper.assert_true(
        _em.can_afford(pid, 300),
        "can_afford returns true when sufficient: can_afford returned false"
    )
    (
        TestHelper
        . assert_true(
            not _em.can_afford(pid, 9999),
            (
                "can_afford returns false when insufficient: "
                + "can_afford returned true for impossible cost"
            ),
        )
    )


func test_multiple_players():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid_a := 104
    var pid_b := 105
    _em.add(pid_a, 100, "test")
    _em.add(pid_b, 200, "test")
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid_a) != _em.get_balance(pid_b),
            "players have independent balances: players have same balance",
        )
    )


func test_add_to_hidden_category():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 110
    _em.add(pid, 100, "harvest", "weed")
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid) == 0,
            (
                "hidden category excluded from displayable balance: expected 0, got %d"
                % _em.get_balance(pid)
            ),
        )
    )
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid, "weed") == 100,
            (
                "hidden category readable directly: expected 100, got %d"
                % _em.get_balance(pid, "weed")
            ),
        )
    )


func test_category_default_is_tiberium():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 111
    _em.add(pid, 500, "harvest")
    _em.deduct(pid, 200, "build")
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid, "tiberium") == 300,
            "default category is tiberium: expected 300, got %d" % _em.get_balance(pid, "tiberium"),
        )
    )


func test_deduct_category_draws_that_category():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 114
    _em.add(pid, 500, "harvest", "tiberium")
    _em.add(pid, 200, "harvest", "weed")
    var result: bool = _em.deduct(pid, 150, "build", "weed")
    TestHelper.assert_true(result, "deduct on weed succeeds with sufficient weed balance")
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid, "weed") == 50,
            "weed deduct draws weed only: expected 50, got %d" % _em.get_balance(pid, "weed"),
        )
    )
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid, "tiberium") == 500,
            (
                "tiberium untouched by weed deduct: expected 500, got %d"
                % _em.get_balance(pid, "tiberium")
            ),
        )
    )


func test_credits_changed_carries_category():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 112
    _em.credits_changed.connect(_on_credits_changed_full)
    _em.add(pid, 50, "harvest", "weed")
    _em.credits_changed.disconnect(_on_credits_changed_full)
    (
        TestHelper
        . assert_true(
            _last_credits_full.size() >= 4 and _last_credits_full[3] == "weed",
            "credits_changed carries category: expected weed, got %s" % str(_last_credits_full),
        )
    )


func test_storage_capacity_category():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 113
    (
        TestHelper
        . assert_true(
            _em.get_storage_capacity(pid, "tiberium") == 2000,
            "tiberium capacity is 2000: got %d" % _em.get_storage_capacity(pid, "tiberium"),
        )
    )
    (
        TestHelper
        . assert_true(
            _em.get_storage_capacity(pid, "weed") == 0,
            "unknown category capacity is 0: got %d" % _em.get_storage_capacity(pid, "weed"),
        )
    )


func test_free_credits_excluded_from_stored():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 115
    _em.add(pid, 1000, "crate", "tiberium", true)
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid, "tiberium") == 0,
            (
                "free credits do not count toward stored tiberium: expected 0, got %d"
                % _em.get_balance(pid, "tiberium")
            ),
        )
    )
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid) == 1000,
            (
                "free credits still count toward total balance: expected 1000, got %d"
                % _em.get_balance(pid)
            ),
        )
    )


func test_total_balance_includes_stored_and_free():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 116
    _em.add(pid, 500, "harvest")
    _em.add(pid, 300, "crate", "tiberium", true)
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid) == 800,
            "total balance is stored + free: expected 800, got %d" % _em.get_balance(pid),
        )
    )
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid, "tiberium") == 500,
            (
                "stored balance unchanged by free credits: expected 500, got %d"
                % _em.get_balance(pid, "tiberium")
            ),
        )
    )


func test_deduct_drains_stored_first():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 117
    _em.add(pid, 1000, "crate", "tiberium", true)
    _em.add(pid, 500, "harvest")
    var result: bool = _em.deduct(pid, 800, "build")
    TestHelper.assert_true(result, "deduct succeeds when stored + free cover the cost")
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid, "tiberium") == 0,
            (
                "deduct drains stored credits first: expected 0, got %d"
                % _em.get_balance(pid, "tiberium")
            ),
        )
    )
    (
        TestHelper
        . assert_true(
            _em.get_balance(pid) == 700,
            "remaining cost drawn from free credits: expected 700, got %d" % _em.get_balance(pid),
        )
    )


func test_deduct_insufficient_includes_free():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var pid := 118
    _em.add(pid, 300, "crate", "tiberium", true)
    var result: bool = _em.deduct(pid, 400, "build")
    TestHelper.assert_true(not result, "deduct fails when total (stored + free) is insufficient")
