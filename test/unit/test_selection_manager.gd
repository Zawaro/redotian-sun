extends Node

# SelectionManager tests — selection state management
# Note: selected_entities is Array[SelectComponent], so we can't mock with Node

const SELECT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/SelectComponent.tscn")

var _sm: Node = null
var _ts: Node = null
var _test_passed := 0
var _test_failed := 0


func test_deselect_all_clears():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return
    _sm.deselect_all()
    var count: int = _sm.selected_entities.size()
    if count == 0:
        _test_passed += 1
        print("    PASS: deselect_all clears selection")
    else:
        _test_failed += 1
        print("    FAIL: expected 0, got %d" % count)


func test_select_entity_ignores_null():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return
    _sm.deselect_all()
    _sm.select_entity(null)
    var count: int = _sm.selected_entities.size()
    if count == 0:
        _test_passed += 1
        print("    PASS: select_entity ignores null")
    else:
        _test_failed += 1
        print("    FAIL: expected 0 after null, got %d" % count)


func test_synchronize_visual_selection_adds_missing_component():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
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

    if _sm.selected_entities.size() == 1 and _sm.selected_entities[0] == select_comp:
        _test_passed += 1
        print("    PASS: visual selection is synchronized into SelectionManager")
    else:
        _test_failed += 1
        print("    FAIL: visual selection should be synchronized into SelectionManager")

    _sm.deselect_all()
    entity.free()


func test_deselect_all_clears_unmanaged_visual_selection():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
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

    if not select_comp.is_selected:
        _test_passed += 1
        print("    PASS: deselect_all clears unmanaged visual selection")
    else:
        _test_failed += 1
        print("    FAIL: deselect_all should clear unmanaged visual selection")

    entity.free()


func test_add_entity_allows_enemy_player():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
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

    if _sm.selected_entities.size() == 1:
        _test_passed += 1
        print("    PASS: add_entity allows enemy player entity for viewing")
    else:
        _test_failed += 1
        print("    FAIL: add_entity should allow enemy entity (selectable for viewing)")
    _sm.deselect_all()
    entity.free()


func test_add_entity_allows_local_player():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
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

    if _sm.selected_entities.size() == 1:
        _test_passed += 1
        print("    PASS: add_entity allows local player entity")
    else:
        _test_failed += 1
        print("    FAIL: add_entity should allow local player entity")
    _sm.deselect_all()
    entity.free()


func test_add_entity_allows_unset_player_id():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
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

    if _sm.selected_entities.size() == 1:
        _test_passed += 1
        print("    PASS: add_entity allows unset player_id (-1)")
    else:
        _test_failed += 1
        print("    FAIL: add_entity should allow unset player_id (-1)")
    _sm.deselect_all()
    entity.free()


func test_add_entity_allows_no_stats_component():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return
    _sm.deselect_all()
    var entity := Node3D.new()
    entity.name = "NoStatsEntity"
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    entity.add_child(select_comp)
    _sm.add_child(entity)

    _sm.add_entity(select_comp)

    if _sm.selected_entities.size() == 1:
        _test_passed += 1
        print("    PASS: add_entity allows entity without StatsComponent")
    else:
        _test_failed += 1
        print("    FAIL: add_entity should allow entity without StatsComponent")
    _sm.deselect_all()
    entity.free()


func test_is_local_entity_filters_enemy():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
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

    if not _sm._is_local_entity(select_comp):
        _test_passed += 1
        print("    PASS: _is_local_entity returns false for enemy")
    else:
        _test_failed += 1
        print("    FAIL: _is_local_entity should return false for enemy")
    entity.free()


func test_is_local_entity_allows_local():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
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

    if _sm._is_local_entity(select_comp):
        _test_passed += 1
        print("    PASS: _is_local_entity returns true for local player")
    else:
        _test_failed += 1
        print("    FAIL: _is_local_entity should return true for local player")
    entity.free()


func test_find_sharer_cell_empty():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return
    # Ensure 50×50 grid so world→cell conversion is deterministic
    if _ts:
        _ts.init_grid(50, 50)
    CellReservation.instance.clear()
    var target := Vector2i(10, 10)
    # Centered: cell (10,10) on 50×50 → world (-79, 0, -79)
    var result: Vector2i = _sm._find_sharer_cell(Vector3(-79, 0, -79))
    if result == target:
        _test_passed += 1
        print("    PASS: _find_sharer_cell returns target when empty")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [target, result])


func test_find_sharer_cell_at_capacity():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return
    # Ensure 50×50 grid so world→cell conversion is deterministic
    if _ts:
        _ts.init_grid(50, 50)
    CellReservation.instance.clear()
    var target := Vector2i(10, 10)
    var claimers: Array[Node3D] = []
    for i in CellReservation.NUM_SLOTS:
        var claimer := Node3D.new()
        add_child(claimer)
        claimers.append(claimer)
        CellReservation.instance.reserve_sub_slot(target, claimer)
    # Centered coords: cell (10,10) on 50×50 grid → world (-79, 0, -79)
    var result: Vector2i = _sm._find_sharer_cell(Vector3(-79, 0, -79))
    for claimer in claimers:
        claimer.queue_free()
    CellReservation.instance.clear()
    if result != target:
        _test_passed += 1
        print("    PASS: _find_sharer_cell spirals when target is full")
    else:
        _test_failed += 1
        print("    FAIL: should have spiraled away from full cell")


func test_non_infantry_sharer_uses_cell_distribution():
    if _sm == null or _ts == null:
        _test_failed += 1
        print("    FAIL: SelectionManager/TerrainSystem not injected")
        return
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
    if routed:
        _test_passed += 1
        print("    PASS: non-infantry sharer routed via cell distribution")
    else:
        _test_failed += 1
        print("    FAIL: expected 1 pending sharer move, got %d" % _sm._pending_moves.size())
