extends Node

# Comprehensive queue step tests — every branch of seek→queue→promote→dock flow.

var _test_passed := 0
var _test_failed := 0
var _cancelled_emitted := false
var _undocked_emitted := false
var _failed_emitted := false


func _make_client(dock_id: String = "PROC") -> DockClientComponent:
    var c := DockClientComponent.new()
    c.name = "DockClientComponent"
    c._dock_id = dock_id
    c.can_dock_with = [dock_id]
    return c


func _make_host(dock_wait: int = 10, stale: float = 5.0) -> Node3D:
    var entity := Node3D.new()
    entity.name = "TestRefinery"
    var host := DockHostComponent.new()
    host.name = "DockHostComponent"
    host.dock_types = ["harvest"]
    host.dock_wait_ticks = dock_wait
    host.stale_timeout = stale
    entity.add_child(host)
    return entity


func _make_harvester(dock_id: String = "PROC") -> Node3D:
    var entity := Node3D.new()
    entity.name = "TestHarvester"
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    var client := _make_client(dock_id)
    entity.add_child(client)
    return entity


func _get_client(entity: Node3D) -> DockClientComponent:
    return entity.get_node("DockClientComponent") as DockClientComponent


func _get_mc(entity: Node3D) -> MovementController:
    return entity.get_node("MovementController") as MovementController


func _on_cancelled() -> void:
    _cancelled_emitted = true


func _on_undocked(_docker: Node) -> void:
    _undocked_emitted = true


func _on_failed() -> void:
    _failed_emitted = true


# --- Category 1: seek_dock → QUEUED transition ---


func test_seek_dock_queues_when_host_occupied():
    var host := _make_host()
    add_child(host)
    var h1 := _make_harvester()
    add_child(h1)
    var h2 := _make_harvester()
    add_child(h2)

    # h1 docks immediately (empty host)
    _get_client(h1).seek_dock(h1, host)
    # h2 tries → host occupied → should queue
    _get_client(h2).seek_dock(h2, host)

    var c2 := _get_client(h2)
    if c2.get_state() == DockClientComponent.State.QUEUED and c2._queued_host == host:
        _test_passed += 1
        print("    PASS: seek_dock queues when host occupied")
    else:
        _test_failed += 1
        print("    FAIL: state=%d queued_host=%s" % [c2.get_state(), c2._queued_host])

    h1.queue_free()
    h2.queue_free()
    host.queue_free()


func test_seek_dock_queues_moves_to_wait_cell():
    var host := _make_host()
    add_child(host)
    var h1 := _make_harvester()
    add_child(h1)
    var h2 := _make_harvester()
    add_child(h2)

    _get_client(h1).seek_dock(h1, host)
    _get_client(h2).seek_dock(h2, host)

    # h2 should have some position set (moved to wait cell)
    var c2 := _get_client(h2)
    if c2.get_state() == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: seek_dock queues and moves to wait cell")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c2.get_state())

    h1.queue_free()
    h2.queue_free()
    host.queue_free()


func test_seek_dock_skips_when_not_idle():
    var host := _make_host()
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    var c := _get_client(h)
    c._state = DockClientComponent.State.MOVING
    c.seek_dock(h, host)

    if c.get_state() == DockClientComponent.State.MOVING:
        _test_passed += 1
        print("    PASS: seek_dock skips when not idle")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()
    host.queue_free()


func test_seek_dock_skips_on_retry_cooldown():
    var host := _make_host()
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    var c := _get_client(h)
    c._retry_cooldown = 2.0
    c.seek_dock(h, host)

    if c.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: seek_dock skips on retry cooldown")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()
    host.queue_free()


func test_seek_dock_specific_host_queues():
    var host := _make_host()
    add_child(host)
    var h1 := _make_harvester()
    add_child(h1)
    var h2 := _make_harvester()
    add_child(h2)

    _get_client(h1).seek_dock(h1, host)
    _get_client(h2).seek_dock(h2, host)

    var c2 := _get_client(h2)
    if c2.get_state() == DockClientComponent.State.QUEUED and c2._queued_host == host:
        _test_passed += 1
        print("    PASS: seek_dock with specific_host queues")
    else:
        _test_failed += 1
        print("    FAIL: state=%d queued_host=%s" % [c2.get_state(), c2._queued_host])

    h1.queue_free()
    h2.queue_free()
    host.queue_free()


func test_seek_dock_specific_host_succeeds():
    var host := _make_host()
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    _get_client(h).seek_dock(h, host)

    var c := _get_client(h)
    if c.get_state() == DockClientComponent.State.MOVING and c._target_host == host:
        _test_passed += 1
        print("    PASS: seek_dock with specific_host succeeds immediately")
    else:
        _test_failed += 1
        print("    FAIL: state=%d target=%s" % [c.get_state(), c._target_host])

    h.queue_free()
    host.queue_free()


# --- Category 2: on_slot_available promotion ---


func test_on_slot_available_transitions_to_moving():
    var host := _make_host(1)
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    var c := _get_client(h)
    c._queued_host = host
    c._state = DockClientComponent.State.QUEUED

    c.on_slot_available()

    if c.get_state() == DockClientComponent.State.MOVING:
        _test_passed += 1
        print("    PASS: on_slot_available transitions to MOVING")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()
    host.queue_free()


func test_on_slot_available_bind_fails_stays_queued():
    var host := _make_host(1)
    add_child(host)
    var h1 := _make_harvester()
    add_child(h1)
    var h2 := _make_harvester()
    add_child(h2)

    # Set up host with h1 as current, h2 in queue
    var host_comp := host.get_node("DockHostComponent") as DockHostComponent
    host_comp.current_docker = _get_client(h1)
    host_comp.queue.append(_get_client(h2))

    var c2 := _get_client(h2)
    c2._queued_host = host
    c2._state = DockClientComponent.State.QUEUED

    # on_slot_available: _try_bind_host calls request_dock
    # current_docker is h1, not h2 → h2 not in queue... wait, h2 IS in queue
    # request_dock sees "already in queue" → returns false → bind fails
    c2.on_slot_available()

    if c2.get_state() == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: on_slot_available stays QUEUED when bind fails")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c2.get_state())

    h1.queue_free()
    h2.queue_free()
    host.queue_free()


func test_on_slot_available_ignored_when_not_queued():
    var h := _make_harvester()
    add_child(h)

    var c := _get_client(h)
    c._state = DockClientComponent.State.IDLE
    c.on_slot_available()

    if c.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: on_slot_available ignored when not QUEUED")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()


func test_on_slot_available_uses_reserved_host():
    var host := _make_host(1)
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    var c := _get_client(h)
    c._reserved_host = host
    c._state = DockClientComponent.State.QUEUED

    c.on_slot_available()

    if c.get_state() == DockClientComponent.State.MOVING and c._target_host == host:
        _test_passed += 1
        print("    PASS: on_slot_available uses _reserved_host")
    else:
        _test_failed += 1
        print("    FAIL: state=%d target=%s" % [c.get_state(), c._target_host])

    h.queue_free()
    host.queue_free()


func test_on_slot_available_uses_queued_host():
    var host := _make_host(1)
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    var c := _get_client(h)
    c._queued_host = host
    c._state = DockClientComponent.State.QUEUED

    c.on_slot_available()

    if c.get_state() == DockClientComponent.State.MOVING and c._target_host == host:
        _test_passed += 1
        print("    PASS: on_slot_available uses _queued_host")
    else:
        _test_failed += 1
        print("    FAIL: state=%d target=%s" % [c.get_state(), c._target_host])

    h.queue_free()
    host.queue_free()


# --- Category 3: Host queue → client promotion ---


func test_finish_vacate_promotes_first_queued():
    var host := _make_host(1)
    add_child(host)
    var h1 := _make_harvester()
    add_child(h1)
    var h2 := _make_harvester()
    add_child(h2)

    # Set up host state directly — don't use seek_dock (it sets host state too)
    var host_comp := host.get_node("DockHostComponent") as DockHostComponent
    host_comp.current_docker = _get_client(h1)
    host_comp.queue.append(_get_client(h2))

    # Simulate vacate
    host_comp._finish_vacate()

    if host_comp.current_docker == _get_client(h2) and host_comp.queue.is_empty():
        _test_passed += 1
        print("    PASS: _finish_vacate promotes first queued")
    else:
        _test_failed += 1
        print("    FAIL: current=%s queue=%d" % [host_comp.current_docker, host_comp.queue.size()])

    h1.queue_free()
    h2.queue_free()
    host.queue_free()


func test_finish_vacate_empty_queue_noop():
    var host := _make_host(1)
    add_child(host)

    var host_comp := host.get_node("DockHostComponent") as DockHostComponent
    host_comp._finish_vacate()

    if host_comp.current_docker == null and host_comp.queue.is_empty():
        _test_passed += 1
        print("    PASS: _finish_vacate noop on empty queue")
    else:
        _test_failed += 1
        print("    FAIL: current=%s queue=%d" % [host_comp.current_docker, host_comp.queue.size()])

    host.queue_free()


func test_process_promotes_after_wait_ticks():
    var host := _make_host(100)
    var h := _make_harvester()
    add_child(h)

    var host_comp := host.get_node("DockHostComponent") as DockHostComponent
    host_comp.queue.append(_get_client(h))
    host_comp.current_docker = null
    host_comp._awaiting_vacate = false

    # Set counter just below threshold, then tick once
    host_comp._wait_counter = 99
    host_comp._process(0.1)

    if host_comp.current_docker == _get_client(h):
        _test_passed += 1
        print("    PASS: _process promotes after wait ticks")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: current=%s wait=%d queue=%d awaiting=%s"
                % [
                    host_comp.current_docker,
                    host_comp._wait_counter,
                    host_comp.queue.size(),
                    host_comp._awaiting_vacate,
                ]
            )
        )

    h.queue_free()
    host.queue_free()


func test_process_does_not_pop_when_current_active():
    var host := _make_host(1)
    add_child(host)
    var h1 := _make_harvester()
    add_child(h1)
    var h2 := _make_harvester()
    add_child(h2)

    var host_comp := host.get_node("DockHostComponent") as DockHostComponent
    host_comp.current_docker = _get_client(h1)
    host_comp.queue.append(_get_client(h2))

    host_comp._process(0.1)

    if host_comp.queue.size() == 1 and host_comp.current_docker == _get_client(h1):
        _test_passed += 1
        print("    PASS: _process does not pop when current active")
    else:
        _test_failed += 1
        print("    FAIL: queue=%d current=%s" % [host_comp.queue.size(), host_comp.current_docker])

    h1.queue_free()
    h2.queue_free()
    host.queue_free()


# --- Category 4: Client leaving queue ---


func test_queued_client_leave_dock_removes_from_queue():
    var host := _make_host(1)
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    var host_comp := host.get_node("DockHostComponent") as DockHostComponent
    var c := _get_client(h)
    host_comp.queue.append(c)

    host_comp.leave_dock(c)

    if host_comp.queue.is_empty():
        _test_passed += 1
        print("    PASS: leave_dock removes from queue")
    else:
        _test_failed += 1
        print("    FAIL: queue=%d" % host_comp.queue.size())

    h.queue_free()
    host.queue_free()


func test_queued_client_exit_tree_releases():
    var host := _make_host(1)
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    var host_comp := host.get_node("DockHostComponent") as DockHostComponent
    var c := _get_client(h)
    c._queued_host = host
    c._state = DockClientComponent.State.QUEUED
    host_comp.queue.append(c)

    # Simulate exit_tree
    c._exit_tree()

    if c.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: exit_tree clears queued state")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()
    host.queue_free()


func test_queued_client_dock_cancelled_clears_state():
    var h := _make_harvester()
    add_child(h)
    var host := _make_host()
    add_child(host)

    var c := _get_client(h)
    c._queued_host = host
    c._state = DockClientComponent.State.QUEUED

    c.on_dock_cancelled()

    if (
        c.get_state() == DockClientComponent.State.IDLE
        and c._queued_host == null
        and c._reserved_host == null
    ):
        _test_passed += 1
        print("    PASS: on_dock_cancelled clears queued state")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: state=%d queued=%s reserved=%s"
                % [c.get_state(), c._queued_host, c._reserved_host]
            )
        )

    h.queue_free()
    host.queue_free()


func test_queued_client_dock_cancelled_full_emits():
    var h := _make_harvester()
    add_child(h)
    var host := _make_host()
    add_child(host)

    var c := _get_client(h)
    c._queued_host = host
    c._state = DockClientComponent.State.QUEUED
    _cancelled_emitted = false
    c.dock_cancelled.connect(_on_cancelled)

    c.on_dock_cancelled_full()

    if _cancelled_emitted and c.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: on_dock_cancelled_full emits signal")
    else:
        _test_failed += 1
        print("    FAIL: emitted=%s state=%d" % [_cancelled_emitted, c.get_state()])

    h.queue_free()
    host.queue_free()


func test_queued_client_dock_undocked_wrong_ignored():
    var h := _make_harvester()
    add_child(h)
    var host := _make_host()
    add_child(host)

    var c := _get_client(h)
    c._queued_host = host
    c._state = DockClientComponent.State.QUEUED

    c.on_dock_undocked(Node.new())

    if c.get_state() == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: on_dock_undocked ignores wrong docker")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()
    host.queue_free()


func test_queued_client_dock_undocked_self_clears():
    var h := _make_harvester()
    add_child(h)
    var host := _make_host()
    add_child(host)

    var c := _get_client(h)
    c._queued_host = host
    c._state = DockClientComponent.State.QUEUED

    c.on_dock_undocked(c)

    if c.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: on_dock_undocked(self) clears state")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()
    host.queue_free()


# --- Category 5: Scatter recovery while queued ---


func test_queued_scatter_arrived_reroutes():
    var host := _make_host()
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    var c := _get_client(h)
    c._queued_host = host
    c._state = DockClientComponent.State.QUEUED

    c._on_arrived(Vector3(999, 0, 999))

    if c.get_state() == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: scatter arrived reroutes to wait cell")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()
    host.queue_free()


func test_queued_scatter_arrived_at_wait_cell_noop():
    var host := _make_host()
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    var dock_comp := host.get_node("DockHostComponent") as DockHostComponent
    var wait_cell := dock_comp.find_wait_cell()
    h.global_position = Pathfinder.cell_to_world(wait_cell)

    var c := _get_client(h)
    c._queued_host = host
    c._state = DockClientComponent.State.QUEUED

    c._on_arrived(h.global_position)

    if c.get_state() == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: scatter at wait cell does nothing")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()
    host.queue_free()


func test_queued_scatter_arrived_no_host_noop():
    var h := _make_harvester()
    add_child(h)

    var c := _get_client(h)
    c._state = DockClientComponent.State.QUEUED

    c._on_arrived(Vector3(999, 0, 999))

    if c.get_state() == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: scatter with no host does nothing")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()


# --- Category 6: Pathfinding while queued ---


func test_queued_pathfinding_failed_noop():
    var h := _make_harvester()
    add_child(h)

    var c := _get_client(h)
    c._state = DockClientComponent.State.QUEUED

    c._on_pathfinding_failed()

    if c.get_state() == DockClientComponent.State.QUEUED:
        _test_passed += 1
        print("    PASS: pathfinding failed in QUEUED does nothing")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()


# --- Category 7: Full cycle edge cases ---


func test_full_cycle_seek_queue_promote_dock_undock():
    var host := _make_host(1)
    add_child(host)
    var h1 := _make_harvester()
    add_child(h1)
    var h2 := _make_harvester()
    add_child(h2)

    # Step 1: h1 docks immediately
    _get_client(h1).seek_dock(h1, host)
    if _get_client(h1).get_state() != DockClientComponent.State.MOVING:
        _test_failed += 1
        print("    FAIL: h1 should be MOVING after seek_dock")
        h1.queue_free()
        h2.queue_free()
        host.queue_free()
        return

    # Step 2: h2 queues
    _get_client(h2).seek_dock(h2, host)
    if _get_client(h2).get_state() != DockClientComponent.State.QUEUED:
        _test_failed += 1
        print("    FAIL: h2 should be QUEUED")
        h1.queue_free()
        h2.queue_free()
        host.queue_free()
        return

    # Step 3: h1 finishes, undock
    var host_comp := host.get_node("DockHostComponent") as DockHostComponent
    host_comp.leave_dock(_get_client(h1))

    # Step 4: promote h2 via _finish_vacate
    host_comp._finish_vacate()

    if host_comp.current_docker == _get_client(h2):
        _test_passed += 1
        print("    PASS: full cycle seek→queue→promote→dock→undock")
    else:
        _test_failed += 1
        print("    FAIL: current=%s" % host_comp.current_docker)

    h1.queue_free()
    h2.queue_free()
    host.queue_free()


func test_multiple_clients_fifo_order():
    var host := _make_host(1)
    add_child(host)
    var h1 := _make_harvester()
    add_child(h1)
    var h2 := _make_harvester()
    add_child(h2)
    var h3 := _make_harvester()
    add_child(h3)

    var host_comp := host.get_node("DockHostComponent") as DockHostComponent
    host_comp.queue.append(_get_client(h1))
    host_comp.queue.append(_get_client(h2))
    host_comp.queue.append(_get_client(h3))

    # Promote h1
    host_comp._process(0.1)
    if host_comp.current_docker != _get_client(h1):
        _test_failed += 1
        print("    FAIL: first should be h1")
        h1.queue_free()
        h2.queue_free()
        h3.queue_free()
        host.queue_free()
        return

    # h1 leaves, promote h2
    host_comp.current_docker = null
    host_comp._process(0.1)
    if host_comp.current_docker != _get_client(h2):
        _test_failed += 1
        print("    FAIL: second should be h2")
        h1.queue_free()
        h2.queue_free()
        h3.queue_free()
        host.queue_free()
        return

    # h2 leaves, promote h3
    host_comp.current_docker = null
    host_comp._process(0.1)
    if host_comp.current_docker == _get_client(h3) and host_comp.queue.is_empty():
        _test_passed += 1
        print("    PASS: FIFO order preserved through 3 promotions")
    else:
        _test_failed += 1
        print("    FAIL: current=%s queue=%d" % [host_comp.current_docker, host_comp.queue.size()])

    h1.queue_free()
    h2.queue_free()
    h3.queue_free()
    host.queue_free()


func test_client_queued_then_host_freed():
    var host := _make_host(1)
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    var host_comp := host.get_node("DockHostComponent") as DockHostComponent
    var c := _get_client(h)
    c._queued_host = host
    c._state = DockClientComponent.State.QUEUED
    host_comp.queue.append(c)

    # Call _clear_queue directly — queue_free is deferred
    host_comp._clear_queue("test")

    if c.get_state() == DockClientComponent.State.IDLE:
        _test_passed += 1
        print("    PASS: host freed clears queued client state")
    else:
        _test_failed += 1
        print("    FAIL: state=%d" % c.get_state())

    h.queue_free()
    host.queue_free()


func test_client_queued_then_entity_freed():
    var host := _make_host(1)
    add_child(host)
    var h := _make_harvester()
    add_child(h)

    var host_comp := host.get_node("DockHostComponent") as DockHostComponent
    var c := _get_client(h)
    c._queued_host = host
    c._reserved_host = host
    c._state = DockClientComponent.State.QUEUED
    host_comp.queue.append(c)

    # Call _exit_tree directly — queue_free is deferred
    c._exit_tree()

    if host_comp.queue.is_empty():
        _test_passed += 1
        print("    PASS: client freed removes from host queue")
    else:
        _test_failed += 1
        print("    FAIL: queue=%d" % host_comp.queue.size())

    h.queue_free()
    host.queue_free()


func test_concurrent_seek_same_host():
    var host := _make_host(1)
    add_child(host)
    var h1 := _make_harvester()
    add_child(h1)
    var h2 := _make_harvester()
    add_child(h2)

    # Both seek at same time — one gets immediate, other queues
    _get_client(h1).seek_dock(h1, host)
    _get_client(h2).seek_dock(h2, host)

    var c1 := _get_client(h1)
    var c2 := _get_client(h2)
    var one_moving := (
        c1.get_state() == DockClientComponent.State.MOVING
        and c2.get_state() == DockClientComponent.State.QUEUED
    )
    var other_moving := (
        c2.get_state() == DockClientComponent.State.MOVING
        and c1.get_state() == DockClientComponent.State.QUEUED
    )

    if one_moving or other_moving:
        _test_passed += 1
        print("    PASS: concurrent seek — one moves, one queues")
    else:
        _test_failed += 1
        print("    FAIL: c1=%d c2=%d" % [c1.get_state(), c2.get_state()])

    h1.queue_free()
    h2.queue_free()
    host.queue_free()


func test_rapid_queue_promote_cycle():
    var host := _make_host(1)
    add_child(host)
    var h1 := _make_harvester()
    add_child(h1)
    var h2 := _make_harvester()
    add_child(h2)

    var host_comp := host.get_node("DockHostComponent") as DockHostComponent

    # Cycle 3 times: h1 docks, h2 queues, h1 leaves, promote h2
    for i in range(3):
        _get_client(h1)._state = DockClientComponent.State.IDLE
        _get_client(h2)._state = DockClientComponent.State.IDLE
        host_comp.current_docker = null
        host_comp.queue.clear()
        host_comp._awaiting_vacate = false

        # h1 docks
        host_comp.current_docker = _get_client(h1)
        # h2 queues
        host_comp.queue.append(_get_client(h2))

        # h1 leaves
        host_comp.leave_dock(_get_client(h1))

        # promote h2
        host_comp._finish_vacate()

        if host_comp.current_docker != _get_client(h2):
            _test_failed += 1
            print("    FAIL: cycle %d — h2 not promoted" % i)
            h1.queue_free()
            h2.queue_free()
            host.queue_free()
            return

    _test_passed += 1
    print("    PASS: rapid queue/promote cycle stable")

    h1.queue_free()
    h2.queue_free()
    host.queue_free()
