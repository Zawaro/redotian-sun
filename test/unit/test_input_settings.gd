extends Node

# InputSettings unit tests — config load/save, remap_action, get_key_text

var _test_passed := 0
var _test_failed := 0


func _get_is() -> Node:
    var tree := Engine.get_main_loop() as SceneTree
    if not tree:
        return null
    return tree.root.get_node_or_null("InputSettings")


func test_default_edge_scroll_enabled():
    var is_node := _get_is()
    if is_node == null:
        _test_failed += 1
        print("    FAIL: InputSettings not injected")
        return
    TestHelper.assert_eq(is_node.edge_scroll_enabled, true, "edge_scroll_enabled defaults to true")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_remap_action_applies_binding():
    var is_node := _get_is()
    if is_node == null:
        _test_failed += 1
        print("    FAIL: InputSettings not injected")
        return
    var original := InputMap.action_get_events("camera_up")
    is_node.remap_action("camera_up", "Kp 8")
    var events := InputMap.action_get_events("camera_up")
    var has_key := events.size() == 1 and events[0] is InputEventKey
    var applied := has_key and (events[0] as InputEventKey).physical_keycode == KEY_KP_8
    InputMap.action_erase_events("camera_up")
    for ev in original:
        InputMap.action_add_event("camera_up", ev)
    TestHelper.assert_true(applied, "remap_action applies Numpad8 binding")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_remap_action_invalid_key():
    var is_node := _get_is()
    if is_node == null:
        _test_failed += 1
        print("    FAIL: InputSettings not injected")
        return
    var original_size := InputMap.action_get_events("camera_up").size()
    is_node.remap_action("camera_up", "NotARealKey")
    var rejected := InputMap.action_get_events("camera_up").size() == original_size
    TestHelper.assert_true(rejected, "remap_action rejects invalid key name")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_get_key_text():
    var is_node := _get_is()
    if is_node == null:
        _test_failed += 1
        print("    FAIL: InputSettings not injected")
        return
    var original := InputMap.action_get_events("camera_up")
    is_node.remap_action("camera_up", "W")
    var text: String = is_node.get_key_text("camera_up")
    InputMap.action_erase_events("camera_up")
    for ev in original:
        InputMap.action_add_event("camera_up", ev)
    TestHelper.assert_eq(text, "W", "get_key_text returns W")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
