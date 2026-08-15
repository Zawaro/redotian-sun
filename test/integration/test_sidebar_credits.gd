extends Node

# Integration tests for the sidebar HUD credits label. Regression guard: the
# credits_changed signal gained a category argument (player_id, new_balance,
# reason, category), and the Sidebar handler must accept all four — otherwise
# Redot aborts the call and the counter silently freezes while the refinery
# storage bar keeps filling.

const SIDEBAR_SCENE: PackedScene = preload("res://scenes/ui/Sidebar.tscn")

var _em: Node = null
var _pm: Node = null


func _ready() -> void:
    _em = get_node_or_null("/root/EconomyManager")
    _pm = get_node_or_null("/root/PlayerManager")


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func test_credits_label_updates_on_credits_changed():
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
        sidebar.queue_free()
        return

    em.credits_changed.emit(local_pid, 1234, "harvest", "tiberium")
    (
        TestHelper
        . assert_eq(
            label.text,
            "$1234",
            "HUD counter updates from the 4-argument credits_changed signal",
        )
    )

    sidebar.queue_free()


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
        sidebar.queue_free()
        return

    var before: String = label.text
    em.credits_changed.emit(local_pid + 99, 999999, "harvest", "tiberium")
    TestHelper.assert_eq(
        label.text, before, "HUD counter ignores credits_changed for other players"
    )

    sidebar.queue_free()
