extends Node

# BriefingDialog integration — content display, the pre-mission auto-show gate,
# pause ownership on close, and the pause-menu entry path that stays paused.
# Every test unpauses and clears the active mission so later suites are clean.

const BRIEFING_SCENE: PackedScene = preload("res://scenes/ui/BriefingDialog.tscn")
const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/PauseMenu.tscn")

var _gc: Node = null


func _guard() -> bool:
    if _gc == null:
        TestHelper.fail("GameContext not injected")
        return false
    return true


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _make_mission(show_briefing: bool, title: String, body: String) -> Mission:
    var mission := Mission.new()
    mission.id = "briefing_test"
    mission.display_name = title
    mission.briefing = body
    mission.show_briefing = show_briefing
    return mission


func _show_dialog() -> Control:
    var dialog: Control = BRIEFING_SCENE.instantiate() as Control
    _tree().root.add_child(dialog)
    return dialog


func _pause_event() -> InputEventAction:
    var ev := InputEventAction.new()
    ev.action = "pause"
    ev.pressed = true
    return ev


func _close(dialog: Control) -> void:
    var close_button: Button = dialog.get_node_or_null("%CloseButton") as Button
    if close_button:
        close_button.pressed.emit()


func _teardown(dialog: Control) -> void:
    _gc.current_mission = null
    _tree().paused = false
    if is_instance_valid(dialog):
        _tree().root.remove_child(dialog)
        dialog.free()


func test_briefing_shows_mission_text() -> void:
    if not _guard():
        return
    _tree().paused = false
    var mission := _make_mission(false, "Reinforce Phoenix Base", "Reinforce Phoenix Base.")
    _gc.current_mission = mission
    var dialog := _show_dialog()
    dialog.call("show_for_mission", mission, false)
    var title := dialog.get("title_label") as Label
    var body := dialog.get("body_label") as Label
    TestHelper.assert_true(dialog.visible, "briefing visible after show")
    TestHelper.assert_eq(title.text, "Reinforce Phoenix Base", "title shows display name")
    TestHelper.assert_eq(body.text, "Reinforce Phoenix Base.", "body shows briefing text")
    _teardown(dialog)


func test_briefing_replaces_previous_content() -> void:
    if not _guard():
        return
    _tree().paused = false
    var first := _make_mission(false, "First", "First briefing")
    var second := _make_mission(false, "Second", "Second briefing")
    _gc.current_mission = second
    var dialog := _show_dialog()
    dialog.call("show_for_mission", first, false)
    dialog.call("show_for_mission", second, false)
    var title := dialog.get("title_label") as Label
    var body := dialog.get("body_label") as Label
    TestHelper.assert_eq(title.text, "Second", "second show replaces the title")
    TestHelper.assert_eq(body.text, "Second briefing", "second show replaces the body")
    _teardown(dialog)


func test_auto_show_when_enabled_pauses() -> void:
    if not _guard():
        return
    _tree().paused = false
    var mission := _make_mission(true, "Auto", "Auto briefing")
    _gc.current_mission = mission
    var dialog := _show_dialog()
    TestHelper.assert_true(dialog.visible, "show_briefing true auto-shows the dialog")
    TestHelper.assert_true(_tree().paused, "pre-mission briefing pauses the tree")
    _close(dialog)
    TestHelper.assert_true(not dialog.visible, "closing hides the dialog")
    TestHelper.assert_true(not _tree().paused, "closing the pre-mission briefing unpauses")
    _teardown(dialog)


func test_auto_show_skipped_when_disabled() -> void:
    if not _guard():
        return
    _tree().paused = false
    var mission := _make_mission(false, "Skipped", "Skipped briefing")
    _gc.current_mission = mission
    var dialog := _show_dialog()
    TestHelper.assert_true(not dialog.visible, "show_briefing false keeps the dialog hidden")
    TestHelper.assert_true(not _tree().paused, "no briefing means no pause")
    _teardown(dialog)


func test_pause_menu_briefing_stays_paused() -> void:
    if not _guard():
        return
    _tree().paused = false
    var mission := _make_mission(false, "Pause Briefing", "From pause menu")
    _gc.current_mission = mission
    var dialog := _show_dialog()
    dialog.call("show_for_mission", mission, true)
    TestHelper.assert_true(dialog.visible, "pause-menu briefing shows")
    TestHelper.assert_true(_tree().paused, "pause-menu briefing keeps the tree paused")
    _close(dialog)
    TestHelper.assert_true(not dialog.visible, "closing hides the pause-menu briefing")
    TestHelper.assert_true(_tree().paused, "closing a pause-menu briefing stays paused")
    _teardown(dialog)


func test_null_mission_is_a_noop() -> void:
    if not _guard():
        return
    _tree().paused = false
    _gc.current_mission = null
    var dialog := _show_dialog()
    dialog.call("show_for_mission", null, false)
    TestHelper.assert_true(not dialog.visible, "null mission does not show the dialog")
    TestHelper.assert_true(not _tree().paused, "null mission does not pause")
    _teardown(dialog)


func test_escape_closes_pre_mission_briefing() -> void:
    if not _guard():
        return
    _tree().paused = false
    var mission := _make_mission(false, "T", "B")
    _gc.current_mission = mission
    var dialog := _show_dialog()
    dialog.call("show_for_mission", mission, false)
    dialog._input(_pause_event())
    TestHelper.assert_true(not dialog.visible, "ESC hides a pre-mission briefing")
    TestHelper.assert_true(not _tree().paused, "ESC on a pre-mission briefing unpauses")
    _teardown(dialog)


func test_escape_closes_pause_menu_briefing_stays_paused() -> void:
    if not _guard():
        return
    _tree().paused = false
    var mission := _make_mission(false, "T", "B")
    _gc.current_mission = mission
    var dialog := _show_dialog()
    dialog.call("show_for_mission", mission, true)
    dialog._input(_pause_event())
    TestHelper.assert_true(not dialog.visible, "ESC hides a pause-menu briefing")
    TestHelper.assert_true(_tree().paused, "ESC on a pause-menu briefing stays paused")
    _teardown(dialog)


func test_escape_ignored_when_hidden() -> void:
    if not _guard():
        return
    _tree().paused = false
    var mission := _make_mission(false, "Hidden", "Hidden")
    _gc.current_mission = mission
    var dialog := _show_dialog()
    dialog._input(_pause_event())
    TestHelper.assert_true(not dialog.visible, "ESC leaves a hidden briefing hidden")
    TestHelper.assert_true(not _tree().paused, "ESC on a hidden briefing does not pause")
    _teardown(dialog)


func test_pause_menu_briefing_request_shows_dialog() -> void:
    if not _guard():
        return
    _tree().paused = false
    _gc.current_mission = _make_mission(false, "Wired", "B")
    var host := Node.new()
    _tree().root.add_child(host)
    var pause_menu: Control = PAUSE_SCENE.instantiate() as Control
    host.add_child(pause_menu)
    var dialog: Control = BRIEFING_SCENE.instantiate() as Control
    host.add_child(dialog)
    (pause_menu as Object).emit_signal("briefing_requested")
    TestHelper.assert_true(dialog.visible, "pause-menu request shows the briefing")
    TestHelper.assert_true(_tree().paused, "pause-menu briefing keeps the tree paused")
    _gc.current_mission = null
    _tree().paused = false
    _tree().root.remove_child(host)
    host.free()
