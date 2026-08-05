extends Node

# SelectionOverlay tests — tracked-list iteration replaces the full-group scan

const SELECT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/SelectComponent.tscn")

var _sm: Node = null
var _ts: Node = null


func _overlay() -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    return tree.root.get_node_or_null("SelectionOverlay") if tree else null


func _ensure_camera() -> Camera3D:
    var tree := _sm.get_tree()
    var cam := Camera3D.new()
    cam.current = true
    tree.root.add_child(cam)
    return cam


func _make_entity() -> Dictionary:
    var entity := Node3D.new()
    entity.position = Vector3(0, 0, -5)
    entity.add_to_group("selectable")
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    select_comp.name = "SelectComponent"
    entity.add_child(select_comp)
    _sm.add_child(entity)
    return {"entity": entity, "select_comp": select_comp}


func _assert_tracked(overlay: Node, expected: int, what: String):
    var size: int = overlay._tracked.size()
    TestHelper.assert_true(size == expected, "%s: expected %d, got %d" % [what, expected, size])


func _assert_collected(overlay: Node, expected: int, what: String):
    overlay._entities.clear()
    overlay._collect_entities()
    var size: int = overlay._entities.size()
    TestHelper.assert_true(size == expected, "%s: expected %d, got %d" % [what, expected, size])


func test_collect_entities_tracks_selected():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var overlay := _overlay()
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload not present")
        return
    _sm.deselect_all()
    var fixture := _make_entity()
    var cam := _ensure_camera()

    _sm.add_entity(fixture["select_comp"] as SelectComponent)
    _assert_tracked(overlay, 1, "selection signal tracks the selected entity")
    _assert_collected(overlay, 1, "collect_entities renders exactly the tracked entity")

    _sm.deselect_all()
    fixture["entity"].free()
    cam.free()


func test_collect_entities_from_selection_signal():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var overlay := _overlay()
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload not present")
        return
    _sm.deselect_all()
    var fixture := _make_entity()
    var sc := fixture["select_comp"] as SelectComponent
    var cam := _ensure_camera()

    sc.set_is_selected(true)
    overlay._on_selection_changed([sc] as Array[SelectComponent])
    _assert_tracked(overlay, 1, "external selection signal tracks the entity")
    _assert_collected(overlay, 1, "collect_entities renders the externally selected entity")

    _sm.deselect_all()
    fixture["entity"].free()
    cam.free()


func test_collect_entities_empty_after_deselect():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var overlay := _overlay()
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload not present")
        return
    _sm.deselect_all()
    var fixture := _make_entity()
    var cam := _ensure_camera()
    _sm.add_entity(fixture["select_comp"] as SelectComponent)

    _sm.deselect_all()
    _assert_tracked(overlay, 0, "deselect_all clears the tracked list")
    _assert_collected(overlay, 0, "collect_entities is empty after deselect_all")

    fixture["entity"].free()
    cam.free()


func test_collect_ignores_untracked_group_entities():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var overlay := _overlay()
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload not present")
        return
    _sm.deselect_all()
    var fixture := _make_entity()
    var sc := fixture["select_comp"] as SelectComponent
    var cam := _ensure_camera()

    sc.set_is_selected(true)
    _assert_tracked(overlay, 0, "a visually selected group entity is not tracked")
    _assert_collected(overlay, 0, "collect_entities skips untracked group entities")

    _sm.deselect_all()
    fixture["entity"].free()
    cam.free()


func test_collect_entities_tracks_hovered():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var overlay := _overlay()
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload not present")
        return
    _sm.deselect_all()
    var fixture := _make_entity()
    var sc := fixture["select_comp"] as SelectComponent
    var cam := _ensure_camera()

    _sm.set_hover_preview(true, sc)
    _assert_tracked(overlay, 1, "hover preview tracks the hovered entity")
    _assert_collected(overlay, 1, "collect_entities renders the hovered entity")

    _sm.clear_hover_preview()
    _assert_tracked(overlay, 0, "clearing hover preview untracks the entity")
    _assert_collected(overlay, 0, "collect_entities drops a cleared hover")
    fixture["entity"].free()
    cam.free()
