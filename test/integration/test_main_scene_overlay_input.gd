extends Node

# Regression test for the MainScene menu-overlay click blocker.
#
# MainScene's menu overlay container (`HUD/UI`) sits above the gameplay HUD
# (both CanvasLayers use layer 256; the menu layer is a later sibling and so
# draws on top). When that container kept the default Control mouse filter
# (STOP) it swallowed every mouse click aimed at gameplay UI — the mission
# briefing's button was visible but unclickable.
#
# The container MUST NOT intercept mouse input; only its own visible children
# (menus, dialogs) may. This test fails on the broken scene and passes once the
# container ignores the mouse.

const MAIN_SCENE: String = "res://scenes/MainScene.tscn"


func test_menu_overlay_container_ignores_mouse() -> void:
    var scene := (load(MAIN_SCENE) as PackedScene).instantiate()
    var ui := scene.get_node_or_null("HUD/UI") as Control
    TestHelper.assert_true(ui != null, "MainScene has a HUD/UI overlay container")
    if ui == null:
        scene.free()
        return
    (
        TestHelper
        . assert_eq(
            ui.mouse_filter,
            Control.MOUSE_FILTER_IGNORE,
            "menu overlay container must not consume gameplay clicks",
        )
    )
    scene.free()


func test_menu_overlay_container_is_full_rect() -> void:
    var scene := (load(MAIN_SCENE) as PackedScene).instantiate()
    var ui := scene.get_node_or_null("HUD/UI") as Control
    if ui == null:
        TestHelper.fail("MainScene has no HUD/UI overlay container")
        scene.free()
        return
    # Full-rect is why an overlay with the default filter blocked gameplay
    # everywhere, not just under a visible menu. The container stays full-rect;
    # the mouse filter is what makes it safe.
    TestHelper.assert_true(ui.anchor_right == 1.0, "overlay spans the width")
    TestHelper.assert_true(ui.anchor_bottom == 1.0, "overlay spans the height")
    scene.free()


func test_main_menu_still_loads() -> void:
    # Guard against a fix that removes the menu: MainMenu01 remains an overlay child.
    var scene := (load(MAIN_SCENE) as PackedScene).instantiate()
    var menu := scene.get_node_or_null("HUD/UI/MainMenu01") as Control
    TestHelper.assert_true(menu != null, "MainMenu01 is still a child of the overlay")
    scene.free()


func test_main_scene_root_is_not_a_subviewport() -> void:
    # A Window/SubViewport root renders gameplay into its own viewport, so the
    # autoload overlays that live in the root viewport (SelectionOverlay brackets,
    # MoveLineRenderer move lines, FogRenderer) resolve no camera and draw
    # underneath gameplay. The entry scene must be a plain Node so gameplay and
    # the overlays share the root viewport.
    var scene := (load(MAIN_SCENE) as PackedScene).instantiate()
    (
        TestHelper
        . assert_true(
            not (scene is Window) and not (scene is SubViewport),
            "MainScene root must not be a sub-viewport",
        )
    )
    TestHelper.assert_true(scene is Node, "MainScene root is a Node")
    scene.free()
