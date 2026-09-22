extends Node

# PauseMenu briefing entry — the Briefing button is gated on an active mission
# and emits `briefing_requested` when pressed. Complements test_pause_menu.gd
# without touching its existing assertions.

const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/PauseMenu.tscn")

var _gc: Node = null


func _guard() -> bool:
    if _gc == null:
        TestHelper.fail("GameContext not injected")
        return false
    return true


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _make_menu() -> Control:
    var menu: Control = PAUSE_SCENE.instantiate() as Control
    _tree().root.add_child(menu)
    return menu


func _briefing_button(menu: Control) -> Button:
    return menu.get_node_or_null("%BriefingButton") as Button


func _teardown(menu: Control) -> void:
    _gc.current_mission = null
    _tree().paused = false
    if is_instance_valid(menu):
        _tree().root.remove_child(menu)
        menu.free()


func test_briefing_disabled_without_mission() -> void:
    if not _guard():
        return
    _gc.current_mission = null
    var menu := _make_menu()
    var button := _briefing_button(menu)
    TestHelper.assert_true(button != null, "BriefingButton exists")
    if button:
        TestHelper.assert_true(button.disabled, "Briefing button disabled with no mission")
    _teardown(menu)


func test_briefing_enabled_with_mission() -> void:
    if not _guard():
        return
    var mission := Mission.new()
    mission.id = "briefing_test"
    _gc.current_mission = mission
    var menu := _make_menu()
    var button := _briefing_button(menu)
    TestHelper.assert_true(button != null, "BriefingButton exists")
    if button:
        TestHelper.assert_true(not button.disabled, "Briefing button enabled with a mission")
    _teardown(menu)


func test_pressing_briefing_emits_requested() -> void:
    if not _guard():
        return
    var mission := Mission.new()
    mission.id = "briefing_test"
    _gc.current_mission = mission
    var menu := _make_menu()
    var button := _briefing_button(menu)
    TestHelper.assert_true(button != null, "BriefingButton exists")
    if button == null:
        _teardown(menu)
        return
    var requested := [false]
    menu.connect("briefing_requested", func() -> void: requested[0] = true)
    button.pressed.emit()
    TestHelper.assert_true(requested[0], "pressing Briefing emits briefing_requested")
    _teardown(menu)
