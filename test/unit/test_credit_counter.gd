extends Node

# CreditCounter resync + insufficient-funds color tests
# (openspec/specs/credit-ui/spec.md). The counter is CreditCounter on CreditsLabel.

const CREDITS_SCENE: PackedScene = preload("res://scenes/ui/CreditsLabel.tscn")

var _em: Node = null


func _ready() -> void:
    _em = get_node_or_null("/root/EconomyManager")


func _make_counter() -> Control:
    var label: Control = CREDITS_SCENE.instantiate()
    (Engine.get_main_loop() as SceneTree).root.add_child(label)
    return label


func _drop_counter(counter: Control) -> void:
    if counter and is_instance_valid(counter):
        counter.free()


## Force the local player's balance to an exact value, isolated from other suites.
func _set_local_balance(amount: int) -> void:
    var data: PlayerData = PlayerManager.get_player_data(PlayerManager.get_local_player_id())
    data.free_credits = amount
    data.stored_by_category.clear()


func test_ready_shows_local_balance():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var counter := _make_counter()
    var balance: int = _em.get_balance(PlayerManager.get_local_player_id())
    TestHelper.assert_eq((counter as Label).text, "$%d" % balance, "ready shows current balance")
    _drop_counter(counter)


## A roster rebuild (mission start) must replace a stale balance on screen.
func test_players_changed_resyncs_label():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var counter := _make_counter()
    _set_local_balance(4321)
    PlayerManager.players_changed.emit()
    TestHelper.assert_eq(
        (counter as Label).text, "$4321", "players_changed resyncs the label instantly"
    )
    _drop_counter(counter)


func test_insufficient_funds_color_threshold():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var counter := _make_counter()
    var cheapest: int = counter.get("_cheapest_cost")
    if cheapest <= 0:
        TestHelper.fail("no buildable entity to derive the cheapest cost")
        _drop_counter(counter)
        return
    _set_local_balance(cheapest - 1)
    counter.call("_update_credits_color")
    var below: Color = counter.get_theme_color("font_color")
    _set_local_balance(cheapest)
    counter.call("_update_credits_color")
    var at: Color = counter.get_theme_color("font_color")
    (
        TestHelper
        . assert_true(
            below == Color(1, 0.3, 0.3, 1) and at == Color(1, 1, 1, 1),
            "counter is red below the cheapest buildable cost and white at/above it",
        )
    )
    _drop_counter(counter)
