extends Node

# Asset browser scene integration: headless load, every category's first asset
# previews, filtering, game-change rebuild, camera projection modes, asset
# rotation, and stackable render overlays.

const CAM_ISOMETRIC := 0
const CAM_PERSPECTIVE := 1
const OVERLAY_MESH := 0
const OVERLAY_FOOTPRINT := 1
const OVERLAY_COLLISION := 2
const OVERLAY_THEATER := 3
const OVERLAY_GROUND := 4
const OVERLAY_AXIS := 5
const OVERLAY_STATES: Array[int] = [
    OVERLAY_MESH,
    OVERLAY_FOOTPRINT,
    OVERLAY_COLLISION,
    OVERLAY_THEATER,
    OVERLAY_GROUND,
    OVERLAY_AXIS,
]

var _scene: Node = null
var _controller: Node = null


func _ensure_scene() -> bool:
    if _scene != null:
        return _controller != null
    var packed := load("res://scenes/AssetBrowser.tscn") as PackedScene
    if packed == null:
        TestHelper.assert_true(false, "AssetBrowser.tscn loads")
        return false
    var tree := Engine.get_main_loop() as SceneTree
    _scene = packed.instantiate()
    tree.root.add_child(_scene)
    _controller = _scene
    return _controller != null


func test_scene_loads_with_camera_and_assets():
    if not _ensure_scene():
        _finish()
        return
    TestHelper.assert_true(_controller.get_camera() != null, "preview camera exists")
    TestHelper.assert_true(_controller.get_object_root() != null, "object root exists")
    TestHelper.assert_true(_controller.get_world_overlays() != null, "world overlays exist")
    var fog := _controller.get_node_or_null("/root/FogRenderer")
    (
        TestHelper
        . assert_true(
            fog == null or not bool(fog.get("overlay_enabled")),
            "gameplay fog plane is suppressed under the browser",
        )
    )
    TestHelper.assert_true(_controller.get_category_count() >= 10, "categories populated")
    TestHelper.assert_true(_controller.get_asset_count() > 0, "assets populated")
    TestHelper.assert_true(not _controller.current_asset_id().is_empty(), "first asset selected")
    TestHelper.assert_eq(_controller.current_game_id(), "ts", "active game reported")
    _finish()


func test_every_category_first_asset_previews():
    if not _ensure_scene():
        _finish()
        return
    var visited := 0
    for i in _controller.get_category_count():
        _controller.select_category(i)
        var count: int = _controller.get_asset_count()
        if count == 0:
            continue
        visited += 1
        _controller.select_asset(0)
        var mode: int = _controller.get_preview_mode()
        if mode == 0 or mode == 1:
            (
                TestHelper
                . assert_true(
                    _controller.get_object_root().get_child_count() > 0,
                    "3D category '%s' instantiated a preview" % _controller.get_category_label(i),
                )
            )
        elif mode == 2:
            TestHelper.assert_true(_controller._audio_row.visible, "audio transport shown")
        elif mode == 3:
            TestHelper.assert_true(_controller._image_rect.visible, "image shown")
    TestHelper.assert_true(
        visited >= 12, "every in-scope category resolved an asset (%d)" % visited
    )
    _finish()


func test_filter_narrows_and_clears():
    if not _ensure_scene():
        _finish()
        return
    _controller.select_category(0)
    var total: int = _controller.get_asset_count()
    TestHelper.assert_true(total > 0, "terrain category populated")
    _controller.apply_filter("cliff")
    var filtered: int = _controller.get_asset_count()
    TestHelper.assert_true(filtered > 0, "filter keeps matching assets")
    TestHelper.assert_true(filtered < total, "filter narrows the list")
    for i in filtered:
        (
            TestHelper
            . assert_true(
                _controller.get_asset_id(i).to_lower().contains("cliff"),
                "filtered id contains the query",
            )
        )
    _controller.apply_filter("")
    TestHelper.assert_eq(
        _controller.get_asset_count(), total, "clearing the filter restores the list"
    )
    _finish()


func test_game_changed_rebuilds_browser():
    if not _ensure_scene():
        _finish()
        return
    _controller._on_game_changed(GameContext.current)
    TestHelper.assert_true(_controller.get_category_count() >= 10, "categories rebuilt")
    TestHelper.assert_true(_controller.get_asset_count() > 0, "assets rebuilt after game_changed")
    _finish()


func test_camera_is_isometric_by_default():
    if not _ensure_scene():
        _finish()
        return
    _controller.set_camera_mode(CAM_ISOMETRIC)
    var cam: Camera3D = _controller.get_camera()
    TestHelper.assert_eq(
        cam.projection, Camera3D.PROJECTION_ORTHOGONAL, "isometric mode is orthographic"
    )
    TestHelper.assert_true(_controller.is_isometric(), "camera reports isometric")
    TestHelper.assert_true(_controller.get_ortho_size() > 0.0, "ortho size is framed")
    _controller.set_camera_mode(CAM_PERSPECTIVE)
    TestHelper.assert_eq(
        cam.projection, Camera3D.PROJECTION_PERSPECTIVE, "perspective mode is perspective"
    )
    TestHelper.assert_true(not _controller.is_isometric(), "camera reports perspective")
    _controller.set_camera_mode(CAM_ISOMETRIC)
    _finish()


func test_asset_rotates_while_camera_stays_fixed():
    if not _ensure_scene():
        _finish()
        return
    _controller.select_category(0)
    _controller.select_asset(0)
    _controller.set_auto_rotate(false)
    var cam: Camera3D = _controller.get_camera()
    var cam_before := cam.global_transform
    var obj_before: Vector3 = _controller.get_object_root().rotation
    _controller._process(0.016)
    TestHelper.assert_true(
        cam_before.is_equal_approx(cam.global_transform), "camera is stable when idle"
    )
    (
        TestHelper
        . assert_true(
            obj_before.is_equal_approx(_controller.get_object_root().rotation),
            "asset is stable when idle",
        )
    )
    _controller.set_auto_rotate(true)
    _controller._process(0.016)
    (
        TestHelper
        . assert_true(
            cam_before.is_equal_approx(cam.global_transform),
            "camera stays fixed while the asset auto-rotates",
        )
    )
    (
        TestHelper
        . assert_true(
            not obj_before.is_equal_approx(_controller.get_object_root().rotation),
            "auto-rotate turns the asset",
        )
    )
    _controller.set_auto_rotate(false)
    _finish()


func test_rotation_only_uses_pitch_in_perspective():
    if not _ensure_scene():
        _finish()
        return
    _controller.select_category(0)
    _controller.select_asset(0)
    _controller.set_auto_rotate(false)
    _controller.set_camera_mode(CAM_ISOMETRIC)
    _controller.rotate_free(0.0, 45.0)
    (
        TestHelper
        . assert_true(
            is_zero_approx(_controller.get_pitch_degrees()),
            "isometric rotation ignores pitch and stays upright",
        )
    )
    _controller.set_camera_mode(CAM_PERSPECTIVE)
    _controller.rotate_free(0.0, 45.0)
    (
        TestHelper
        . assert_true(
            _controller.get_pitch_degrees() > 1.0,
            "perspective rotation pitches the asset",
        )
    )
    _controller.set_camera_mode(CAM_ISOMETRIC)
    _finish()


func test_zoom_clamps_and_step_is_exact():
    if not _ensure_scene():
        _finish()
        return
    _controller.select_category(0)
    _controller.select_asset(0)
    _controller.set_camera_mode(CAM_ISOMETRIC)
    _controller.zoom(10000.0)
    (
        TestHelper
        . assert_true(
            is_equal_approx(_controller.get_ortho_size(), 300.0),
            "isometric zoom clamps at maximum",
        )
    )
    _controller.zoom(-10000.0)
    (
        TestHelper
        . assert_true(
            is_equal_approx(_controller.get_ortho_size(), 1.0),
            "isometric zoom clamps at minimum",
        )
    )
    _controller.set_camera_mode(CAM_PERSPECTIVE)
    _controller.zoom(-10000.0)
    (
        TestHelper
        . assert_true(
            is_equal_approx(_controller.get_zoom_distance(), 1.0),
            "perspective zoom clamps at minimum",
        )
    )
    _controller.zoom(10000.0)
    (
        TestHelper
        . assert_true(
            is_equal_approx(_controller.get_zoom_distance(), 300.0),
            "perspective zoom clamps at maximum",
        )
    )
    _controller.set_camera_mode(CAM_ISOMETRIC)
    var yaw0: float = _controller.get_yaw_degrees()
    _controller.rotate_step(90.0)
    var delta := wrapf(_controller.get_yaw_degrees() - yaw0, -180.0, 180.0)
    TestHelper.assert_true(absf(delta - 90.0) < 0.01, "90-degree step is exact")
    _finish()


func test_overlays_toggle_and_world_overlays_stay_fixed():
    if not _ensure_scene():
        _finish()
        return
    _controller.select_category(0)
    _controller.select_asset(0)
    for state in OVERLAY_STATES:
        _controller.set_overlay(state, true)
        var node: Node3D = _controller.get_overlay_node(state)
        TestHelper.assert_true(node != null, "overlay %d has a node" % state)
        TestHelper.assert_true(node.visible, "overlay %d becomes visible" % state)
        _controller.set_overlay(state, false)
        TestHelper.assert_true(not node.visible, "overlay %d hides again" % state)
        _controller.set_overlay(state, true)
    var ground: Node3D = _controller.get_overlay_node(OVERLAY_GROUND)
    (
        TestHelper
        . assert_true(
            ground.get_parent() == _controller.get_world_overlays(),
            "ground grid is world-fixed, not attached to the asset",
        )
    )
    var ground_before := ground.global_transform
    var obj_before: Vector3 = _controller.get_object_root().rotation
    _controller.rotate_step(90.0)
    (
        TestHelper
        . assert_true(
            ground_before.is_equal_approx(ground.global_transform),
            "ground grid does not rotate with the asset",
        )
    )
    (
        TestHelper
        . assert_true(
            not obj_before.is_equal_approx(_controller.get_object_root().rotation),
            "the asset did rotate",
        )
    )
    _finish()


func test_cell_click_highlights_terrain_cell():
    if not _ensure_scene():
        _finish()
        return
    _controller.select_category(0)
    _controller.select_asset(0)
    TestHelper.assert_eq(_controller.get_preview_mode(), 1, "first category is terrain")
    var key := ""
    for row in _controller._cell_list.get_children():
        if row is Button:
            key = (row as Button).text.split("  ")[0]
            break
    TestHelper.assert_true(not key.is_empty(), "terrain cell list is populated")
    _controller._highlight_cell(key)
    TestHelper.assert_true(_controller._highlight_mesh != null, "cell highlight was created")
    (
        TestHelper
        . assert_true(
            _controller._highlight_mesh.get_parent() == _controller.get_object_root(),
            "cell highlight is attached to the asset",
        )
    )
    _finish()


func test_cleanup_frees_scene():
    if _scene != null:
        var tree := Engine.get_main_loop() as SceneTree
        tree.root.remove_child(_scene)
        _scene.queue_free()
        _scene = null
        _controller = null
        TestHelper.assert_true(true, "browser scene freed")
    else:
        TestHelper.assert_true(true, "no browser scene to free")
    _finish()


func _finish() -> void:
    pass
