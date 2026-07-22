extends Node

# EconomyManager unit tests — credit tracking, add/deduct, signals
# Note: tests operate on EconomyManager directly (assumes autoload or injected)

var _test_passed := 0
var _test_failed := 0
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
        print("    FAIL: EconomyManager not injected")
        return
    _em.credits_changed.connect(_on_credits_changed)
    _em.add(0, 500, "harvest")
    var balance: int = _em.get_balance(0)
    if balance >= 500:
        print("    PASS: add_credits increases balance")
    else:
        print("    FAIL: expected balance >= 500, got %d" % balance)


func test_deduct_success():
    if _em == null:
        print("    FAIL: EconomyManager not injected")
        return
    _em.credits_changed.connect(_on_credits_changed)
    _em.add(0, 1000, "test")
    var result: bool = _em.deduct(0, 300, "build")
    if result:
        print("    PASS: deduct returns true when sufficient funds")
    else:
        print("    FAIL: deduct returned false")


func test_deduct_insufficient():
    if _em == null:
        print("    FAIL: EconomyManager not injected")
        return
    _em.insufficient_funds.connect(_on_insufficient_funds)
    _em.add(0, 100, "test")
    _last_insufficient = []
    var result: bool = _em.deduct(0, 9999, "build")
    if not result:
        print("    PASS: deduct returns false when insufficient")
    else:
        print("    FAIL: deduct returned true")


func test_can_afford():
    if _em == null:
        print("    FAIL: EconomyManager not injected")
        return
    _em.add(0, 500, "test")
    if _em.can_afford(0, 300):
        print("    PASS: can_afford returns true when sufficient")
    else:
        print("    FAIL: can_afford returned false")
    if not _em.can_afford(0, 9999):
        print("    PASS: can_afford returns false when insufficient")
    else:
        print("    FAIL: can_afford returned true for impossible cost")


func test_multiple_players():
    if _em == null:
        print("    FAIL: EconomyManager not injected")
        return
    _em.add(0, 100, "test")
    _em.add(1, 200, "test")
    if _em.get_balance(0) != _em.get_balance(1):
        print("    PASS: players have independent balances")
    else:
        print("    FAIL: players have same balance")
