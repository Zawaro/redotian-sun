extends Node

# HarvestComponent dock-state tests
# Tests the DOCKING rotation flow and DockUnloadComponent integration.
# Uses mock nodes — no autoloads required except what the runner injects.

var _test_passed := 0
var _test_failed := 0
var _slot_emitted_flag := false

# --- helpers ---


func _make_entity(dock_id: String = "PROC", storage: int = 700) -> Node3D:
    var entity := Node3D.new()
    entity.name = "TestHarvester"

    var transport := TransportComponent.new()
    transport.name = "TransportComponent"
    transport.dock = dock_id
    transport.storage = storage
    transport.cargo = {"tiberium_green": storage}
    entity.add_child(transport)

    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)

    var harvest := HarvestComponent.new()
    harvest.name = "HarvestComponent"
    entity.add_child(harvest)

    return entity


func _make_dock_entity(
    dock_rotation: float = -90.0, _foundation: Vector2i = Vector2i(4, 3), _dock_id: String = "PROC"
) -> Node3D:
    var dock_entity := Node3D.new()
    dock_entity.name = "TestRefinery"

    var dock_comp := DockHostComponent.new()
    dock_comp.name = "DockHostComponent"
    dock_comp.dock_rotation = dock_rotation
    dock_comp.dock_types = ["harvest"]
    dock_entity.add_child(dock_comp)

    var dock_unload := DockUnloadComponent.new()
    dock_unload.name = "DockUnloadComponent"
    dock_unload.unload_rate = 100.0
    dock_entity.add_child(dock_unload)

    return dock_entity


func _get_harvest(entity: Node3D) -> HarvestComponent:
    return entity.get_node("HarvestComponent") as HarvestComponent


func _get_transport(entity: Node3D) -> TransportComponent:
    return entity.get_node("TransportComponent") as TransportComponent


func _get_dock_comp(dock_entity: Node3D) -> DockHostComponent:
    return dock_entity.get_node("DockHostComponent") as DockHostComponent


func _get_dock_unload(dock_entity: Node3D) -> DockUnloadComponent:
    return dock_entity.get_node("DockUnloadComponent") as DockUnloadComponent


# Test node is not in scene tree, so _ready() never fires.
# These helpers manually set what _ready() would compute.


func _init_harvest(_harvest: HarvestComponent, _dock_id: String = "PROC") -> void:
    pass  # ponytail: _dock_id was on old HarvestComponent, removed in dock-host-client-refactor


func _init_dock(dock_comp: DockHostComponent, dock_entity: Node3D) -> void:
    var cs := Pathfinder.CELL_SIZE
    var found := dock_comp._get_foundation()
    var origin_cell := Vector2i(
        floori((dock_entity.position.x - found.x * 0.5 * cs) / cs),
        floori((dock_entity.position.z - found.y * 0.5 * cs) / cs)
    )
    var top_left := Pathfinder.cell_to_world(origin_cell)
    dock_comp._dock_cell = Pathfinder.world_to_cell(
        top_left + dock_entity.global_transform.basis * dock_comp.dock_position
    )


func _on_slot_signal() -> void:
    _slot_emitted_flag = true


# --- tests ---


func test_docking_rotates_toward_target():
    var entity := _make_entity()
    add_child(entity)
    var dock_entity := _make_dock_entity(-90.0)
    add_child(dock_entity)

    var harvest := _get_harvest(entity)
    var dock_comp := _get_dock_comp(dock_entity)

    # Set up state: entity at dock cell, state DOCKING, rotation off target
    entity.rotation.y = deg_to_rad(0.0)
    harvest._current_dock = dock_entity
    harvest._state = HarvestComponent.State.DOCKING

    # Simulate one _process frame with delta=0.016
    harvest._process(0.016)

    # Should have rotated toward -90° but not reached it yet
    var rotated_to := rad_to_deg(entity.rotation.y)
    var passed := rotated_to < 0.0 and rotated_to > -90.0
    if passed:
        _test_passed += 1
        print("    PASS: DOCKING rotates toward target (%.1f°)" % rotated_to)
    else:
        _test_failed += 1
        print("    FAIL: expected rotation between 0° and -90°, got %.1f°" % rotated_to)

    entity.queue_free()
    dock_entity.queue_free()


func test_docking_completes_rotation_and_transitions_to_unloading():
    var entity := _make_entity()
    add_child(entity)
    var dock_entity := _make_dock_entity(-90.0)
    add_child(dock_entity)

    var harvest := _get_harvest(entity)
    var dock_unload := _get_dock_unload(dock_entity)

    # Set up: almost at target rotation (within 0.05 rad ≈ 2.86°)
    entity.rotation.y = deg_to_rad(-88.0)
    harvest._current_dock = dock_entity
    harvest._state = HarvestComponent.State.DOCKING

    # DockUnloadComponent starts disabled
    var was_processing_before := dock_unload.is_processing()

    harvest._process(0.016)

    # Should be UNLOADING now
    var state_ok := harvest._state == HarvestComponent.State.UNLOADING
    var rotation_ok: bool = absf(entity.rotation.y - deg_to_rad(-90.0)) < 0.05
    var unload_started := dock_unload.is_processing()

    if state_ok and rotation_ok and unload_started:
        _test_passed += 1
        print("    PASS: DOCKING → UNLOADING with rotation snap + begin_unload")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: state=%d (want %d), rot=%.1f (want -90), unload_started=%s"
                % [
                    harvest._state,
                    HarvestComponent.State.UNLOADING,
                    rad_to_deg(entity.rotation.y),
                    unload_started,
                ]
            )
        )
        if not was_processing_before:
            print("    (dock_unload was disabled before, now=%s)" % unload_started)

    entity.queue_free()
    dock_entity.queue_free()


func test_docking_returns_to_idle_when_dock_invalid():
    var entity := _make_entity()
    add_child(entity)

    var harvest := _get_harvest(entity)
    harvest._state = HarvestComponent.State.DOCKING
    harvest._current_dock = null

    harvest._process(0.016)

    if harvest._state == HarvestComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: DOCKING → IDLE when dock invalid")
    else:
        _test_failed += 1
        print("    FAIL: expected IDLE (0), got %d" % harvest._state)

    entity.queue_free()


func test_on_dock_undocked_ignores_docking_state():
    var entity := _make_entity()
    add_child(entity)
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)

    var harvest := _get_harvest(entity)
    harvest._current_dock = dock_entity
    harvest._state = HarvestComponent.State.DOCKING

    harvest.on_dock_undocked(dock_entity)

    if harvest._state == HarvestComponent.State.DOCKING:
        _test_passed += 1
        print("    PASS: on_dock_undocked ignores DOCKING state (only handles UNLOADING)")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: state=%d (want DOCKING=%d)"
                % [harvest._state, HarvestComponent.State.DOCKING]
            )
        )

    entity.queue_free()
    dock_entity.queue_free()


func test_on_dock_undocked_handles_unloading_state():
    var entity := _make_entity()
    add_child(entity)
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)

    var harvest := _get_harvest(entity)
    harvest._current_dock = dock_entity
    harvest._state = HarvestComponent.State.UNLOADING

    harvest.on_dock_undocked(dock_entity)

    if harvest._state == HarvestComponent.State.IDLE and harvest._current_dock == null:
        _test_passed += 1
        print("    PASS: on_dock_undocked transitions UNLOADING → IDLE")
    else:
        _test_failed += 1
        print("    FAIL: state=%d (want 0), dock=%s" % [harvest._state, harvest._current_dock])

    entity.queue_free()
    dock_entity.queue_free()


func test_dock_unload_begin_unload_enables_processing():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)

    var dock_unload := _get_dock_unload(dock_entity)
    var was_before := dock_unload.is_processing()

    dock_unload.begin_unload()
    var is_after := dock_unload.is_processing()

    if not was_before and is_after:
        _test_passed += 1
        print("    PASS: begin_unload() enables processing")
    else:
        _test_failed += 1
        print("    FAIL: before=%s, after=%s" % [was_before, is_after])

    dock_entity.queue_free()


func test_dock_unload_stops_on_undocked():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)

    var dock_unload := _get_dock_unload(dock_entity)
    dock_unload.begin_unload()
    var was_processing := dock_unload.is_processing()

    # Simulate undocked signal
    dock_unload._on_docker_undocked(dock_entity)
    var is_after := dock_unload.is_processing()

    if was_processing and not is_after:
        _test_passed += 1
        print("    PASS: docker_undocked stops processing")
    else:
        _test_failed += 1
        print("    FAIL: before=%s, after=%s" % [was_processing, is_after])

    dock_entity.queue_free()


func test_cancel_harvest_clears_state():
    var entity := _make_entity()
    add_child(entity)

    var harvest := _get_harvest(entity)
    harvest._current_resource = Node3D.new()
    harvest._current_dock = Node3D.new()
    harvest._state = HarvestComponent.State.HARVESTING

    harvest.cancel_harvest()

    if (
        harvest._state == HarvestComponent.State.IDLE
        and harvest._current_resource == null
        and harvest._current_dock == null
    ):
        _test_passed += 1
        print("    PASS: cancel_harvest clears all state to IDLE")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: state=%d, crystal=%s, dock=%s"
                % [harvest._state, harvest._current_resource, harvest._current_dock]
            )
        )

    entity.queue_free()


func test_change_state_noop_on_same_state():
    var entity := _make_entity()
    add_child(entity)

    var harvest := _get_harvest(entity)
    harvest._state = HarvestComponent.State.IDLE

    var emitted := false
    harvest.state_changed.connect(func(_s): emitted = true)
    harvest._change_state(HarvestComponent.State.IDLE)

    if not emitted:
        _test_passed += 1
        print("    PASS: _change_state is a no-op for same state")
    else:
        _test_failed += 1
        print("    FAIL: state_changed emitted for same-state transition")

    entity.queue_free()


# --- DockHostComponent: request_dock / leave_dock / reservation ---


func test_request_dock_succeeds_when_empty():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var entity := _make_entity()
    add_child(entity)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest := _get_harvest(entity)
    _init_harvest(harvest)
    _init_dock(dock_comp, dock_entity)

    var result: bool = dock_comp.request_dock(harvest)

    if result and dock_comp.current_docker == harvest:
        _test_passed += 1
        print("    PASS: request_dock succeeds when dock is empty")
    else:
        _test_failed += 1
        print("    FAIL: result=%s, current_docker=%s" % [result, dock_comp.current_docker])

    entity.queue_free()
    dock_entity.queue_free()


func test_request_dock_fails_when_occupied():
    var dock_entity := _make_dock_entity(-90.0, Vector2i(4, 3), "PROC")
    add_child(dock_entity)
    var entity_a := _make_entity("PROC")
    add_child(entity_a)
    var entity_b := _make_entity("PROC")
    add_child(entity_b)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest_a := _get_harvest(entity_a)
    var harvest_b := _get_harvest(entity_b)
    _init_harvest(harvest_a, "PROC")
    _init_harvest(harvest_b, "PROC")
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest_a)
    var result: bool = dock_comp.request_dock(harvest_b)

    if not result and dock_comp.current_docker == harvest_a:
        _test_passed += 1
        print("    PASS: request_dock fails when another docker is active")
    else:
        _test_failed += 1
        print("    FAIL: result=%s, current_docker=%s" % [result, dock_comp.current_docker])

    entity_a.queue_free()
    entity_b.queue_free()
    dock_entity.queue_free()


func test_request_dock_returns_true_for_same_docker():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var entity := _make_entity()
    add_child(entity)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest := _get_harvest(entity)
    _init_harvest(harvest)
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest)
    var result: bool = dock_comp.request_dock(harvest)

    if result:
        _test_passed += 1
        print("    PASS: request_dock returns true for same docker (re-dock)")
    else:
        _test_failed += 1
        print("    FAIL: re-dock returned false")

    entity.queue_free()
    dock_entity.queue_free()


func test_request_dock_queues_second_docker():
    var dock_entity := _make_dock_entity(-90.0, Vector2i(4, 3), "PROC")
    add_child(dock_entity)
    var entity_a := _make_entity("PROC")
    add_child(entity_a)
    var entity_b := _make_entity("PROC")
    add_child(entity_b)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest_a := _get_harvest(entity_a)
    var harvest_b := _get_harvest(entity_b)
    _init_harvest(harvest_a, "PROC")
    _init_harvest(harvest_b, "PROC")
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest_a)
    var result: bool = dock_comp.request_dock(harvest_b)

    if not result and dock_comp.queue.has(harvest_b):
        _test_passed += 1
        print("    PASS: second docker is queued when dock is occupied")
    else:
        _test_failed += 1
        print("    FAIL: result=%s, in_queue=%s" % [result, dock_comp.queue.has(harvest_b)])

    entity_a.queue_free()
    entity_b.queue_free()
    dock_entity.queue_free()


func test_leave_dock_releases_cell():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var entity := _make_entity()
    add_child(entity)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest := _get_harvest(entity)
    _init_harvest(harvest)
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest)
    var dock_cell := dock_comp._dock_cell

    dock_comp.leave_dock(harvest)

    var key: int = SpatialHash.instance._cell_key(dock_cell)
    var still_reserved: bool = SpatialHash.instance._reserved.has(key)

    if not still_reserved and dock_comp.current_docker == null:
        _test_passed += 1
        print("    PASS: leave_dock releases dock cell and clears current_docker")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: still_reserved=%s, current_docker=%s"
                % [still_reserved, dock_comp.current_docker]
            )
        )

    entity.queue_free()
    dock_entity.queue_free()


func test_leave_dock_reserves_cell_for_next_docker():
    var dock_entity := _make_dock_entity(-90.0, Vector2i(4, 3), "PROC")
    add_child(dock_entity)
    var entity_a := _make_entity("PROC")
    add_child(entity_a)
    var entity_b := _make_entity("PROC")
    add_child(entity_b)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest_a := _get_harvest(entity_a)
    var harvest_b := _get_harvest(entity_b)
    _init_harvest(harvest_a, "PROC")
    _init_harvest(harvest_b, "PROC")
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest_a)
    dock_comp.request_dock(harvest_b)  # queued
    var dock_cell := dock_comp._dock_cell

    dock_comp.leave_dock(harvest_a)  # transfers to B

    var key: int = SpatialHash.instance._cell_key(dock_cell)
    var reserved_for_b: bool = SpatialHash.instance._reserved.has(key)

    if reserved_for_b and dock_comp.current_docker == harvest_b:
        _test_passed += 1
        print("    PASS: leave_dock reserves dock cell for next queued docker")
    else:
        _test_failed += 1
        print(
            "    FAIL: reserved=%s, current_docker=%s" % [reserved_for_b, dock_comp.current_docker]
        )

    entity_a.queue_free()
    entity_b.queue_free()
    dock_entity.queue_free()


func test_leave_dock_emits_slot_available():
    var dock_entity := _make_dock_entity(-90.0, Vector2i(4, 3), "PROC")
    add_child(dock_entity)
    var entity_a := _make_entity("PROC")
    add_child(entity_a)
    var entity_b := _make_entity("PROC")
    add_child(entity_b)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest_a := _get_harvest(entity_a)
    var harvest_b := _get_harvest(entity_b)
    _init_harvest(harvest_a, "PROC")
    _init_harvest(harvest_b, "PROC")
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest_a)
    dock_comp.request_dock(harvest_b)  # queued

    _slot_emitted_flag = false
    dock_comp.slot_available.connect(_on_slot_signal)

    dock_comp.leave_dock(harvest_a)

    if _slot_emitted_flag:
        _test_passed += 1
        print("    PASS: leave_dock emits slot_available when queue has next docker")
    else:
        _test_failed += 1
        print("    FAIL: slot_available was not emitted")

    entity_a.queue_free()
    entity_b.queue_free()
    dock_entity.queue_free()


func test_leave_dock_no_slot_available_when_queue_empty():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var entity := _make_entity()
    add_child(entity)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest := _get_harvest(entity)
    _init_harvest(harvest)
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest)

    var slot_emitted := false
    dock_comp.slot_available.connect(func(): slot_emitted = true)

    dock_comp.leave_dock(harvest)

    if not slot_emitted:
        _test_passed += 1
        print("    PASS: leave_dock does not emit slot_available when queue is empty")
    else:
        _test_failed += 1
        print("    FAIL: slot_available was emitted with empty queue")

    entity.queue_free()
    dock_entity.queue_free()


func test_leave_dock_removes_from_queue():
    var dock_entity := _make_dock_entity(-90.0, Vector2i(4, 3), "PROC")
    add_child(dock_entity)
    var entity_a := _make_entity("PROC")
    add_child(entity_a)
    var entity_b := _make_entity("PROC")
    add_child(entity_b)
    var entity_c := _make_entity("PROC")
    add_child(entity_c)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest_a := _get_harvest(entity_a)
    var harvest_b := _get_harvest(entity_b)
    var harvest_c := _get_harvest(entity_c)
    _init_harvest(harvest_a, "PROC")
    _init_harvest(harvest_b, "PROC")
    _init_harvest(harvest_c, "PROC")
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest_a)
    dock_comp.request_dock(harvest_b)  # queued
    dock_comp.request_dock(harvest_c)  # queued

    # B cancels (leaves queue without being current_docker)
    dock_comp.leave_dock(harvest_b)

    if not dock_comp.queue.has(harvest_b) and dock_comp.queue.has(harvest_c):
        _test_passed += 1
        print("    PASS: leave_dock removes non-current docker from queue")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: b_in_queue=%s, c_in_queue=%s"
                % [dock_comp.queue.has(harvest_b), dock_comp.queue.has(harvest_c)]
            )
        )

    entity_a.queue_free()
    entity_b.queue_free()
    entity_c.queue_free()
    dock_entity.queue_free()


func test_on_slot_available_triggers_try_dock():
    var entity := _make_entity()
    add_child(entity)
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)

    var harvest := _get_harvest(entity)
    _init_harvest(harvest)
    _init_dock(_get_dock_comp(dock_entity), dock_entity)

    harvest._state = HarvestComponent.State.QUEUED
    harvest._current_dock = dock_entity

    harvest.on_slot_available()

    if harvest._state == HarvestComponent.State.DOCKING:
        _test_passed += 1
        print("    PASS: on_slot_available triggers _try_dock → DOCKING")
    else:
        _test_failed += 1
        print("    FAIL: state=%d (want %d)" % [harvest._state, HarvestComponent.State.DOCKING])

    entity.queue_free()
    dock_entity.queue_free()


func test_on_slot_available_ignores_non_queued():
    var entity := _make_entity()
    add_child(entity)
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)

    var harvest := _get_harvest(entity)
    harvest._state = HarvestComponent.State.IDLE  # not QUEUED

    harvest.on_slot_available()

    if harvest._state == HarvestComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: on_slot_available is a no-op when not QUEUED")
    else:
        _test_failed += 1
        print("    FAIL: state changed to %d" % harvest._state)

    entity.queue_free()
    dock_entity.queue_free()


# --- DockHostComponent: _compute_dock_cell ---


func test_dock_cell_computed_by_helper():
    var dock_entity := _make_dock_entity()
    dock_entity.position = Vector3(10.0, 0.0, 8.0)
    add_child(dock_entity)

    var dock_comp := _get_dock_comp(dock_entity)
    _init_dock(dock_comp, dock_entity)

    # _dock_cell should be computed from position + foundation + dock_position
    var is_computed: bool = dock_comp._dock_cell != Vector2i.ZERO

    if is_computed:
        _test_passed += 1
        print("    PASS: _init_dock computes _dock_cell correctly")
    else:
        _test_failed += 1
        print("    FAIL: _dock_cell is still Vector2i.ZERO")

    dock_entity.queue_free()


# --- Full dock cycle ---


func test_full_dock_cycle_leave_transfers_to_next():
    var dock_entity := _make_dock_entity(-90.0, Vector2i(4, 3), "PROC")
    add_child(dock_entity)
    var entity_a := _make_entity("PROC")
    add_child(entity_a)
    var entity_b := _make_entity("PROC")
    add_child(entity_b)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest_a := _get_harvest(entity_a)
    var harvest_b := _get_harvest(entity_b)
    _init_harvest(harvest_a, "PROC")
    _init_harvest(harvest_b, "PROC")
    _init_dock(dock_comp, dock_entity)

    # A docks
    dock_comp.request_dock(harvest_a)
    var docked_a: bool = dock_comp.current_docker == harvest_a

    # B tries to dock — queued
    dock_comp.request_dock(harvest_b)
    var queued_b: bool = dock_comp.queue.has(harvest_b)

    # A leaves — B should become current_docker
    dock_comp.leave_dock(harvest_a)
    var transferred: bool = dock_comp.current_docker == harvest_b
    var queue_empty: bool = dock_comp.queue.is_empty()

    # Dock cell should be reserved for B
    var key: int = SpatialHash.instance._cell_key(dock_comp._dock_cell)
    var cell_reserved: bool = SpatialHash.instance._reserved.has(key)

    if docked_a and queued_b and transferred and queue_empty and cell_reserved:
        _test_passed += 1
        print("    PASS: full dock cycle: A docks → B queued → A leaves → B docked + cell reserved")
    else:
        _test_failed += 1
        var msg := "    FAIL: docked_a=%s queued_b=%s transferred=%s"
        msg += " queue_empty=%s cell_reserved=%s"
        print(msg % [docked_a, queued_b, transferred, queue_empty, cell_reserved])

    entity_a.queue_free()
    entity_b.queue_free()
    dock_entity.queue_free()


func test_request_dock_does_not_re_reserve_for_same_docker():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var entity := _make_entity()
    add_child(entity)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest := _get_harvest(entity)
    _init_harvest(harvest)
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest)
    var key_before: int = SpatialHash.instance._cell_key(dock_comp._dock_cell)

    # Call request_dock again for same docker
    dock_comp.request_dock(harvest)
    # Cell should still be reserved (no double-reserve issue)
    var still_reserved: bool = SpatialHash.instance._reserved.has(key_before)

    if still_reserved:
        _test_passed += 1
        print("    PASS: re-request_dock for same docker preserves reservation")
    else:
        _test_failed += 1
        print("    FAIL: reservation lost after re-request_dock")

    entity.queue_free()
    dock_entity.queue_free()


# --- is_cell_available: building cell check ---


func test_is_cell_available_rejects_building_cell():
    if SpatialHash.instance == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not available")
        return

    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var dock_comp := _get_dock_comp(dock_entity)
    _init_dock(dock_comp, dock_entity)

    var building_cell := Vector2i(5, 5)
    var building_cells: Array[Vector2i] = [building_cell]
    SpatialHash.instance.register_building_cells(building_cells)

    var available: bool = dock_comp.is_cell_available(building_cell)

    SpatialHash.instance.unregister_building_cells(building_cells)

    if not available:
        _test_passed += 1
        print("    PASS: is_cell_available returns false for building cell")
    else:
        _test_failed += 1
        print("    FAIL: is_cell_available returned true for building cell")

    dock_entity.queue_free()


func test_is_cell_available_allows_bib_cell():
    if SpatialHash.instance == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not available")
        return

    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var dock_comp := _get_dock_comp(dock_entity)
    _init_dock(dock_comp, dock_entity)

    var bib_cell := Vector2i(6, 5)
    var bib_cells: Array[Vector2i] = [bib_cell]
    SpatialHash.instance.register_bib_cells(bib_cells)

    var available: bool = dock_comp.is_cell_available(bib_cell)

    SpatialHash.instance._bib_cells.erase(SpatialHash.instance._cell_key(bib_cell))

    if available:
        _test_passed += 1
        print("    PASS: is_cell_available returns true for bib cell")
    else:
        _test_failed += 1
        print("    FAIL: is_cell_available returned false for bib cell")

    dock_entity.queue_free()


# --- _find_nearest_dock: dock cell distance ---


func test_find_nearest_dock_uses_dock_cell_distance():
    var dock_a := _make_dock_entity(-90.0, Vector2i(4, 3), "PROC")
    dock_a.position = Vector3(0.0, 0.0, 0.0)
    add_child(dock_a)

    var dock_b := _make_dock_entity(-90.0, Vector2i(4, 3), "PROC")
    dock_b.position = Vector3(10.0, 0.0, 0.0)
    add_child(dock_b)

    _init_dock(_get_dock_comp(dock_a), dock_a)
    _init_dock(_get_dock_comp(dock_b), dock_b)

    # Place harvester closer to dock_a's dock cell
    var entity := _make_entity("PROC")
    entity.position = Vector3(3.0, 0.0, 3.0)
    add_child(entity)

    var parent_cell := Pathfinder.world_to_cell(entity.global_position)
    var dock_a_cell := Pathfinder.world_to_cell(
        Pathfinder.cell_to_world(_get_dock_comp(dock_a)._dock_cell)
    )
    var dock_b_cell := Pathfinder.world_to_cell(
        Pathfinder.cell_to_world(_get_dock_comp(dock_b)._dock_cell)
    )
    var dist_a := Vector2(parent_cell - dock_a_cell).length_squared()
    var dist_b := Vector2(parent_cell - dock_b_cell).length_squared()

    if dist_a < dist_b:
        _test_passed += 1
        print(
            (
                "    PASS: dock_a dock cell is closer (dist_a=%.1f, dist_b=%.1f)"
                % [sqrt(dist_a), sqrt(dist_b)]
            )
        )
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: dock_a should be closer (dist_a=%.1f, dist_b=%.1f)"
                % [sqrt(dist_a), sqrt(dist_b)]
            )
        )

    entity.queue_free()
    dock_a.queue_free()
    dock_b.queue_free()
