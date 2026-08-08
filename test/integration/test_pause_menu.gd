extends Node

# Integration tests for the pause system — ESC toggles a global pause, the
# menu stays interactive while paused, and ESC first belongs to cancel-modes.
# The runner calls test methods synchronously and test objects are NOT added to
# the tree, so the tree is reached via Engine.get_main_loop() and pause state
# is asserted via Node.can_process() (reflects pause + process_mode) instead of
# awaited frames.

const PAUSE_SCENE: PackedScene = preload("res://scenes/ui/PauseMenu.tscn")
const MOUSE_HANDLER_SCENE: PackedScene = preload("res://scenes/hud/MouseHandler.tscn")

var _bm: Node = null


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _make_esc_event() -> InputEventKey:
    var ev := InputEventKey.new()
    ev.physical_keycode = KEY_ESCAPE
    ev.pressed = true
    return ev


func test_pause_action_registered():
    TestHelper.assert_true(InputMap.has_action("pause"), "pause action exists in InputMap")


func test_escape_toggles_pause_and_menu():
    TestHelper.assert_true(InputMap.has_action("pause"), "pause action present")
    var bm: Node = _bm
    if bm:
        bm.is_build_mode = false
    var tree := _tree()
    tree.paused = false
    var menu: Control = PAUSE_SCENE.instantiate()
    tree.root.add_child(menu)
    TestHelper.assert_true(not tree.paused, "tree starts unpaused")
    TestHelper.assert_true(not menu.visible, "menu starts hidden")

    var pausable := Node.new()
    tree.root.add_child(pausable)
    TestHelper.assert_true(pausable.can_process(), "pausable node processes before pause")
    TestHelper.assert_true(menu.can_process(), "menu processes before pause")

    menu._unhandled_input(_make_esc_event())
    TestHelper.assert_true(tree.paused, "ESC pauses the tree")
    TestHelper.assert_true(menu.visible, "ESC shows the pause menu")
    TestHelper.assert_true(not pausable.can_process(), "pausable node stops while paused")
    TestHelper.assert_true(menu.can_process(), "menu still processes while paused")

    menu._unhandled_input(_make_esc_event())
    TestHelper.assert_true(not tree.paused, "second ESC resumes the tree")
    TestHelper.assert_true(not menu.visible, "second ESC hides the pause menu")
    TestHelper.assert_true(pausable.can_process(), "pausable node resumes after unpause")

    pausable.queue_free()
    menu.queue_free()


func test_escape_does_not_pause_during_build_mode():
    TestHelper.assert_true(InputMap.has_action("pause"), "pause action present")
    var bm: Node = _bm
    TestHelper.assert_true(bm != null, "BuildingManager autoload present")
    if bm == null:
        return
    var tree := _tree()
    var menu: Control = PAUSE_SCENE.instantiate()
    tree.root.add_child(menu)

    var prev_build_mode: bool = bm.is_build_mode
    bm.is_build_mode = true
    menu._unhandled_input(_make_esc_event())
    TestHelper.assert_true(not tree.paused, "ESC in build mode does not pause")
    TestHelper.assert_true(not menu.visible, "menu stays hidden during build mode")

    bm.is_build_mode = prev_build_mode
    tree.paused = false
    menu.visible = false
    menu.queue_free()


func test_resume_button_unpauses():
    TestHelper.assert_true(InputMap.has_action("pause"), "pause action present")
    var bm: Node = _bm
    if bm:
        bm.is_build_mode = false
    var tree := _tree()
    tree.paused = false
    var menu: Control = PAUSE_SCENE.instantiate()
    tree.root.add_child(menu)
    menu._unhandled_input(_make_esc_event())
    TestHelper.assert_true(tree.paused, "paused via ESC before button test")
    var resume: Button = menu.get_node_or_null("%ResumeButton") as Button
    TestHelper.assert_true(resume != null, "ResumeButton exists")
    if resume:
        resume.pressed.emit()
        TestHelper.assert_true(not tree.paused, "Return to game resumes the tree")
        TestHelper.assert_true(not menu.visible, "Return to game hides the menu")
    tree.paused = false
    menu.visible = false
    menu.queue_free()


func test_quit_button_wired_to_quit_handler():
    var tree := _tree()
    var menu: Control = PAUSE_SCENE.instantiate()
    tree.root.add_child(menu)
    var quit: Button = menu.get_node_or_null("%QuitButton") as Button
    TestHelper.assert_true(quit != null, "QuitButton exists")
    if quit:
        (
            TestHelper
            . assert_true(
                quit.pressed.is_connected(Callable(menu, "_on_quit_pressed")),
                "Quit to desktop is wired to the quit handler",
            )
        )
    tree.paused = false
    menu.queue_free()


func test_pause_resets_mouse_drag_state():
    # Pausing mid box-select swallows the mouse-release (input gated by
    # process_mode); MouseHandler resets on NOTIFICATION_PAUSED so no stuck drag.
    var tree := _tree()
    var mh: Control = MOUSE_HANDLER_SCENE.instantiate()
    tree.root.add_child(mh)
    mh.mouse_dragging = true
    mh.active_rect = Rect2(10, 10, 40, 40)
    mh.selection_rect.visible = true
    mh._current_cursor = CursorState.Type.ATTACK
    mh.notification(Node.NOTIFICATION_PAUSED)
    TestHelper.assert_true(not mh.mouse_dragging, "pause clears mouse drag state")
    TestHelper.assert_true(not mh.selection_rect.visible, "pause hides the selection rect")
    TestHelper.assert_eq(mh.active_rect, Rect2(), "pause clears the active drag rect")
    TestHelper.assert_eq(
        mh._current_cursor, CursorState.Type.DEFAULT, "pause forces the default cursor"
    )
    tree.paused = false
    mh.queue_free()


func test_unpause_arms_input_debounce():
    # The click that resumes the game is still visible to the Input singleton on
    # the unpause frame; MouseHandler must skip a couple of frames so it is not
    # processed as a gameplay click (move order to the selection).
    var tree := _tree()
    var mh: Control = MOUSE_HANDLER_SCENE.instantiate()
    tree.root.add_child(mh)
    mh.notification(Node.NOTIFICATION_UNPAUSED)
    TestHelper.assert_eq(mh._skip_input_frames, 2, "unpause arms a 2-frame input debounce")
    mh._process(0.0)
    TestHelper.assert_eq(mh._skip_input_frames, 1, "first skipped frame drains the debounce")
    mh._process(0.0)
    TestHelper.assert_eq(mh._skip_input_frames, 0, "second skipped frame drains the debounce")
    tree.paused = false
    mh.queue_free()


func test_pause_does_not_arm_debounce():
    var tree := _tree()
    var mh: Control = MOUSE_HANDLER_SCENE.instantiate()
    tree.root.add_child(mh)
    mh.notification(Node.NOTIFICATION_PAUSED)
    TestHelper.assert_eq(mh._skip_input_frames, 0, "pausing does not arm the input debounce")
    tree.paused = false
    mh.queue_free()
