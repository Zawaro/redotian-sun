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
const OVERLAY_SELECT := 6
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
    (
        TestHelper
        . assert_true(
            is_zero_approx(_controller.get_pitch_degrees()),
            "switching back to isometric clears pitch",
        )
    )
    var root: Node3D = _controller.get_object_root()
    TestHelper.assert_true(
        is_zero_approx(root.rotation.x), "object root is upright after isometric switch"
    )
    _finish()


func test_asset_is_grounded_at_world_origin():
    if not _ensure_scene():
        _finish()
        return
    _controller.select_category(0)
    _controller.select_asset(0)
    _controller.set_auto_rotate(false)
    var root: Node3D = _controller.get_object_root()
    var boxes: Array[AABB] = []
    _controller._collect_bounds(root, root.global_transform, boxes)
    TestHelper.assert_true(not boxes.is_empty(), "preview has mesh bounds to ground")
    if boxes.is_empty():
        _finish()
        return
    var merged: AABB = boxes[0]
    for i in range(1, boxes.size()):
        merged = merged.merge(boxes[i])
    TestHelper.assert_true(
        absf(merged.position.y) < 0.05,
        "lowest mesh point sits at world y=0 (got %s)" % merged.position.y
    )
    TestHelper.assert_true(
        absf(merged.position.x) < 0.05 and absf(merged.position.z) < 0.05,
        "object min corner sits at world origin (got %s)" % merged.position
    )
    _finish()


func test_camera_zoom_survives_asset_change():
    if not _ensure_scene():
        _finish()
        return
    _controller.select_category(0)
    _controller.select_asset(0)
    _controller.set_camera_mode(CAM_ISOMETRIC)
    _controller.zoom(-10000.0)
    var zoom0: float = _controller.get_ortho_size()
    TestHelper.assert_true(zoom0 <= 1.01, "user zoom applied")
    _controller.select_asset(1 if _controller.get_asset_count() > 1 else 0)
    TestHelper.assert_true(
        is_equal_approx(_controller.get_ortho_size(), zoom0),
        "ortho zoom preserved across asset change (got %s)" % _controller.get_ortho_size()
    )
    _finish()


func test_reset_rotation_returns_to_base_yaw():
    if not _ensure_scene():
        _finish()
        return
    _controller.select_category(0)
    _controller.select_asset(0)
    _controller.set_auto_rotate(false)
    _controller.set_camera_mode(CAM_ISOMETRIC)
    var base_yaw: float = _controller.get_yaw_degrees()
    _controller.rotate_step(90.0)
    _controller.rotate_free(0.0, 30.0)
    _controller.reset_rotation()
    TestHelper.assert_true(is_zero_approx(_controller.get_pitch_degrees()), "reset clears pitch")
    var after := wrapf(_controller.get_yaw_degrees() - base_yaw, -180.0, 180.0)
    TestHelper.assert_true(absf(after) < 0.01, "reset returns to base yaw (delta %s)" % after)
    _finish()


func test_theater_selector_lists_theaters():
    if not _ensure_scene():
        _finish()
        return
    TestHelper.assert_true(_controller._theater_option != null, "theater selector exists")
    TestHelper.assert_true(
        _controller._theater_option.item_count >= 1, "at least one theater listed"
    )
    _finish()


func test_building_shows_select_and_health_preview():
    if not _ensure_scene():
        _finish()
        return
    var buildings_idx := -1
    for i in _controller.get_category_count():
        if _controller.get_category_label(i) == "Buildings":
            buildings_idx = i
            break
    TestHelper.assert_true(buildings_idx >= 0, "Buildings category exists")
    if buildings_idx < 0:
        _finish()
        return
    _controller.select_category(buildings_idx)
    TestHelper.assert_true(_controller.get_asset_count() > 0, "buildings populated")
    _controller.select_asset(0)
    _controller.set_overlay(OVERLAY_SELECT, true)
    var sel: Node3D = _controller.get_overlay_node(OVERLAY_SELECT)
    TestHelper.assert_true(sel != null, "select preview node exists")
    TestHelper.assert_true(sel != null and sel.visible, "select preview visible")
    TestHelper.assert_true(
        _controller._health_bar_mesh != null and _controller._health_bar_mesh.visible,
        "health bar preview visible"
    )
    # Health bar sits at the top of the select box (gameplay structure bar),
    # long axis along Z after -90° yaw — not a free-floating mid-air slab.
    var bar: MeshInstance3D = _controller._health_bar_mesh
    TestHelper.assert_true(absf(bar.rotation_degrees.y + 90.0) < 0.1, "bar yawed -90 like gameplay")
    var root: Node3D = _controller.get_object_root()
    var boxes: Array[AABB] = []
    _controller._collect_bounds(bar, bar.transform, boxes)
    TestHelper.assert_true(not boxes.is_empty(), "health bar has bounds")
    if not boxes.is_empty() and _controller._select_mesh != null:
        var select_boxes: Array[AABB] = []
        _controller._collect_bounds(
            _controller._select_mesh, _controller._select_mesh.transform, select_boxes
        )
        TestHelper.assert_true(not select_boxes.is_empty(), "select box has bounds")
        if not select_boxes.is_empty():
            var select_top := select_boxes[0].end.y
            var bar_top := boxes[0].end.y
            TestHelper.assert_true(
                absf(bar_top - select_top) < 0.5,
                (
                    "health bar top aligns with select box top (bar %s vs select %s)"
                    % [bar_top, select_top]
                )
            )
            TestHelper.assert_true(
                boxes[0].position.y > root.position.y - 1.0,
                (
                    "health bar not below ground/local mid (y=%s root=%s)"
                    % [boxes[0].position.y, root.position.y]
                )
            )
    _finish()


func test_image_mode_fills_info_resource():
    if not _ensure_scene():
        _finish()
        return
    var image_idx := -1
    for i in _controller.get_category_count():
        if _controller.get_category_label(i) == "Cameos / UI":
            image_idx = i
            break
    TestHelper.assert_true(image_idx >= 0, "Cameos / UI category exists")
    if image_idx < 0:
        _finish()
        return
    _controller.select_category(image_idx)
    TestHelper.assert_true(_controller.get_asset_count() > 0, "cameos populated")
    _controller.select_asset(0)
    TestHelper.assert_eq(_controller.get_preview_mode(), 3, "image mode")
    TestHelper.assert_true(_controller._current_resource != null, "image sets current resource")
    TestHelper.assert_true(_controller._image_rect.visible, "image pane shown")
    _finish()


func test_failed_resolution_shows_explicit_message():
    if not _ensure_scene():
        _finish()
        return
    _controller.select_category(0)
    TestHelper.assert_true(_controller.get_asset_count() > 0, "terrain category has assets")
    _controller._assets = [{"id": "__missing__", "path": "res://does/not/exist.tres"}]
    _controller.select_asset(0)
    (
        TestHelper
        . assert_true(
            _controller._message_label != null and _controller._message_label.visible,
            "failed resolution shows an explicit empty state",
        )
    )
    (
        TestHelper
        . assert_true(
            not _controller._message_label.text.is_empty(),
            "failure message has visible text",
        )
    )
    _controller.select_category(0)
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


func test_fx_category_lists_and_previews():
    if not _ensure_scene():
        _finish()
        return
    var fx_index := -1
    for i in _controller.get_category_count():
        if _controller.get_category_label(i) == "FX":
            fx_index = i
            break
    TestHelper.assert_true(fx_index >= 0, "FX category is present")
    _controller.select_category(fx_index)
    TestHelper.assert_true(_controller.get_asset_count() >= 1, "FX category lists effects")
    _controller.select_asset(0)
    TestHelper.assert_eq(_controller.get_preview_mode(), 4, "FX preview mode is active")
    TestHelper.assert_true(_controller._fx_row.visible, "FX replay transport is shown")
    TestHelper.assert_true(
        _controller.get_object_root().get_child_count() > 0, "FX effect added to the preview stage"
    )
    var first: Node = _controller.get_object_root().get_child(0)
    var first_id: int = first.get_instance_id()
    _controller.replay_asset()
    var second: Node = _controller.get_object_root().get_child(0)
    TestHelper.assert_true(second.get_instance_id() != first_id, "replay spawns a fresh effect")
    _finish()


func test_fx_invalid_selection_shows_empty_state():
    if not _ensure_scene():
        _finish()
        return
    _controller._preview_fx("res://games/ts/fx/__missing__.tres")
    TestHelper.assert_true(_controller._message_label.visible, "invalid FX shows the empty state")
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
