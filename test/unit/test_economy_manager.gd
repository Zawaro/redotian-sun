extends Node

# EconomyManager unit tests — credit tracking, add/deduct, signals
# Each test uses a unique player ID to avoid state leakage between tests.

var _em: Node = null
var _last_credits_changed: Array = []
var _last_insufficient: Array = []


func _ready() -> void:
    _em = get_node("/root/EconomyManager")


func _on_credits_changed(player_id: int, balance: int, reason: String) -> void:
    _last_credits_changed = [player_id, balance, reason]


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
