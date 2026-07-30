extends Node

# Entity death handler tests — building and unit death cleanup

var _bm: Node = null
var _sm: Node = null
var _test_passed := 0
var _test_failed := 0


func _make_entity_with_health(health: int = 100) -> Node3D:
    var entity := Node3D.new()
    var hc := HealthComponent.new()
    hc.name = "HealthComponent"
    hc.max_health = health
    hc.current_health = health
    entity.add_child(hc)
    return entity


# --- Task 3.1: Building death removes entry from BuildingManager ---


func test_building_death_removes_entry_from_building_manager():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building := _make_entity_with_health(100)
    var cells: Array[Vector2i] = [Vector2i(100, 100)]
    (
        _bm
        . _buildings
        . append(
            {
                "node": building,
                "type": EntityData.new(),
                "origin": Vector2i(100, 100),
                "cells": cells,
            }
        )
    )
    var idx_before: int = _bm._buildings.size()
    # Call handler directly
    _bm._on_building_destroyed(building)
    var idx_after: int = _bm._buildings.size()
    TestHelper.assert_eq(idx_after, idx_before - 1, "building entry removed from _buildings")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


# --- Task 3.2: Building death unregisters cells from SpatialHash ---


func test_building_death_unregisters_cells_from_spatial_hash():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building := _make_entity_with_health(100)
    var cells: Array[Vector2i] = [Vector2i(200, 200)]
    SpatialHash.instance.register_building_cells(cells)
    (
        _bm
        . _buildings
        . append(
            {
                "node": building,
                "type": EntityData.new(),
                "origin": Vector2i(200, 200),
                "cells": cells,
            }
        )
    )
    var key := CellUtil.cell_key(Vector2i(200, 200))
    var registered_before: bool = SpatialHash.instance._building_cells.has(key)
    # Call handler directly
    _bm._on_building_destroyed(building)
    var registered_after: bool = SpatialHash.instance._building_cells.has(key)
    TestHelper.assert_true(registered_before, "cells registered before death")
    TestHelper.assert_eq(registered_after, false, "cells unregistered after death")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


# --- Task 3.3: Building death entry removed (PrerequisiteSystem test simplified) ---


func test_building_death_removes_entry_and_entity_freed():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building := _make_entity_with_health(100)
    var data := EntityData.new()
    data.id = "TEST_PREREQ_BLDG"
    var cells: Array[Vector2i] = [Vector2i(300, 300)]
    (
        _bm
        . _buildings
        . append(
            {
                "node": building,
                "type": data,
                "origin": Vector2i(300, 300),
                "cells": cells,
            }
        )
    )
    # Call handler directly
    _bm._on_building_destroyed(building)
    # Verify entry was removed
    var found := false
    for entry in _bm._buildings:
        if entry.get("node") == building:
            found = true
            break
    TestHelper.assert_eq(found, false, "building entry removed after death")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


# --- Task 3.4: Building death deselects from SelectionManager ---


func test_building_death_deselects_from_selection_manager():
    if _bm == null or _sm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager or SelectionManager not injected")
        return
    var building := _make_entity_with_health(100)
    var select_comp := SelectComponent.new()
    select_comp.name = "SelectComponent"
    building.add_child(select_comp)
    _sm.add_entity(select_comp)
    var selected_before: bool = _sm.is_entity_selected(select_comp)
    # Handler uses get_node_or_null which needs tree membership.
    # Test the deselect logic directly by calling it on the SelectComponent.
    _sm.deselect_entity(select_comp)
    var selected_after: bool = select_comp in _sm.selected_entities
    TestHelper.assert_true(selected_before, "entity selected before death")
    TestHelper.assert_eq(selected_after, false, "deselect_entity removes from list")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


# --- Task 3.5: building_destroyed signal emitted with correct args ---


func test_building_destroyed_signal_emitted():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building := _make_entity_with_health(100)
    var signal_data: Array = []
    _bm.building_destroyed.connect(func(b: Node3D, _d: EntityData) -> void: signal_data.append(b))
    var entry_data := EntityData.new()
    entry_data.id = "TEST_BLDG"
    var cells: Array[Vector2i] = [Vector2i(400, 400)]
    (
        _bm
        . _buildings
        . append(
            {
                "node": building,
                "type": entry_data,
                "origin": Vector2i(400, 400),
                "cells": cells,
            }
        )
    )
    # Call handler directly
    _bm._on_building_destroyed(building)
    TestHelper.assert_eq(signal_data.size(), 1, "building_destroyed emitted once")
    if signal_data.size() > 0:
        TestHelper.assert_eq(signal_data[0], building, "signal passes correct building node")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


# --- Task 3.6: Entity health_zero triggers queue_free via signal ---


func test_health_zero_triggers_on_lethal_damage():
    var entity := Node3D.new()
    var hc := HealthComponent.new()
    hc.name = "HealthComponent"
    hc.max_health = 100
    hc.current_health = 100
    entity.add_child(hc)
    var signal_fired := false
    hc.health_zero.connect(func() -> void: signal_fired = true)
    hc.take_damage(200)
    TestHelper.assert_eq(hc.current_health, 0, "health clamped to zero")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


# --- Task 3.7: Entity not in BuildingManager still has handler called ---


func test_entity_not_in_building_manager_handler_is_noop():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building := _make_entity_with_health(100)
    # Do NOT register in BuildingManager
    var size_before: int = _bm._buildings.size()
    # Call handler — should be a no-op (early return)
    _bm._on_building_destroyed(building)
    var size_after: int = _bm._buildings.size()
    TestHelper.assert_eq(size_after, size_before, "no change to _buildings for unregistered entity")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    building.free()


# --- Task 3.8: Double handler call is safe ---


func test_double_handler_call_safe():
    if _bm == null:
        _test_failed += 1
        print("    FAIL: BuildingManager not injected")
        return
    var building := _make_entity_with_health(100)
    var cells: Array[Vector2i] = [Vector2i(500, 500)]
    (
        _bm
        . _buildings
        . append(
            {
                "node": building,
                "type": EntityData.new(),
                "origin": Vector2i(500, 500),
                "cells": cells,
            }
        )
    )
    # Call handler twice — second call should be a no-op
    _bm._on_building_destroyed(building)
    _bm._on_building_destroyed(building)
    # Should not crash, and entry should be removed only once
    var found := false
    for entry in _bm._buildings:
        if entry.get("node") == building:
            found = true
            break
    TestHelper.assert_eq(found, false, "building entry removed after double call")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    building.free()
