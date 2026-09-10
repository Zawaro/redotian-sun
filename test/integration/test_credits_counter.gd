extends Node

# Integration tests for the HUD credit counter (now a standalone HUD node above
# the minimap, extracted from Sidebar.tscn). Regression guard: the
# credits_changed signal gained a category argument (player_id, new_balance,
# reason, category), and the handler must accept all four — otherwise Redot
# aborts the call and the counter silently freezes while the refinery storage bar
# keeps filling.
#
# The counter animates toward the target balance, so tests drive
# CreditCounter._step_counter with synthetic deltas instead of awaiting frames.

const CREDITS_SCENE: PackedScene = preload("res://scenes/ui/CreditsLabel.tscn")

var _em: Node = null
var _pm: Node = null


func _ready() -> void:
    _em = get_node_or_null("/root/EconomyManager")
    _pm = get_node_or_null("/root/PlayerManager")


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _make_label() -> Label:
    return CREDITS_SCENE.instantiate() as Label


func test_credits_label_shows_balance_on_ready():
    var em: Node = _em
    if not em:
        TestHelper.fail("EconomyManager autoload missing")
        return
    var label := _make_label()
    _tree().root.add_child(label)

    TestHelper.assert_true(label != null, "CreditsLabel scene has a Label root")
    if not label:
        return
    (
        TestHelper
        . assert_eq(
            label.text,
            "$%d" % em.get_balance(_pm.get_local_player_id()),
            "HUD counter shows the current balance immediately on ready",
        )
    )

    label.free()


func test_credits_label_settles_on_credits_changed():
    var em: Node = _em
    if not em:
        TestHelper.fail("EconomyManager autoload missing")
        return
    var local_pid: int = _pm.get_local_player_id()
    var label := _make_label()
    _tree().root.add_child(label)

    TestHelper.assert_true(label != null, "CreditsLabel scene has a Label root")
    if not label:
        return

    label.call("_force_display_credits", 234)
    em.credits_changed.emit(local_pid, 1234, "harvest", "tiberium")
    TestHelper.assert_true(
        label.text != "$1234", "HUD counter does not jump straight to the new balance"
    )

    # A wrong handler signature aborts the emit and the target is never stored,
    # so this settle loop is the actual regression guard for the 4-arg signal.
    var calls := 0
    while label.text != "$1234" and calls < 1000:
        label.call("_step_counter", 0.05)
        calls += 1
    TestHelper.assert_eq(
        label.text, "$1234", "HUD counter settles at the target from the 4-argument signal"
    )

    label.free()


func test_credits_label_ignores_other_players():
    var em: Node = _em
    if not em:
        TestHelper.fail("EconomyManager autoload missing")
        return
    var local_pid: int = _pm.get_local_player_id()
    var label := _make_label()
    _tree().root.add_child(label)

    TestHelper.assert_true(label != null, "CreditsLabel scene has a Label root")
    if not label:
        return

    var before: String = label.text
    em.credits_changed.emit(local_pid + 99, 999999, "harvest", "tiberium")
    for i in range(10):
        label.call("_step_counter", 0.1)
    TestHelper.assert_eq(
        label.text, before, "HUD counter ignores credits_changed for other players"
    )

    label.free()
