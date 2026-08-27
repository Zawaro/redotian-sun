extends Node

# SelectionManager tests — selection state management
# Note: selected_entities is Array[SelectComponent], so we can't mock with Node

const SELECT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/SelectComponent.tscn")

var _sm: Node = null
var _ts: Node = null

var _emit_count := 0
var _last_selection_arg: Array[SelectComponent] = []


func _on_selection_changed_counter(selected: Array[SelectComponent]) -> void:
    _emit_count += 1
    _last_selection_arg = selected


func test_deselect_all_clears():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm.deselect_all()
    var count: int = _sm.selected_entities.size()
    TestHelper.assert_true(count == 0, "deselect_all clears selection: expected 0, got %d" % count)


func test_external_set_is_selected_reconciles_same_frame():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm.deselect_all()
    var entity := Node3D.new()
    entity.add_to_group("selectable")
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    select_comp.name = "SelectComponent"
    entity.add_child(select_comp)
    _sm.add_child(entity)

    _sm._synchronize_visual_selection()

    select_comp.set_is_selected(true)
    (
        TestHelper
        . assert_true(
            _sm.selected_entities.size() == 1 and _sm.selected_entities[0] == select_comp,
            (
                "external set_is_selected(true) reconciles same frame: "
                + "expected component in selection after external select"
            ),
        )
    )
    select_comp.set_is_selected(false)
    (
        TestHelper
        . assert_true(
            not _sm.selected_entities.has(select_comp),
            (
                "external set_is_selected(false) reconciles same frame: "
                + "expected component removed after external deselect"
            ),
        )
    )

    _sm.deselect_all()
    entity.free()


func test_throttled_sync_not_every_frame():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm.deselect_all()
    _sm._selection_sync_counter = 0
    var entity := Node3D.new()
    entity.add_to_group("selectable")
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    select_comp.name = "SelectComponent"
    select_comp.set_is_selected(true)
    entity.add_child(select_comp)
    _sm.add_child(entity)

    for i in 5:
        _sm._process(0.016)
    (
        TestHelper
        . assert_true(
            _sm.selected_entities.is_empty(),
            "throttled sync skips frames: not reconciled before 6th frame",
        )
    )

    _sm._process(0.016)
    (
        TestHelper
        . assert_true(
            _sm.selected_entities.size() == 1,
            (
                "throttled sync runs on 6th frame: expected reconciliation, got %d"
                % _sm.selected_entities.size()
            ),
        )
    )

    _sm.deselect_all()
    entity.free()


func test_select_entity_ignores_null():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm.deselect_all()
    _sm.select_entity(null)
    var count: int = _sm.selected_entities.size()
    TestHelper.assert_true(
        count == 0, "select_entity ignores null: expected 0 after null, got %d" % count
    )


func test_synchronize_visual_selection_adds_missing_component():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm.deselect_all()
    var entity := Node3D.new()
    entity.add_to_group("selectable")
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    select_comp.name = "SelectComponent"
    select_comp.set_is_selected(true)
    entity.add_child(select_comp)
    _sm.add_child(entity)

    _sm._synchronize_visual_selection()

    (
        TestHelper
        . assert_true(
            _sm.selected_entities.size() == 1 and _sm.selected_entities[0] == select_comp,
            (
                "visual selection is synchronized into SelectionManager: "
                + "visual selection should be synchronized into SelectionManager"
            ),
        )
    )

    _sm.deselect_all()
    entity.free()


func test_deselect_all_clears_unmanaged_visual_selection():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm.deselect_all()
    var entity := Node3D.new()
    entity.add_to_group("selectable")
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    select_comp.name = "SelectComponent"
    select_comp.set_is_selected(true)
    entity.add_child(select_comp)
    _sm.add_child(entity)

    _sm.deselect_all()

    (
        TestHelper
        . assert_true(
            not select_comp.is_selected,
            (
                "deselect_all clears unmanaged visual selection: "
                + "deselect_all should clear unmanaged visual selection"
            ),
        )
    )

    entity.free()


func test_add_entity_allows_enemy_player():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm.deselect_all()
    var pm := get_node_or_null("/root/PlayerManager")
    var local_pid: int = pm.get_local_player_id() if pm else 0
    var entity := Node3D.new()
    entity.name = "EnemyEntity"
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    entity.add_child(select_comp)
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = local_pid + 1
    entity.add_child(stats)
    _sm.add_child(entity)

    _sm.add_entity(select_comp)

    (
        TestHelper
        . assert_true(
            _sm.selected_entities.size() == 1,
            (
                "add_entity allows enemy player entity for viewing: "
                + "add_entity should allow enemy entity (selectable for viewing)"
            ),
        )
    )
    _sm.deselect_all()
    entity.free()


func test_add_entity_allows_local_player():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm.deselect_all()
    var pm := get_node_or_null("/root/PlayerManager")
    var local_pid: int = pm.get_local_player_id() if pm else 0
    var entity := Node3D.new()
    entity.name = "FriendlyEntity"
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    entity.add_child(select_comp)
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = local_pid
    entity.add_child(stats)
    _sm.add_child(entity)

    _sm.add_entity(select_comp)

    (
        TestHelper
        . assert_true(
            _sm.selected_entities.size() == 1,
            "add_entity allows local player entity: add_entity should allow local player entity",
        )
    )
    _sm.deselect_all()
    entity.free()


func test_add_entity_allows_unset_player_id():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm.deselect_all()
    var entity := Node3D.new()
    entity.name = "UnsetEntity"
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    entity.add_child(select_comp)
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = -1
    entity.add_child(stats)
    _sm.add_child(entity)

    _sm.add_entity(select_comp)

    (
        TestHelper
        . assert_true(
            _sm.selected_entities.size() == 1,
            "add_entity allows unset player_id (-1): add_entity should allow unset player_id (-1)",
        )
    )
    _sm.deselect_all()
    entity.free()


func test_add_entity_allows_no_stats_component():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm.deselect_all()
    var entity := Node3D.new()
    entity.name = "NoStatsEntity"
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    entity.add_child(select_comp)
    _sm.add_child(entity)

    _sm.add_entity(select_comp)

    (
        TestHelper
        . assert_true(
            _sm.selected_entities.size() == 1,
            (
                "add_entity allows entity without StatsComponent: "
                + "add_entity should allow entity without StatsComponent"
            ),
        )
    )
    _sm.deselect_all()
    entity.free()


func test_is_local_entity_filters_enemy():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var pm := get_node_or_null("/root/PlayerManager")
    var local_pid: int = pm.get_local_player_id() if pm else 0
    var entity := Node3D.new()
    entity.name = "EnemyEntity"
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    entity.add_child(select_comp)
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = local_pid + 1
    entity.add_child(stats)
    _sm.add_child(entity)

    (
        TestHelper
        . assert_true(
            not _sm._is_local_entity(select_comp),
            (
                "_is_local_entity returns false for enemy: "
                + "_is_local_entity should return false for enemy"
            ),
        )
    )
    entity.free()


func test_is_local_entity_allows_local():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var pm := get_node_or_null("/root/PlayerManager")
    var local_pid: int = pm.get_local_player_id() if pm else 0
    var entity := Node3D.new()
    entity.name = "FriendlyEntity"
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    entity.add_child(select_comp)
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = local_pid
    entity.add_child(stats)
    _sm.add_child(entity)

    (
        TestHelper
        . assert_true(
            _sm._is_local_entity(select_comp),
            (
                "_is_local_entity returns true for local player: "
                + "_is_local_entity should return true for local player"
            ),
        )
    )
    entity.free()


func test_find_sharer_cell_empty():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    # Ensure 50×50 grid so world→cell conversion is deterministic
    if _ts:
        _ts.init_grid(50, 50)
    CellReservation.instance.clear()
    var target := Vector2i(10, 10)
    # Centered: cell (10,10) on 50×50 → world (-79, 0, -79)
    var result: Vector2i = _sm._find_sharer_cell(Vector3(-79, 0, -79))
    TestHelper.assert_true(
        result == target,
        "_find_sharer_cell returns target when empty: expected %s, got %s" % [target, result]
    )


func test_find_sharer_cell_at_capacity():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    # Ensure 50×50 grid so world→cell conversion is deterministic
    if _ts:
        _ts.init_grid(50, 50)
    CellReservation.instance.clear()
    # In-visible cell on 50×50 (orders only target inside the visible diamond);
    # a full cell here must spiral to an in-area neighbor, not an off-map cell.
    var target := Vector2i(30, 30)
    var claimers: Array[Node3D] = []
    for i in CellSubPositions.get_slot_count():
        var claimer := Node3D.new()
        add_child(claimer)
        claimers.append(claimer)
        CellReservation.instance.reserve_sub_slot(target, claimer)
    # Centered coords: cell (30,30) on 50×50 grid → world (-39, 0, -39)
    var result: Vector2i = _sm._find_sharer_cell(Vector3(-39, 0, -39))
    for claimer in claimers:
        claimer.queue_free()
    CellReservation.instance.clear()
    (
        TestHelper
        . assert_true(
            result != target,
            (
                "_find_sharer_cell spirals when target is full: "
                + "should have spiraled away from full cell"
            ),
        )
    )


func test_deselect_all_emits_selection_changed_once():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm.deselect_all()
    var entities: Array[Node3D] = []
    for i in 5:
        var entity := Node3D.new()
        entity.name = "EmitCounter%d" % i
        entity.add_to_group("selectable")
        var sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
        sc.name = "SelectComponent"
        entity.add_child(sc)
        _sm.add_child(entity)
        entities.append(entity)
        _sm.add_entity(sc)
    _emit_count = 0
    _last_selection_arg = []
    _sm.selection_changed.connect(_on_selection_changed_counter)
    _sm.deselect_all()
    _sm.selection_changed.disconnect(_on_selection_changed_counter)
    for e in entities:
        _sm.remove_child(e)
        e.free()
    TestHelper.assert_eq(_emit_count, 1, "deselect_all emits selection_changed exactly once")
    TestHelper.assert_true(
        _last_selection_arg.is_empty(), "the single emit carries an empty selection"
    )
    TestHelper.assert_true(
        _sm.selected_entities.is_empty(), "selected_entities is empty after deselect_all"
    )


func test_non_infantry_sharer_uses_cell_distribution():
    if _sm == null or _ts == null:
        TestHelper.fail("SelectionManager/TerrainSystem not injected")
        return
    var rules := GlobalRules.get_current()
    var saved_shroud: bool = rules.shroud_enabled
    var saved_fog: bool = rules.fog_of_war
    rules.shroud_enabled = false
    rules.fog_of_war = false
    _ts.init_grid(50, 50)
    _sm.deselect_all()
    CellReservation.instance.clear()
    var entity := Node3D.new()
    entity.name = "VehicleSharer"
    var stats := StatsComponent.new()
    stats.player_id = -1
    stats.entity_type = EntityData.EntityType.VEHICLE
    entity.add_child(stats)
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    mc._shares_cell = true
    _sm.add_child(entity)
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    select_comp.name = "SelectComponent"
    entity.add_child(select_comp)
    _sm.select_entity(select_comp)
    _sm.request_move(Vector3(-79, 0, -79))
    var routed: bool = _sm._pending_moves.size() == 1
    _sm.deselect_all()
    CellReservation.instance.clear()
    entity.queue_free()
    rules.shroud_enabled = saved_shroud
    rules.fog_of_war = saved_fog
    (
        TestHelper
        . assert_true(
            routed,
            (
                (
                    "non-infantry sharer routed via cell distribution: "
                    + "expected 1 pending sharer move, got %d"
                )
                % _sm._pending_moves.size()
            ),
        )
    )
