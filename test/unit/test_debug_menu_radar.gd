extends Node

# DebugMenu radar override tests — the Force radar online cheat drives
# RadarSystem.force_online and resets with the scene.

const DEBUG_MENU_SCENE: PackedScene = preload("res://scenes/ui/DebugMenu.tscn")


func _make_menu() -> DebugMenu:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    var menu := DEBUG_MENU_SCENE.instantiate() as DebugMenu
    tree.root.add_child(menu)
    return menu


func test_force_radar_toggle_sets_system_and_reset_clears():
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    var system := tree.root.get_node_or_null("RadarSystem")
    if system == null:
        TestHelper.fail("RadarSystem autoload missing")
        return
    system.force_online = false
    var menu := _make_menu()
    menu.cb_force_radar.button_pressed = true
    TestHelper.assert_true(system.force_online, "checkbox enables the radar override")
    menu.reset_state()
    TestHelper.assert_true(not system.force_online, "scene reset clears the radar override")
    TestHelper.assert_true(
        not menu.cb_force_radar.button_pressed, "scene reset unchecks the checkbox"
    )
    menu.free()
    system.force_online = false
