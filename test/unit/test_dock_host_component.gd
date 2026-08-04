extends Node

# DockHostComponent tests — queue limits, wait timer, has_dock_type, stale eviction

var _ts: Node = null
var _timeout_signal_emitted := false
var _timeout_signal_docker: Node = null


func _make_dock_host(wait_steps: int = 10, stale_timeout: float = 5.0) -> DockHostComponent:
    var host := DockHostComponent.new()
    host.name = "DockHostComponent"
    # Each test steps _process(0.1); map the step count to a matching seconds threshold.
    host.dock_wait_seconds = wait_steps * 0.1
    host.dock_types = ["harvest"]
    host.stale_timeout = stale_timeout
    return host


func _on_timeout_signal(docker: Node) -> void:
    _timeout_signal_emitted = true
    _timeout_signal_docker = docker


# --- Basic tests ---


func test_request_dock_immediate():
    var host := _make_dock_host()
    var docker := Node.new()
    var result := host.request_dock(docker)
    (
        TestHelper
        . assert_true(
            result and host.current_docker == docker,
            "request_dock succeeds when empty: request_dock failed when empty",
        )
    )


func test_request_dock_unlimited_queue():
    var host := _make_dock_host()
    var docker1 := Node.new()
    var docker2 := Node.new()
    var docker3 := Node.new()
    host.request_dock(docker1)  # becomes current_docker
    var r2 := host.request_dock(docker2)  # queued
    var r3 := host.request_dock(docker3)  # queued
    (
        TestHelper
        . assert_true(
            not r2 and not r3 and host.queue.size() == 2,
            (
                "request_dock queues unlimited clients: r2=%s r3=%s queue_size=%d"
                % [r2, r3, host.queue.size()]
            ),
        )
    )


func test_get_queue_size():
    var host := _make_dock_host()
    host.queue.append(Node.new())
    host.queue.append(Node.new())
    (
        TestHelper
        . assert_true(
            host.get_queue_size() == 2,
            "get_queue_size returns correct count: get_queue_size returned wrong count",
        )
    )


func test_has_dock_type():
    var host := _make_dock_host()
    (
        TestHelper
        . assert_true(
            host.has_dock_type("harvest") and not host.has_dock_type("repair"),
            "has_dock_type works correctly: has_dock_type mismatch",
        )
    )


# --- Stale client eviction ---


func test_stale_timer_resets_on_dock():
    var host := _make_dock_host(10, 0.1)
    var docker := Node.new()
    host.request_dock(docker)
    (
        TestHelper
        . assert_true(
            host._stale_timer == 0.0,
            "_stale_timer resets to 0 on dock: _stale_timer = %f (expected 0)" % host._stale_timer,
        )
    )


func test_stale_timer_increments():
    var host := _make_dock_host(10, 5.0)
    var docker := Node.new()
    host.request_dock(docker)
    host._process(1.0)
    (
        TestHelper
        . assert_true(
            host._stale_timer == 1.0,
            (
                "_stale_timer increments by delta: _stale_timer = %f (expected 1.0)"
                % host._stale_timer
            ),
        )
    )


func test_stale_eviction():
    var host := _make_dock_host(10, 0.1)
    var docker := Node.new()
    add_child(docker)
    host.request_dock(docker)
    # Simulate time passing beyond stale_timeout
    host._process(0.2)
    (
        TestHelper
        . assert_true(
            host.current_docker == null and not host.queue.has(docker),
            (
                "stale client evicted after stale_timeout: current_docker=%s, in_queue=%s"
                % [host.current_docker, host.queue.has(docker)]
            ),
        )
    )
    docker.queue_free()


func test_stale_eviction_emits_dock_timeout():
    var host := _make_dock_host(10, 0.1)
    var docker := Node.new()
    add_child(docker)
    host.request_dock(docker)
    _timeout_signal_emitted = false
    _timeout_signal_docker = null
    host.dock_timeout.connect(_on_timeout_signal)
    host._process(0.2)
    (
        TestHelper
        . assert_true(
            _timeout_signal_emitted and _timeout_signal_docker == docker,
            (
                "dock_timeout signal emitted on stale eviction: emitted=%s, docker=%s"
                % [_timeout_signal_emitted, _timeout_signal_docker]
            ),
        )
    )
    docker.queue_free()


func test_stale_eviction_promotes_next():
    var host := _make_dock_host(10, 0.1)
    var docker_a := Node.new()
    var docker_b := Node.new()
    add_child(docker_a)
    add_child(docker_b)
    host.request_dock(docker_a)
    host.request_dock(docker_b)  # queued
    # A times out — B should be promoted after vacate resolves
    host._process(0.2)
    host._process(0.0)  # resolve vacate
    (
        TestHelper
        . assert_true(
            host.current_docker == docker_b and host.queue.is_empty(),
            (
                "stale eviction promotes next queued docker: current_docker=%s, queue_empty=%s"
                % [host.current_docker, host.queue.is_empty()]
            ),
        )
    )
    docker_a.queue_free()
    docker_b.queue_free()


func test_stale_disabled_when_zero():
    var host := _make_dock_host(10, 0.0)
    var docker := Node.new()
    host.request_dock(docker)
    host._process(100.0)
    (
        TestHelper
        . assert_true(
            host.current_docker == docker,
            "no eviction when stale_timeout = 0: docker was evicted with stale_timeout = 0",
        )
    )


# --- Queue promotion ---


func test_leave_dock_promotes_next():
    var host := _make_dock_host(10, 0.0)
    var docker_a := Node.new()
    var docker_b := Node.new()
    host.request_dock(docker_a)
    host.request_dock(docker_b)
    host.leave_dock(docker_a)
    host._process(0.0)  # resolve vacate
    (
        TestHelper
        . assert_true(
            host.current_docker == docker_b and host.queue.is_empty(),
            (
                "leave_dock promotes next queued docker: current_docker=%s, queue_empty=%s"
                % [host.current_docker, host.queue.is_empty()]
            ),
        )
    )


func test_leave_dock_clears_queue_when_empty():
    var host := _make_dock_host(10, 0.0)
    var docker := Node.new()
    host.request_dock(docker)
    host.leave_dock(docker)
    (
        TestHelper
        . assert_true(
            host.current_docker == null and host.queue.is_empty(),
            (
                "leave_dock clears state when queue empty: current_docker=%s, queue_empty=%s"
                % [host.current_docker, host.queue.is_empty()]
            ),
        )
    )


func test_leave_dock_removes_from_queue():
    var host := _make_dock_host(10, 0.0)
    var docker_a := Node.new()
    var docker_b := Node.new()
    var docker_c := Node.new()
    host.request_dock(docker_a)
    host.request_dock(docker_b)
    host.request_dock(docker_c)
    host.leave_dock(docker_b)  # remove from middle of queue
    (
        TestHelper
        . assert_true(
            not host.queue.has(docker_b) and host.queue.has(docker_c),
            (
                "leave_dock removes non-current docker from queue: b_in_queue=%s, c_in_queue=%s"
                % [host.queue.has(docker_b), host.queue.has(docker_c)]
            ),
        )
    )


func test_request_dock_same_docker_returns_true():
    var host := _make_dock_host()
    var docker := Node.new()
    host.request_dock(docker)
    var result := host.request_dock(docker)
    TestHelper.assert_true(
        result, "request_dock returns true for same docker: re-dock returned false"
    )


# --- find_wait_cell excludes bib cells ---


func test_find_wait_cell_excludes_bib_cells():
    if SpatialHash.instance == null:
        TestHelper.fail("SpatialHash not available")
        return

    var host := _make_dock_host()
    var dock_entity := Node3D.new()
    dock_entity.name = "TestRefinery"
    dock_entity.add_child(host)

    # Set dock_cell to a known position
    host._dock_cell = Vector2i(5, 5)

    # Register a bib cell at (5, 6) — adjacent to dock_cell
    var bib_cells: Array[Vector2i] = [Vector2i(5, 6)]
    SpatialHash.instance.register_bib_cells(bib_cells)

    # find_wait_cell should skip the bib cell and return a non-bib cell
    var wait_cell := host.find_wait_cell(1)

    # Clean up
    SpatialHash.instance._bib_cells.erase(CellUtil.cell_key(Vector2i(5, 6)))

    (
        TestHelper
        . assert_true(
            wait_cell != Vector2i(5, 6),
            "find_wait_cell excludes bib cells: find_wait_cell returned bib cell %s" % wait_cell,
        )
    )


# --- Centered world placement ---


func test_dock_position_uses_real_foundation_origin_on_rectangular_map() -> void:
    if _ts == null:
        TestHelper.fail("TerrainSystem is not available")
        return

    var grid_cells: Vector2i = Vector2i(51, 50)
    _ts.clear()
    _ts.init_grid(grid_cells.x, grid_cells.y)

    var origin_cell: Vector2i = Vector2i(47, 49)
    var footprint: Vector2i = Vector2i(3, 2)
    var entity: Node3D = Node3D.new()
    entity.name = "TestRefinery"

    var foundation: FoundationComponent = FoundationComponent.new()
    foundation.name = "FoundationComponent"
    foundation.foundation = footprint
    entity.add_child(foundation)

    var host: DockHostComponent = _make_dock_host()
    host.dock_position = Vector3(4.0, 0.0, -2.0)
    entity.add_child(host)
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    tree.root.add_child(entity)
    entity.global_position = CellUtil.cell_origin_to_world(origin_cell, footprint, grid_cells)
    entity.rotation.y = PI * 0.5
    host._compute_dock_cell()

    var expected_world: Vector3 = (
        CellUtil.cell_to_world(origin_cell, grid_cells)
        + entity.global_transform.basis * host.dock_position
    )
    var expected_cell: Vector2i = CellUtil.world_to_cell(expected_world, grid_cells)
    (
        TestHelper
        . assert_true(
            (
                host.get_dock_world_position().is_equal_approx(expected_world)
                and host._dock_cell == expected_cell
            ),
            (
                (
                    "dock offset starts at the real foundation origin: expected dock world/cell "
                    + "%s/%s, got %s/%s"
                )
                % [
                    expected_world,
                    expected_cell,
                    host.get_dock_world_position(),
                    host._dock_cell,
                ]
            ),
        )
    )

    entity.queue_free()
    _ts.clear()
    _ts.init_grid(50, 50)


# --- Queue purge on host freed ---


func test_clear_queue_notifies_clients():
    var host := _make_dock_host()
    var dock_entity := Node3D.new()
    dock_entity.name = "TestRefinery"
    dock_entity.add_child(host)

    # Create two fake dockers with on_dock_cancelled method
    var docker_a := Node.new()
    docker_a.name = "DockerA"
    add_child(docker_a)
    var docker_b := Node.new()
    docker_b.name = "DockerB"
    add_child(docker_b)

    # Manually add to queue (bypass request_dock which needs current_docker set)
    host.queue.append(docker_a)
    host.queue.append(docker_b)

    host._clear_queue("test")

    (
        TestHelper
        . assert_true(
            host.queue.is_empty(),
            "_clear_queue empties the queue: queue size = %d (expected 0)" % host.queue.size(),
        )
    )

    docker_a.queue_free()
    docker_b.queue_free()


func test_clear_queue_skips_dead_clients():
    var host := _make_dock_host()
    var dock_entity := Node3D.new()
    dock_entity.name = "TestRefinery"
    dock_entity.add_child(host)

    # One alive, one freed
    var docker_a := Node.new()
    docker_a.name = "DockerA"
    add_child(docker_a)
    var docker_b := Node.new()
    docker_b.name = "DockerB"
    add_child(docker_b)

    host.queue.append(docker_a)
    host.queue.append(docker_b)

    # Free docker_b before purge
    docker_b.queue_free()

    host._clear_queue("test dead skip")

    (
        TestHelper
        . assert_true(
            host.queue.is_empty(),
            (
                "_clear_queue skips dead clients and empties queue: queue size = %d (expected 0)"
                % host.queue.size()
            ),
        )
    )

    docker_a.queue_free()


# --- _process promotes from queue ---


func test_process_promotes_from_queue_after_seconds():
    var host := _make_dock_host(2)
    var dock_entity := Node3D.new()
    dock_entity.name = "TestRefinery"
    dock_entity.add_child(host)

    host.current_docker = null
    var docker_a := Node.new()
    docker_a.name = "DockerA"
    add_child(docker_a)
    var docker_b := Node.new()
    docker_b.name = "DockerB"
    add_child(docker_b)

    host.queue.append(docker_a)
    host.queue.append(docker_b)

    # First tick — counter increments but hasn't reached dock_wait_seconds
    host._process(0.1)
    (
        TestHelper
        . assert_true(
            host.current_docker == null and host.queue.size() == 2,
            (
                (
                    "_process waits for dock_wait_seconds before promoting: premature promotion"
                    + " — current=%s queue=%d"
                )
                % [host.current_docker, host.queue.size()]
            ),
        )
    )

    # Second tick — counter reaches dock_wait_seconds, promotes first
    host._process(0.1)
    (
        TestHelper
        . assert_true(
            host.current_docker == docker_a and host.queue.size() == 1,
            (
                (
                    "_process promotes first queued client after seconds: current=%s"
                    + " (expected DockerA), queue=%d"
                )
                % [host.current_docker, host.queue.size()]
            ),
        )
    )

    docker_a.queue_free()
    docker_b.queue_free()


# --- Queue pop when current_docker active (the bug) ---


func test_process_does_not_pop_queue_when_current_active():
    var host := _make_dock_host(2)
    var dock_entity := Node3D.new()
    dock_entity.name = "TestRefinery"
    dock_entity.add_child(host)

    # Set up: current docker active, one client queued
    var current := Node.new()
    current.name = "CurrentDocker"
    add_child(current)
    var queued := Node.new()
    queued.name = "QueuedDocker"
    add_child(queued)

    host.current_docker = current
    host.queue.append(queued)

    # Tick past dock_wait_seconds — should NOT pop because current is active
    host._process(0.1)
    host._process(0.1)

    (
        TestHelper
        . assert_true(
            host.queue.size() == 1 and host.current_docker == current,
            (
                "_process does not pop queue when current_docker active: queue=%d current=%s"
                % [host.queue.size(), host.current_docker]
            ),
        )
    )

    current.queue_free()
    queued.queue_free()


func test_process_promotes_after_current_leaves():
    var host := _make_dock_host(1)
    var dock_entity := Node3D.new()
    dock_entity.name = "TestRefinery"
    dock_entity.add_child(host)

    var current := Node.new()
    current.name = "CurrentDocker"
    add_child(current)
    var queued := Node.new()
    queued.name = "QueuedDocker"
    add_child(queued)

    host.current_docker = current
    host.queue.append(queued)

    # Simulate current leaving
    host.current_docker = null

    # Tick — should promote queued
    host._process(0.1)

    (
        TestHelper
        . assert_true(
            host.current_docker == queued and host.queue.is_empty(),
            (
                "_process promotes after current leaves: current=%s queue=%d"
                % [host.current_docker, host.queue.size()]
            ),
        )
    )

    queued.queue_free()


func test_process_preserves_queue_order():
    var host := _make_dock_host(1)
    var dock_entity := Node3D.new()
    dock_entity.name = "TestRefinery"
    dock_entity.add_child(host)

    var a := Node.new()
    a.name = "A"
    add_child(a)
    var b := Node.new()
    b.name = "B"
    add_child(b)
    var c := Node.new()
    c.name = "C"
    add_child(c)

    host.queue.append(a)
    host.queue.append(b)
    host.queue.append(c)

    # Promote A
    host._process(0.1)
    if host.current_docker != a:
        TestHelper.fail("first promote should be A, got %s" % host.current_docker)
        a.queue_free()
        b.queue_free()
        c.queue_free()
        return

    # A leaves, promote B
    host.current_docker = null
    host._process(0.1)
    if host.current_docker != b:
        TestHelper.fail("second promote should be B, got %s" % host.current_docker)
        a.queue_free()
        b.queue_free()
        c.queue_free()
        return

    # B leaves, promote C
    host.current_docker = null
    host._process(0.1)
    (
        TestHelper
        . assert_true(
            host.current_docker == c and host.queue.is_empty(),
            (
                "_process preserves FIFO queue order: current=%s queue=%d"
                % [host.current_docker, host.queue.size()]
            ),
        )
    )

    a.queue_free()
    b.queue_free()
    c.queue_free()


func test_process_does_not_pop_when_no_current_and_empty_queue():
    var host := _make_dock_host(1)
    var dock_entity := Node3D.new()
    dock_entity.name = "TestRefinery"
    dock_entity.add_child(host)

    host.current_docker = null

    # Should return early — no queue, no crash
    host._process(0.1)

    (
        TestHelper
        . assert_true(
            host.current_docker == null and host.queue.is_empty(),
            (
                "_process handles empty queue with no current docker: current=%s queue=%d"
                % [host.current_docker, host.queue.size()]
            ),
        )
    )


func test_process_waits_full_ticks_before_promoting():
    var host := _make_dock_host(3)
    var dock_entity := Node3D.new()
    dock_entity.name = "TestRefinery"
    dock_entity.add_child(host)

    var docker := Node.new()
    docker.name = "Docker"
    add_child(docker)
    host.queue.append(docker)

    # Tick once — not enough
    host._process(0.1)
    if host.current_docker != null:
        TestHelper.fail("promoted too early")
        docker.queue_free()
        return

    # Tick twice — not enough
    host._process(0.1)
    if host.current_docker != null:
        TestHelper.fail("promoted after 2 ticks, need 3")
        docker.queue_free()
        return

    # Tick three times — now promote
    host._process(0.1)
    (
        TestHelper
        . assert_true(
            host.current_docker == docker,
            "_process waits full dock_wait_seconds before promoting: not promoted after 3 ticks",
        )
    )

    docker.queue_free()


func test_process_promotion_scales_with_delta():
    # Promotion depends on accumulated seconds, not on the number of _process calls.
    var host := _make_dock_host(2)  # dock_wait_seconds == 0.2
    var dock_entity := Node3D.new()
    dock_entity.name = "TestRefinery"
    dock_entity.add_child(host)

    # Many tiny deltas that stay below the threshold must not promote.
    var slow_docker := Node.new()
    slow_docker.name = "SlowDocker"
    add_child(slow_docker)
    host.current_docker = null
    host.queue.append(slow_docker)
    for i in range(3):
        host._process(0.05)  # 3 * 0.05 = 0.15 < 0.2
    (
        TestHelper
        . assert_true(
            host.current_docker == null,
            (
                "sub-threshold deltas do not promote (frame count irrelevant): "
                + "promoted before dock_wait_seconds elapsed"
            ),
        )
    )

    # A single delta at/above the threshold promotes on that tick.
    host._process(0.2)
    (
        TestHelper
        . assert_true(
            host.current_docker == slow_docker,
            (
                "one delta >= dock_wait_seconds promotes (scales with game speed): "
                + "not promoted after delta reached dock_wait_seconds"
            ),
        )
    )

    slow_docker.queue_free()
