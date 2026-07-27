extends Node

# SelectionManager tests — selection state management
# Note: selected_entities is Array[SelectComponent], so we can't mock with Node

const SELECT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/SelectComponent.tscn")

var _sm: Node = null
var _test_passed := 0
var _test_failed := 0


func test_selected_entities_initially_empty():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return
    _sm.deselect_all()
    var count: int = _sm.selected_entities.size()
    if count == 0:
        _test_passed += 1
        print("    PASS: selected_entities initially empty")
    else:
        _test_failed += 1
        print("    FAIL: expected 0, got %d" % count)


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


func test_find_infantry_cell_empty():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return
    var occupancy: Dictionary = {}
    var target := Vector2i(10, 10)
    var result: Vector2i = _sm._find_infantry_cell(Vector3(22, 0, 22), occupancy)
    if result == target:
        _test_passed += 1
        print("    PASS: _find_infantry_cell returns target when empty")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [target, result])


func test_find_infantry_cell_at_capacity():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return
    var occupancy: Dictionary = {}
    var target := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(target)
    occupancy[key] = 3
    var result: Vector2i = _sm._find_infantry_cell(Vector3(22, 0, 22), occupancy)
    if result != target:
        _test_passed += 1
        print("    PASS: _find_infantry_cell spirals when target is full")
    else:
        _test_failed += 1
        print("    FAIL: should have spiraled away from full cell")
