extends Node

# Integration tests for the sidebar HUD credits counter. Regression guard: the
# credits_changed signal gained a category argument (player_id, new_balance,
# reason, category), and the Sidebar handler must accept all four — otherwise
# Redot aborts the call and the counter silently freezes while the refinery
# storage bar keeps filling.
#
# The counter animates toward the target balance, so tests drive
# Sidebar._step_counter with synthetic deltas instead of awaiting frames.

const SIDEBAR_SCENE: PackedScene = preload("res://scenes/ui/Sidebar.tscn")

var _em: Node = null
var _pm: Node = null


func _ready() -> void:
    _em = get_node_or_null("/root/EconomyManager")
    _pm = get_node_or_null("/root/PlayerManager")


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func test_credits_label_shows_balance_on_ready():
    var em: Node = _em
    if not em:
        TestHelper.fail("EconomyManager autoload missing")
        return
    var sidebar: Control = SIDEBAR_SCENE.instantiate()
    _tree().root.add_child(sidebar)

    var label := sidebar.get_node_or_null("%CreditsLabel") as Label
    TestHelper.assert_true(label != null, "Sidebar has a %CreditsLabel node")
    if not label:
        sidebar.free()
        return

    (
        TestHelper
        . assert_eq(
            label.text,
            "$%d" % em.get_balance(_pm.get_local_player_id()),
            "HUD counter shows the current balance immediately on ready",
        )
    )

    sidebar.free()


func test_credits_label_settles_on_credits_changed():
    var em: Node = _em
    if not em:
        TestHelper.fail("EconomyManager autoload missing")
        return
    var local_pid: int = _pm.get_local_player_id()
    var sidebar: Control = SIDEBAR_SCENE.instantiate()
    _tree().root.add_child(sidebar)

    var label := sidebar.get_node_or_null("%CreditsLabel") as Label
    TestHelper.assert_true(label != null, "Sidebar has a %CreditsLabel node")
    if not label:
        sidebar.free()
        return

    sidebar.call("_force_display_credits", 234)
    em.credits_changed.emit(local_pid, 1234, "harvest", "tiberium")
    TestHelper.assert_true(
        label.text != "$1234", "HUD counter does not jump straight to the new balance"
    )

    # A wrong handler signature aborts the emit and the target is never stored,
    # so this settle loop is the actual regression guard for the 4-arg signal.
    var calls := 0
    while label.text != "$1234" and calls < 1000:
        sidebar.call("_step_counter", 0.05)
        calls += 1
    TestHelper.assert_eq(
        label.text, "$1234", "HUD counter settles at the target from the 4-argument signal"
    )

    sidebar.free()


func test_credits_label_ignores_other_players():
    var em: Node = _em
    if not em:
        TestHelper.fail("EconomyManager autoload missing")
        return
    var local_pid: int = _pm.get_local_player_id()
    var sidebar: Control = SIDEBAR_SCENE.instantiate()
    _tree().root.add_child(sidebar)

    var label := sidebar.get_node_or_null("%CreditsLabel") as Label
    TestHelper.assert_true(label != null, "Sidebar has a %CreditsLabel node")
    if not label:
        sidebar.free()
        return

    var before: String = label.text
    em.credits_changed.emit(local_pid + 99, 999999, "harvest", "tiberium")
    for i in range(10):
        sidebar.call("_step_counter", 0.1)
    TestHelper.assert_eq(
        label.text, before, "HUD counter ignores credits_changed for other players"
    )

    sidebar.free()
