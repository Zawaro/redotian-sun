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


func _make_transport_entity(storage_count: int, max_passengers: int) -> Node3D:
    var entity := Node3D.new()
    var transport := TransportComponent.new()
    transport.name = "TransportComponent"
    transport.storage = storage_count
    transport.passengers = max_passengers
    entity.add_child(transport)
    _sm.add_child(entity)
    return entity


func _assert_row_clears_bracket(pips: Array[Dictionary], bracket_rect: Rect2, what: String):
    TestHelper.assert_true(not pips.is_empty(), what + ": pips are present")
    var pip_h: float = (pips[0]["rect"] as Rect2).size.y
    for pip in pips:
        var pip_rect: Rect2 = pip["rect"]
        var gap: float = bracket_rect.end.y - pip_rect.end.y
        # The bracket line and the pip outline are both 1 px strokes centered on
        # their edges, so they overlap once gap < 1.0; 1.5 demands a visible
        # separation. The old 0.1 * pip_h offset left ~0.4 px and flickered.
        TestHelper.assert_true(gap >= 1.5, what + ": pip clears the bracket line (gap=%.2f)" % gap)
        TestHelper.assert_true(
            gap <= pip_h, what + ": pips stay attached to the bracket (gap=%.2f)" % gap
        )


func test_cargo_pips_clear_bottom_bracket():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var overlay := _overlay()
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload not present")
        return
    var entity := _make_transport_entity(10, 0)
    var transport := entity.get_node("TransportComponent") as TransportComponent
    transport.cargo = {"tiberium_green": 5.0}

    var rect := Rect2(0, 0, 60, 40)
    var cargo_pips: Array[Dictionary] = []
    var pass_pips: Array[Dictionary] = []
    overlay._gather_pips(entity, rect, rect, cargo_pips, pass_pips)

    TestHelper.assert_eq(
        cargo_pips.size(), overlay.MAX_CARGO_SLOTS, "cargo pips fill the slot grid"
    )
    TestHelper.assert_true(pass_pips.is_empty(), "no passenger pips without passengers")
    _assert_row_clears_bracket(cargo_pips, rect, "cargo row")

    entity.free()


func test_passenger_pips_clear_bottom_bracket_when_rows_stack():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var overlay := _overlay()
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload not present")
        return
    var entity := _make_transport_entity(10, 3)
    var transport := entity.get_node("TransportComponent") as TransportComponent
    transport.cargo = {"tiberium_green": 5.0}
    transport.current_passengers = 2

    var rect := Rect2(0, 0, 60, 40)
    var cargo_pips: Array[Dictionary] = []
    var pass_pips: Array[Dictionary] = []
    overlay._gather_pips(entity, rect, rect, cargo_pips, pass_pips)

    TestHelper.assert_true(not pass_pips.is_empty(), "passenger row drawn for loaded transport")
    var cargo_bottom: float = (cargo_pips[0]["rect"] as Rect2).end.y
    var passenger_top: float = (pass_pips[0]["rect"] as Rect2).position.y
    TestHelper.assert_true(
        passenger_top >= cargo_bottom, "stacked passenger row sits below the cargo row"
    )
    _assert_row_clears_bracket(pass_pips, rect, "passenger row")

    entity.free()


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


## Structures were previously skipped by _collect_entities entirely, which
## starved the selected-producer power label — the label's primary subject.
## Regression coverage for the structure-collection fix (power-grid task 4.3).
func _make_structure(power: int) -> Dictionary:
    var entity := Node3D.new()
    entity.position = Vector3(0, 0, -5)
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = 0
    entity.add_child(stats)
    var pc := PowerComponent.new()
    pc.name = "PowerComponent"
    pc.power = power
    entity.add_child(pc)
    var sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    sc.name = "SelectComponent"
    sc.select_box_type = SelectComponent.SelectBoxType.Structure
    entity.add_child(sc)
    _sm.add_child(entity)
    return {"entity": entity, "select_comp": sc}


func test_collect_entities_includes_selected_structure_with_power_label():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var overlay := _overlay()
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload not present")
        return
    _sm.deselect_all()
    var fixture := _make_structure(100)
    var cam := _ensure_camera()

    _sm.add_entity(fixture["select_comp"] as SelectComponent)
    overlay._entities.clear()
    overlay._collect_entities()
    TestHelper.assert_true(overlay._entities.size() == 1, "selected structure is collected")
    if overlay._entities.size() == 1:
        var e: Dictionary = overlay._entities[0]
        TestHelper.assert_true(e["is_structure"], "collected entry is tagged as structure")
        var label: String = e["power_label"]
        TestHelper.assert_true(not label.is_empty(), "selected producer structure has a label")
        TestHelper.assert_true(
            label.begins_with("POWER = "), "label leads with POWER = line: %s" % label
        )
        TestHelper.assert_true(label.contains("\nDRAIN = "), "label carries DRAIN = line")

    _sm.deselect_all()
    fixture["entity"].free()
    cam.free()


func test_selected_structure_consumer_has_no_power_label():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var overlay := _overlay()
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload not present")
        return
    _sm.deselect_all()
    var fixture := _make_structure(-50)
    var cam := _ensure_camera()

    _sm.add_entity(fixture["select_comp"] as SelectComponent)
    overlay._entities.clear()
    overlay._collect_entities()
    TestHelper.assert_true(overlay._entities.size() == 1, "selected structure is collected")
    if overlay._entities.size() == 1:
        var e: Dictionary = overlay._entities[0]
        TestHelper.assert_true(e["is_structure"], "collected entry is tagged as structure")
        TestHelper.assert_true(
            (e["power_label"] as String).is_empty(), "consumer structure shows no label"
        )

    _sm.deselect_all()
    fixture["entity"].free()
    cam.free()


## Name-label fixtures: StatsComponent + SelectComponent (units path), with or
## without a display name, or without StatsComponent at all.
func _make_named_entity(display_name: String, with_stats: bool) -> Dictionary:
    var entity := Node3D.new()
    entity.position = Vector3(0, 0, -5)
    if with_stats:
        var stats := StatsComponent.new()
        stats.name = "StatsComponent"
        stats.player_id = 0
        stats.display_name = display_name
        entity.add_child(stats)
    var sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    sc.name = "SelectComponent"
    entity.add_child(sc)
    _sm.add_child(entity)
    return {"entity": entity, "select_comp": sc}


func _assert_collected_name(fixture: Dictionary, expected: String, what: String) -> void:
    var overlay := _overlay()
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload not present")
        return
    var cam := _ensure_camera()
    _sm.add_entity(fixture["select_comp"] as SelectComponent)
    overlay._entities.clear()
    overlay._collect_entities()
    TestHelper.assert_true(overlay._entities.size() == 1, what + ": entity is collected")
    if overlay._entities.size() == 1:
        var e: Dictionary = overlay._entities[0]
        TestHelper.assert_eq(e["display_name"], expected, what)
    _sm.deselect_all()
    fixture["entity"].free()
    cam.free()


func test_collect_entities_carries_uppercase_display_name():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var fixture := _make_named_entity("Light Infantry", true)
    _assert_collected_name(fixture, "LIGHT INFANTRY", "name label renders uppercase")


func test_collect_entities_empty_name_when_stats_has_no_display_name():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var fixture := _make_named_entity("", true)
    _assert_collected_name(fixture, "", "empty display_name collects as empty string")


func test_collect_entities_missing_statscomponent_yields_empty_name():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var fixture := _make_named_entity("", false)
    _assert_collected_name(fixture, "", "missing StatsComponent collects empty name")
