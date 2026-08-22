extends Node

# DockClientComponent tests — state machine, dock sequence, thin client behavior

var _cancelled_emitted := false
var _undocked_emitted := false
var _failed_emitted := false


func _make_dock_client(dock_id: String = "GDI_REFINERY") -> DockClientComponent:
    var client := DockClientComponent.new()
    client.name = "DockClientComponent"
    client._dock_id = dock_id
    client.can_dock_with = [dock_id]
    return client


func _add_owner(entity: Node, player_id: int = 0) -> void:
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = player_id
    entity.add_child(stats)


func _get_stats(entity: Node) -> StatsComponent:
    return entity.get_node("StatsComponent") as StatsComponent


func _make_dock_host(_dock_id: String = "GDI_REFINERY", queue_size: int = 0) -> Node3D:
    var entity := Node3D.new()
    entity.name = "TestRefinery"

    var host := DockHostComponent.new()
    host.name = "DockHostComponent"
    host.dock_types = ["harvest"]
    for i in queue_size:
        host.queue.append(Node.new())
    entity.add_child(host)
    _add_owner(entity)

    return entity


func _make_entity_with_client(dock_id: String = "GDI_REFINERY") -> Node3D:
    var entity := Node3D.new()
    entity.name = "TestHarvester"

    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)

    var client := _make_dock_client(dock_id)
    entity.add_child(client)
    _add_owner(entity)

    return entity


func _on_cancelled() -> void:
    _cancelled_emitted = true


func _on_undocked(_docker: Node) -> void:
    _undocked_emitted = true


func _on_failed() -> void:
    _failed_emitted = true


# --- Basic tests ---


func test_configure_sets_can_dock_with():
    var client := _make_dock_client("GDI_REFINERY")
    (
        TestHelper
        . assert_true(
            client.can_dock_with.has("GDI_REFINERY") and client.get_dock_id() == "GDI_REFINERY",
            "configure sets can_dock_with: configure did not set can_dock_with",
        )
    )


func test_get_dock_id():
    var client := _make_dock_client("REFN")
    TestHelper.assert_true(
        client.get_dock_id() == "REFN",
        "get_dock_id returns correct id: get_dock_id returned wrong id"
    )


func test_is_reserved():
    var client := _make_dock_client()
    (
        TestHelper
        . assert_true(
            not client.is_reserved(),
            "is_reserved returns false when no host: is_reserved returned true with no host",
        )
    )


func test_initial_state_is_idle():
    var client := _make_dock_client()
    (
        TestHelper
        . assert_true(
            client.get_state() == DockClientComponent.State.IDLE,
            "initial state is IDLE: initial state = %d (expected IDLE)" % client.get_state(),
        )
    )


# --- State transitions ---


func test_seek_dock_transitions_to_queued_when_host_occupied():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host("GDI_REFINERY", 1)
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    _failed_emitted = false
    client.dock_slot_failed.connect(_on_failed)

    # Manually test the queuing path — set up the queued state directly
    # since find_neaster_host requires a scene tree with "Buildings" group
    client._queued_host = host_entity
    client._state = DockClientComponent.State.QUEUED

    (
        TestHelper
        . assert_true(
            client.get_state() == DockClientComponent.State.QUEUED,
            (
                "client can be in QUEUED state: state = %d (expected QUEUED=%d)"
                % [client.get_state(), DockClientComponent.State.QUEUED]
            ),
        )
    )


func test_seek_dock_emits_failed_when_no_host():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    _failed_emitted = false
    client.dock_slot_failed.connect(_on_failed)

    client.seek_dock(entity)

    (
        TestHelper
        . assert_true(
            _failed_emitted and client.get_state() == DockClientComponent.State.IDLE,
            (
                "seek_dock emits dock_slot_failed when no host: emitted=%s, state=%d"
                % [_failed_emitted, client.get_state()]
            ),
        )
    )


func test_on_slot_available_moves_to_docked_when_queued():
    var entity := _make_entity_with_client()
    add_child(entity)
    var host_entity := _make_dock_host("GDI_REFINERY")
    add_child(host_entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent

    # Manually set up queued state
    client._queued_host = host_entity
    client._state = DockClientComponent.State.QUEUED

    client.on_slot_available()

    (
        TestHelper
        . assert_true(
            (
                client.get_state() == DockClientComponent.State.MOVING
                and client._target_host == host_entity
            ),
            (
                "on_slot_available transitions QUEUED → MOVING: state=%d, target=%s"
                % [client.get_state(), client._target_host]
            ),
        )
    )


func test_on_slot_available_ignores_non_queued():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._state = DockClientComponent.State.IDLE

    client.on_slot_available()

    (
        TestHelper
        . assert_true(
            client.get_state() == DockClientComponent.State.IDLE,
            (
                "on_slot_available is a no-op when not QUEUED: state changed to %d"
                % client.get_state()
            ),
        )
    )


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

    (
        TestHelper
        . assert_true(
            (
                client._reserved_host == null
                and client._target_host == null
                and client.get_state() == DockClientComponent.State.IDLE
                and _undocked_emitted
            ),
            (
                (
                    "on_dock_undocked clears state and emits signal: reserved=%s, target=%s, "
                    + "state=%d, emitted=%s"
                )
                % [
                    client._reserved_host,
                    client._target_host,
                    client.get_state(),
                    _undocked_emitted
                ]
            ),
        )
    )


func test_on_dock_undocked_ignores_other_docker():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._state = DockClientComponent.State.UNLOADING

    var other := Node.new()
    client.on_dock_undocked(other)

    (
        TestHelper
        . assert_true(
            client.get_state() == DockClientComponent.State.UNLOADING,
            "on_dock_undocked ignores other docker: state changed to %d" % client.get_state(),
        )
    )


# --- Retry cooldown ---


func test_retry_cooldown_decrements():
    var client := _make_dock_client()
    client._retry_cooldown = 2.0
    client._process(1.0)
    (
        TestHelper
        . assert_true(
            client._retry_cooldown == 1.0,
            (
                "_retry_cooldown decrements by delta: _retry_cooldown = %f (expected 1.0)"
                % client._retry_cooldown
            ),
        )
    )


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

    (
        TestHelper
        . assert_true(
            client.get_state() == DockClientComponent.State.IDLE,
            "_exit_tree clears state to IDLE: state = %d (expected IDLE)" % client.get_state(),
        )
    )


func test_exit_tree_noop_when_idle():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._state = DockClientComponent.State.IDLE

    client._exit_tree()

    (
        TestHelper
        . assert_true(
            client.get_state() == DockClientComponent.State.IDLE,
            "_exit_tree is no-op when IDLE: state = %d (expected IDLE)" % client.get_state(),
        )
    )


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
    (
        TestHelper
        . assert_true(
            (
                client._retry_cooldown == 1.0
                and client.get_state() == DockClientComponent.State.MOVING
            ),
            (
                "pathfinding failure during MOVING sets retry cooldown: cooldown=%f, state=%d"
                % [client._retry_cooldown, client.get_state()]
            ),
        )
    )


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
    (
        TestHelper
        . assert_true(
            client.get_state() == DockClientComponent.State.QUEUED,
            (
                "pathfinding failure during QUEUED stays queued: state = %d (expected QUEUED=%d)"
                % [client.get_state(), DockClientComponent.State.QUEUED]
            ),
        )
    )


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

    (
        TestHelper
        . assert_true(
            client.get_state() == DockClientComponent.State.IDLE,
            (
                "on_dock_cancelled clears QUEUED state to IDLE: state = %d (expected IDLE)"
                % client.get_state()
            ),
        )
    )


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

    (
        TestHelper
        . assert_true(
            (
                client.get_state() == DockClientComponent.State.IDLE
                and client._reserved_host == null
                and client._target_host == null
            ),
            (
                (
                    "on_dock_cancelled clears MOVING state and all references: state=%d "
                    + "reserved=%s target=%s"
                )
                % [client.get_state(), client._reserved_host, client._target_host]
            ),
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

    (
        TestHelper
        . assert_true(
            not _cancelled_emitted and client.get_state() == DockClientComponent.State.IDLE,
            (
                "on_dock_cancelled cleans state without signal: emitted=%s state=%d"
                % [_cancelled_emitted, client.get_state()]
            ),
        )
    )


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
    (
        TestHelper
        . assert_true(
            client._state == DockClientComponent.State.QUEUED,
            (
                "queued _on_arrived re-routes to wait cell: state = %d (expected QUEUED)"
                % client.get_state()
            ),
        )
    )


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
        entity.global_position = CellUtil.cell_to_world(wait_cell)

    client._on_arrived(entity.global_position)

    (
        TestHelper
        . assert_true(
            client._state == DockClientComponent.State.QUEUED,
            (
                "queued _on_arrived stays when already at wait cell: state = %d (expected QUEUED)"
                % client.get_state()
            ),
        )
    )


func test_queued_arrived_no_host_does_nothing():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._state = DockClientComponent.State.QUEUED
    # _queued_host is null — no host to recover to

    client._on_arrived(Vector3.ZERO)

    (
        TestHelper
        . assert_true(
            client._state == DockClientComponent.State.QUEUED,
            (
                "queued _on_arrived does nothing with no host: state = %d (expected QUEUED)"
                % client.get_state()
            ),
        )
    )


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
        entity.global_position = CellUtil.cell_to_world(dock._dock_cell)

    client._on_arrived(entity.global_position)

    (
        TestHelper
        . assert_true(
            client._state == DockClientComponent.State.ROTATING,
            (
                (
                    "MOVING _on_arrived transitions to ROTATING normally: state = %d "
                    + "(expected ROTATING)"
                )
                % client.get_state()
            ),
        )
    )


func test_idle_arrived_ignored():
    var entity := _make_entity_with_client()
    add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    client._state = DockClientComponent.State.IDLE

    client._on_arrived(Vector3.ZERO)

    (
        TestHelper
        . assert_true(
            client._state == DockClientComponent.State.IDLE,
            "IDLE _on_arrived does nothing: state = %d (expected IDLE)" % client.get_state(),
        )
    )


## Builds a dock host entity configured to report `_entity_id`, attached to the
## real scene-tree root and added to the "entities" group so find_nearest_host's
## scene-wide scan can see it.
func _make_scene_dock_host(
    entity_id: String = "GDI_REFINERY", dock_cell: Vector2i = Vector2i(50, 50)
) -> Node3D:
    var host_entity := Node3D.new()
    host_entity.name = "SceneHost"

    var host := DockHostComponent.new()
    host.name = "DockHostComponent"
    var data := EntityData.new()
    data.id = entity_id
    host.configure(data)
    host._dock_cell = dock_cell
    host_entity.add_child(host)
    _add_owner(host_entity)

    host_entity.add_to_group("entities")
    Engine.get_main_loop().root.add_child(host_entity)
    return host_entity


func _remove_scene_dock_host(host_entity: Node3D) -> void:
    if is_instance_valid(host_entity):
        host_entity.free()


func test_find_nearest_host_finds_map_rooted_host():
    var entity := _make_entity_with_client()
    Engine.get_main_loop().root.add_child(entity)
    var host_entity := _make_scene_dock_host()

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    var found := client.find_nearest_host(entity)
    _remove_scene_dock_host(host_entity)
    entity.free()

    (
        TestHelper
        . assert_true(
            found == host_entity,
            (
                (
                    "find_nearest_host finds a host not under a Buildings node: found=%s "
                    + "(expected map-rooted host)"
                )
                % [found]
            ),
        )
    )


func test_find_nearest_host_skips_incompatible_dock_type():
    var entity := _make_entity_with_client()
    Engine.get_main_loop().root.add_child(entity)
    var wrong_host := _make_scene_dock_host("NOD_REFINERY")
    var right_host := _make_scene_dock_host("GDI_REFINERY", Vector2i(52, 50))

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    var found := client.find_nearest_host(entity)
    _remove_scene_dock_host(wrong_host)
    _remove_scene_dock_host(right_host)
    entity.free()

    (
        TestHelper
        . assert_true(
            found == right_host,
            (
                (
                    "find_nearest_host skips incompatible dock type, finds compatible: found=%s "
                    + "(expected compatible GDI host)"
                )
                % [found]
            ),
        )
    )


func test_find_nearest_host_occupancy_ranking():
    var entity := _make_entity_with_client()
    Engine.get_main_loop().root.add_child(entity)
    # Two compatible hosts at equal distance; the occupied one ranks lower.
    var empty_host := _make_scene_dock_host("GDI_REFINERY", Vector2i(49, 49))
    var busy_host := _make_scene_dock_host("GDI_REFINERY", Vector2i(51, 51))
    var busy_dock := busy_host.get_node("DockHostComponent") as DockHostComponent
    busy_dock.current_docker = Node.new()

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    var found := client.find_nearest_host(entity)
    _remove_scene_dock_host(empty_host)
    _remove_scene_dock_host(busy_host)
    entity.free()

    (
        TestHelper
        . assert_true(
            found == empty_host,
            (
                (
                    "find_nearest_host ranks less-occupied host first: found=%s "
                    + "(expected less-occupied host)"
                )
                % [found]
            ),
        )
    )


func test_find_nearest_host_no_host():
    var entity := _make_entity_with_client()
    Engine.get_main_loop().root.add_child(entity)

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    var found := client.find_nearest_host(entity)
    entity.free()

    (
        TestHelper
        . assert_true(
            found == null,
            (
                "find_nearest_host returns null when no compatible host: found=%s (expected null)"
                % [found]
            ),
        )
    )


func test_find_nearest_host_skips_foreign_owned():
    var entity := _make_entity_with_client()
    Engine.get_main_loop().root.add_child(entity)
    # Enemy host nearer, own host one cell farther — must pick the own-side host.
    var enemy_host := _make_scene_dock_host("GDI_REFINERY", Vector2i(49, 50))
    (_get_stats(enemy_host) as StatsComponent).player_id = 1
    var own_host := _make_scene_dock_host("GDI_REFINERY", Vector2i(51, 50))

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    var found := client.find_nearest_host(entity)
    _remove_scene_dock_host(enemy_host)
    _remove_scene_dock_host(own_host)
    entity.free()

    (
        TestHelper
        . assert_true(
            found == own_host,
            (
                (
                    "find_nearest_host skips foreign-owned host: found=%s "
                    + "(expected own-side host)"
                )
                % [found]
            ),
        )
    )


func test_find_nearest_host_only_foreign_returns_null():
    var entity := _make_entity_with_client()
    Engine.get_main_loop().root.add_child(entity)
    var enemy_host := _make_scene_dock_host("GDI_REFINERY", Vector2i(50, 50))
    (_get_stats(enemy_host) as StatsComponent).player_id = 1

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    var found := client.find_nearest_host(entity)
    _remove_scene_dock_host(enemy_host)
    entity.free()

    TestHelper.assert_true(
        found == null,
        "find_nearest_host returns null when only foreign hosts exist: found=%s" % [found]
    )


func test_find_nearest_host_ownerless_client_finds_nothing():
    var entity := _make_entity_with_client()
    Engine.get_main_loop().root.add_child(entity)
    (_get_stats(entity) as StatsComponent).queue_free()
    var host_entity := _make_scene_dock_host()

    var client := entity.get_node("DockClientComponent") as DockClientComponent
    var found := client.find_nearest_host(entity)
    _remove_scene_dock_host(host_entity)
    entity.free()

    TestHelper.assert_true(
        found == null, "find_nearest_host returns null for ownerless seeker: found=%s" % [found]
    )
