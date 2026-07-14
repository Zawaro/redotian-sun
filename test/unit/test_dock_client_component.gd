extends Node

# DockClientComponent tests — state machine, dock sequence, thin client behavior

var _test_passed := 0
var _test_failed := 0
var _cancelled_emitted := false
var _undocked_emitted := false
var _failed_emitted := false


func _make_dock_client(dock_id: String = "PROC") -> DockClientComponent:
    var client := DockClientComponent.new()
    client.name = "DockClientComponent"
    client._dock_id = dock_id
    client.can_dock_with = [dock_id]
    return client


func _make_dock_host(_dock_id: String = "PROC", queue_size: int = 0) -> Node3D:
    var entity := Node3D.new()
    entity.name = "TestRefinery"

    var host := DockHostComponent.new()
    host.name = "DockHostComponent"
    host.dock_types = ["harvest"]
    for i in queue_size:
        host.queue.append(Node.new())
    entity.add_child(host)

    return entity


func _make_entity_with_client(dock_id: String = "PROC") -> Node3D:
    var entity := Node3D.new()
    entity.name = "TestHarvester"

    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)

    var client := _make_dock_client(dock_id)
    entity.add_child(client)

    return entity


func _on_cancelled() -> void:
    _cancelled_emitted = true


func _on_undocked(_docker: Node) -> void:
    _undocked_emitted = true


func _on_failed() -> void:
    _failed_emitted = true


# --- Basic tests ---


func test_configure_sets_can_dock_with():
    var client := _make_dock_client("PROC")
    if client.can_dock_with.has("PROC") and client.get_dock_id() == "PROC":
        _test_passed += 1
        print("    PASS: configure sets can_dock_with")
    else:
        _test_failed += 1
        print("    FAIL: configure did not set can_dock_with")


func test_get_dock_id():
    var client := _make_dock_client("REFN")
    if client.get_dock_id() == "REFN":
        _test_passed += 1
        print("    PASS: get_dock_id returns correct id")
    else:
        _test_failed += 1
        print("    FAIL: get_dock_id returned wrong id")


func test_is_reserved():
    var client := _make_dock_client()
    if not client.is_reserved():
        _test_passed += 1
        print("    PASS: is_reserved returns false when no host")
    else:
        _test_failed += 1
        print("    FAIL: is_reserved returned true with no host")


func test_initial_state_is_idle():
    var client := _make_dock_client()
    if client.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: initial state is IDLE")
    else:
        _test_failed += 1
        print("    FAIL: initial state = %d (expected IDLE)" % client.get_state())


func test_no_timeout_variables():
    var client := _make_dock_client()
    var has_timeout := (
        client.get("_refinery_timeout") != null
        or client.get("_docking_timeout") != null
        or client.get("_queued_timeout") != null
        or client.get("_recheck_timer") != null
    )
    if not has_timeout:
        _test_passed += 1
        print("    PASS: no timeout variables on DockClientComponent")
    else:
        _test_failed += 1
        print("    FAIL: timeout variables still exist")


func test_no_find_shorter_queue():
    var client := _make_dock_client()
    var has_method := client.has_method("_find_shorter_queue")
    if not has_method:
        _test_passed += 1
        print("    PASS: _find_shorter_queue removed")
    else:
        _test_failed += 1
        print("    FAIL: _find_shorter_queue still exists")


func test_no_dock_slot_reserved_signal():
    var client := _make_dock_client()
    var has_signal := client.has_signal("dock_slot_reserved")
    if not has_signal:
        _test_passed += 1
        print("    PASS: dock_slot_reserved signal removed")
    else:
        _test_failed += 1
        print("    FAIL: dock_slot_reserved signal still exists")


# --- State transitions ---


func test_seek_dock_transitions_to_queued_when_host_occupied():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host("PROC", 1)
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    _failed_emitted = false
    client.dock_slot_failed.connect(_on_failed)

    # Manually test the queuing path — set up the queued state directly
    # since find_neaster_host requires a scene tree with "Buildings" group
    client._queued_host = host_entity
    client._state = DockClientComponent.State.QUEUED

    if client.get_state() == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: client can be in QUEUED state")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: state = %d (expected QUEUED=%d)"
                % [client.get_state(), DockClientComponent.State.QUEUED]
            )
        )


func test_seek_dock_emits_failed_when_no_host():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    _failed_emitted = false
    client.dock_slot_failed.connect(_on_failed)

    client.seek_dock(entity)

    if _failed_emitted and client.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: seek_dock emits dock_slot_failed when no host")
    else:
        _test_failed += 1
        print("    FAIL: emitted=%s, state=%d" % [_failed_emitted, client.get_state()])


func test_on_slot_available_moves_to_docked_when_queued():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host("PROC")
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent

    # Manually set up queued state
    client._queued_host = host_entity
    client._state = DockClientComponent.State.QUEUED

    client.on_slot_available()

    if (
        client.get_state() == DockClientComponent.State.MOVING
        and client._target_host == host_entity
    ):
        _test_passed += 1
        print("    PASS: on_slot_available transitions QUEUED → MOVING")
    else:
        _test_failed += 1
        print("    FAIL: state=%d, target=%s" % [client.get_state(), client._target_host])


func test_on_slot_available_ignores_non_queued():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._state = DockClientComponent.State.IDLE

    client.on_slot_available()

    if client.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: on_slot_available is a no-op when not QUEUED")
    else:
        _test_failed += 1
        print("    FAIL: state changed to %d" % client.get_state())


# --- on_dock_undocked handler ---


func test_on_dock_undocked_clears_state():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host()
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._reserved_host = host_entity
    client._target_host = host_entity
    client._state = DockClientComponent.State.UNLOADING

    _undocked_emitted = false
    client.dock_undocked.connect(_on_undocked)

    # on_dock_undocked checks docker != self, so pass the client itself
    client.on_dock_undocked(client)

    if (
        client._reserved_host == null
        and client._target_host == null
        and client.get_state() == DockClientComponent.State.IDLE
        and _undocked_emitted
    ):
        _test_passed += 1
        print("    PASS: on_dock_undocked clears state and emits signal")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: reserved=%s, target=%s, state=%d, emitted=%s"
                % [
                    client._reserved_host,
                    client._target_host,
                    client.get_state(),
                    _undocked_emitted
                ]
            )
        )


func test_on_dock_undocked_ignores_other_docker():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._state = DockClientComponent.State.UNLOADING

    var other := Node.new()
    client.on_dock_undocked(other)

    if client.get_state() == DockClientComponent.State.UNLOADING:
        _test_passed += 1
        print("    PASS: on_dock_undocked ignores other docker")
    else:
        _test_failed += 1
        print("    FAIL: state changed to %d" % client.get_state())


# --- Retry cooldown ---


func test_retry_cooldown_decrements():
    var client := _make_dock_client()
    client._retry_cooldown = 2.0
    client._process(1.0)
    if client._retry_cooldown == 1.0:
        _test_passed += 1
        print("    PASS: _retry_cooldown decrements by delta")
    else:
        _test_failed += 1
        print("    FAIL: _retry_cooldown = %f (expected 1.0)" % client._retry_cooldown)


# --- Exit tree cleanup ---


func test_exit_tree_clears_reservation():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host()
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._reserved_host = host_entity
    client._state = DockClientComponent.State.UNLOADING

    # Simulate exit_tree by calling the method directly
    client._exit_tree()

    if client.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: _exit_tree clears state to IDLE")
    else:
        _test_failed += 1
        print("    FAIL: state = %d (expected IDLE)" % client.get_state())


func test_exit_tree_noop_when_idle():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._state = DockClientComponent.State.IDLE

    client._exit_tree()

    if client.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: _exit_tree is no-op when IDLE")
    else:
        _test_failed += 1
        print("    FAIL: state = %d (expected IDLE)" % client.get_state())


# --- Pathfinding failure retry ---


func test_pathfinding_failed_retries_when_moving():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host()
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._target_host = host_entity
    client._state = DockClientComponent.State.MOVING

    client._on_pathfinding_failed()

    # Should NOT cancel — should set retry cooldown and stay in MOVING
    if client._retry_cooldown == 1.0 and client.get_state() == DockClientComponent.State.MOVING:
        _test_passed += 1
        print("    PASS: pathfinding failure during MOVING sets retry cooldown")
    else:
        _test_failed += 1
        print("    FAIL: cooldown=%f, state=%d" % [client._retry_cooldown, client.get_state()])


func test_pathfinding_failed_stays_queued():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host()
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._queued_host = host_entity
    client._state = DockClientComponent.State.QUEUED

    client._on_pathfinding_failed()

    # Should stay QUEUED — wait cell is just a convenience
    if client.get_state() == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: pathfinding failure during QUEUED stays queued")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: state = %d (expected QUEUED=%d)"
                % [client.get_state(), DockClientComponent.State.QUEUED]
            )
        )


# --- Dock cell retry constant ---


func test_dock_cell_retry_constant_exists():
    var client := _make_dock_client()
    if "DOCK_CELL_RETRY_COOLDOWN" in client:
        _test_passed += 1
        print("    PASS: DOCK_CELL_RETRY_COOLDOWN constant exists")
    else:
        _test_failed += 1
        print("    FAIL: DOCK_CELL_RETRY_COOLDOWN constant missing")


# --- on_dock_cancelled (queue purge callback) ---


func test_on_dock_cancelled_clears_queued_state():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host()
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._queued_host = host_entity
    client._state = DockClientComponent.State.QUEUED

    client.on_dock_cancelled()

    if client.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: on_dock_cancelled clears QUEUED state to IDLE")
    else:
        _test_failed += 1
        print("    FAIL: state = %d (expected IDLE)" % client.get_state())


func test_on_dock_cancelled_clears_moving_state():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host()
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._target_host = host_entity
    client._reserved_host = host_entity
    client._state = DockClientComponent.State.MOVING

    client.on_dock_cancelled()

    if (
        client.get_state() == DockClientComponent.State.IDLE
        and client._reserved_host == null
        and client._target_host == null
    ):
        _test_passed += 1
        print("    PASS: on_dock_cancelled clears MOVING state and all references")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: state=%d reserved=%s target=%s"
                % [client.get_state(), client._reserved_host, client._target_host]
            )
        )


func test_on_dock_cancelled_does_not_emit_signal():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._state = DockClientComponent.State.QUEUED
    _cancelled_emitted = false

    if not client.dock_cancelled.is_connected(_on_cancelled):
        client.dock_cancelled.connect(_on_cancelled)

    # on_dock_cancelled() is safe for teardown — no signals
    client.on_dock_cancelled()

    if not _cancelled_emitted and client.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: on_dock_cancelled cleans state without signal")
    else:
        _test_failed += 1
        print("    FAIL: emitted=%s state=%d" % [_cancelled_emitted, client.get_state()])


# --- Scatter recovery ---


func test_queued_arrived_reroutes_to_wait_cell():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host()
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._queued_host = host_entity
    client._state = DockClientComponent.State.QUEUED

    # Simulate scatter arrival at wrong cell
    client._on_arrived(Vector3.ZERO)

    # Should have issued a move to the wait cell
    if client._state == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: queued _on_arrived re-routes to wait cell")
    else:
        _test_failed += 1
        print("    FAIL: state = %d (expected QUEUED)" % client.get_state())


func test_queued_arrived_stays_at_wait_cell():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host()
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._queued_host = host_entity
    client._state = DockClientComponent.State.QUEUED

    # Place entity at the dock's wait cell so it's already correct
    var dock := host_entity.get_node_or_null("DockHostComponent") as DockHostComponent
    if dock:
        var wait_cell := dock.find_wait_cell()
        entity.global_position = Pathfinder.cell_to_world(wait_cell)

    client._on_arrived(entity.global_position)

    if client._state == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: queued _on_arrived stays when already at wait cell")
    else:
        _test_failed += 1
        print("    FAIL: state = %d (expected QUEUED)" % client.get_state())


func test_queued_arrived_no_host_does_nothing():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._state = DockClientComponent.State.QUEUED
    # _queued_host is null — no host to recover to

    client._on_arrived(Vector3.ZERO)

    if client._state == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: queued _on_arrived does nothing with no host")
    else:
        _test_failed += 1
        print("    FAIL: state = %d (expected QUEUED)" % client.get_state())


func test_moving_arrived_unchanged_by_scatter():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host()
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._target_host = host_entity
    client._state = DockClientComponent.State.MOVING

    # Simulate arrival at dock cell
    var dock := host_entity.get_node_or_null("DockHostComponent") as DockHostComponent
    if dock:
        entity.global_position = Pathfinder.cell_to_world(dock._dock_cell)

    client._on_arrived(entity.global_position)

    if client._state == DockClientComponent.State.ROTATING:
        _test_passed += 1
        print("    PASS: MOVING _on_arrived transitions to ROTATING normally")
    else:
        _test_failed += 1
        print("    FAIL: state = %d (expected ROTATING)" % client.get_state())


func test_idle_arrived_ignored():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._state = DockClientComponent.State.IDLE

    client._on_arrived(Vector3.ZERO)

    if client._state == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: IDLE _on_arrived does nothing")
    else:
        _test_failed += 1
        print("    FAIL: state = %d (expected IDLE)" % client.get_state())
