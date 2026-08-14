extends Node

# HarvestComponent + DockHostComponent + DockUnloadComponent integration tests
# Uses mock nodes — no autoloads required except what the runner injects.

var _slot_emitted_flag := false
var _timeout_emitted_flag := false
var _timeout_docker_ref: Node = null
var _em: Node = null

# --- helpers ---


func _make_entity(
    dock_id: String = "GDI_REFINERY", storage: int = 700, owner_id: int = -1
) -> Node3D:
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

    if owner_id >= 0:
        var stats := StatsComponent.new()
        stats.name = "StatsComponent"
        stats.player_id = owner_id
        entity.add_child(stats)

    return entity


func _make_dock_entity(
    dock_rotation: float = -90.0,
    _foundation: Vector2i = Vector2i(4, 3),
    _dock_id: String = "GDI_REFINERY"
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


func _init_harvest(_harvest: HarvestComponent, _dock_id: String = "GDI_REFINERY") -> void:
    pass


func _init_dock(dock_comp: DockHostComponent, dock_entity: Node3D) -> void:
    var cs := CellUtil.CELL_SIZE
    var found := dock_comp._get_foundation()
    var origin_cell := Vector2i(
        floori((dock_entity.position.x - found.x * 0.5 * cs) / cs),
        floori((dock_entity.position.z - found.y * 0.5 * cs) / cs)
    )
    var top_left := CellUtil.cell_to_world(origin_cell)
    dock_comp._dock_cell = CellUtil.world_to_cell(
        top_left + dock_entity.global_transform.basis * dock_comp.dock_position
    )


func _on_slot_signal() -> void:
    _slot_emitted_flag = true


func _on_dock_timeout_test(docker: Node) -> void:
    _timeout_emitted_flag = true
    _timeout_docker_ref = docker


# --- HarvestComponent state tests ---


func test_harvest_initial_state_is_idle():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    (
        TestHelper
        . assert_true(
            harvest._state == HarvestComponent.State.IDLE,
            "HarvestComponent starts in IDLE: initial state = %d (expected IDLE)" % harvest._state,
        )
    )
    entity.queue_free()


func test_harvest_cargo_full_transitions_to_delivering():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    harvest._state = HarvestComponent.State.HARVESTING
    # Manually set cargo to full
    var transport := _get_transport(entity)
    transport.cargo = {"tiberium_green": 700.0}
    harvest._harvest_accumulator = 0.0

    # Simulate _process — should detect full cargo and transition to DELIVERING
    # But we need to mock _get_storage_capacity to return 700
    # Since transport.storage = 700 and cargo = 700, get_cargo() >= _get_storage_capacity()
    # The _process HARVESTING branch checks this

    # Actually, let's just call _deliver_cargo directly
    harvest._deliver_cargo(entity)

    (
        TestHelper
        . assert_true(
            harvest._state == HarvestComponent.State.DELIVERING,
            (
                "cargo full transitions to DELIVERING: state = %d (expected DELIVERING)"
                % harvest._state
            ),
        )
    )
    entity.queue_free()


func test_harvest_cancel_goes_to_idle():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    harvest._state = HarvestComponent.State.HARVESTING

    harvest.cancel_harvest()

    (
        TestHelper
        . assert_true(
            harvest._state == HarvestComponent.State.IDLE,
            "cancel_harvest transitions to IDLE: state = %d (expected IDLE)" % harvest._state,
        )
    )
    entity.queue_free()


func test_harvest_dock_undocked_goes_to_seek_node():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    harvest._state = HarvestComponent.State.DELIVERING
    # Clear cargo so _assess_next_action hibernates (empty, no resources reachable)
    var transport := _get_transport(entity)
    transport.cargo = {}

    harvest.on_dock_undocked(entity)

    TestHelper.assert_true(
        harvest._state == HarvestComponent.State.HIBERNATE,
        (
            (
                "dock_undocked from DELIVERING → assesses next action: "
                + "state = %d (expected HIBERNATE)"
            )
            % harvest._state
        )
    )
    entity.queue_free()


func test_harvest_dock_slot_failed_schedules_retry():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    harvest._state = HarvestComponent.State.DELIVERING

    # No reachable dock: must schedule a retry and stay DELIVERING, NOT re-seek
    # synchronously (which recurses via dock_slot_failed → stack overflow).
    harvest._on_dock_slot_failed()

    (
        TestHelper
        . assert_true(
            harvest._state == HarvestComponent.State.DELIVERING and harvest._deliver_retry > 0.0,
            (
                "dock_slot_failed schedules retry, no synchronous re-seek: state=%d retry=%f"
                % [harvest._state, harvest._deliver_retry]
            ),
        )
    )
    entity.queue_free()


func test_harvest_dock_cancelled_goes_to_seek_node():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    harvest._state = HarvestComponent.State.DELIVERING
    # Clear cargo so _assess_next_action hibernates (empty, no resources reachable)
    var transport := _get_transport(entity)
    transport.cargo = {}

    harvest._on_dock_cancelled()

    TestHelper.assert_true(
        harvest._state == HarvestComponent.State.HIBERNATE,
        (
            (
                "dock_cancelled from DELIVERING → assesses next action: "
                + "state = %d (expected HIBERNATE)"
            )
            % harvest._state
        )
    )
    entity.queue_free()


func test_harvest_empty_no_resource_enters_hibernate():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    var transport := _get_transport(entity)
    transport.cargo = {}  # empty, and no resources exist in the group
    harvest._state = HarvestComponent.State.DELIVERING

    harvest._assess_next_action()

    # Empty + nothing to harvest → HIBERNATE (auto-retry), NOT IDLE (player-only).
    (
        TestHelper
        . assert_true(
            harvest._state == HarvestComponent.State.HIBERNATE,
            (
                "empty + no resource → HIBERNATE, not IDLE: state=%d (expected HIBERNATE)"
                % harvest._state
            ),
        )
    )
    entity.queue_free()


func test_harvest_hibernate_ticks_research_timer():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    harvest._state = HarvestComponent.State.HIBERNATE
    harvest._hibernate_timer = 2.0

    harvest._process(0.5)

    (
        TestHelper
        . assert_true(
            (
                harvest._state == HarvestComponent.State.HIBERNATE
                and is_equal_approx(harvest._hibernate_timer, 1.5)
            ),
            (
                "HIBERNATE ticks the re-search timer down: state=%d timer=%f"
                % [harvest._state, harvest._hibernate_timer]
            ),
        )
    )
    entity.queue_free()


func test_harvest_change_state_noop_on_same_state():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    harvest._state = HarvestComponent.State.IDLE

    var emitted := false
    harvest.state_changed.connect(func(_s): emitted = true)
    harvest._change_state(HarvestComponent.State.IDLE)

    (
        TestHelper
        . assert_true(
            not emitted,
            (
                "_change_state is a no-op for same state: "
                + "state_changed emitted for same-state transition"
            ),
        )
    )
    entity.queue_free()


func test_harvest_set_target_node_transitions_to_seek_node():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    harvest._state = HarvestComponent.State.IDLE

    var resource := Node3D.new()
    resource.name = "TestResource"
    var rc := ResourceComponent.new()
    rc.name = "ResourceComponent"
    resource.add_child(rc)
    add_child(resource)

    # set_target_node sets _current_resource and changes state
    harvest.set_target_node(resource)

    # State should have changed from IDLE (may be SEEK_NODE or redirected
    # by SpatialHash reservation failure in test env)
    (
        TestHelper
        . assert_true(
            harvest._state != HarvestComponent.State.IDLE,
            "set_target_node changed state from IDLE: state still IDLE after set_target_node",
        )
    )
    resource.queue_free()
    entity.queue_free()


func test_harvest_set_target_refinery_enters_delivering():
    var entity := _make_entity()
    var dc := DockClientComponent.new()
    dc.name = "DockClientComponent"
    entity.add_child(dc)
    add_child(entity)
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var harvest := _get_harvest(entity)
    harvest.dock_client = dc  # _ready doesn't run (suite isn't in tree), wire manually
    harvest._state = HarvestComponent.State.IDLE

    # Player-ordered dock must enter DELIVERING, else the undock handler
    # (gated on DELIVERING) never resumes the harvest loop afterwards.
    harvest.set_target_refinery(dock_entity)

    (
        TestHelper
        . assert_true(
            harvest._state == HarvestComponent.State.DELIVERING,
            (
                "set_target_refinery enters DELIVERING: state=%d (expected DELIVERING)"
                % harvest._state
            ),
        )
    )
    dock_entity.queue_free()
    entity.queue_free()


# --- DockHostComponent tests ---


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

    (
        TestHelper
        . assert_true(
            result and dock_comp.current_docker == harvest,
            (
                "request_dock succeeds when dock is empty: result=%s, current_docker=%s"
                % [result, dock_comp.current_docker]
            ),
        )
    )

    entity.queue_free()
    dock_entity.queue_free()


func test_request_dock_fails_when_occupied():
    var dock_entity := _make_dock_entity(-90.0, Vector2i(4, 3), "GDI_REFINERY")
    add_child(dock_entity)
    var entity_a := _make_entity("GDI_REFINERY")
    add_child(entity_a)
    var entity_b := _make_entity("GDI_REFINERY")
    add_child(entity_b)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest_a := _get_harvest(entity_a)
    var harvest_b := _get_harvest(entity_b)
    _init_harvest(harvest_a, "GDI_REFINERY")
    _init_harvest(harvest_b, "GDI_REFINERY")
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest_a)
    var result: bool = dock_comp.request_dock(harvest_b)

    (
        TestHelper
        . assert_true(
            not result and dock_comp.current_docker == harvest_a,
            (
                "request_dock fails when another docker is active: result=%s, current_docker=%s"
                % [result, dock_comp.current_docker]
            ),
        )
    )

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

    (
        TestHelper
        . assert_true(
            result,
            "request_dock returns true for same docker (re-dock): re-dock returned false",
        )
    )

    entity.queue_free()
    dock_entity.queue_free()


func test_request_dock_queues_second_docker():
    var dock_entity := _make_dock_entity(-90.0, Vector2i(4, 3), "GDI_REFINERY")
    add_child(dock_entity)
    var entity_a := _make_entity("GDI_REFINERY")
    add_child(entity_a)
    var entity_b := _make_entity("GDI_REFINERY")
    add_child(entity_b)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest_a := _get_harvest(entity_a)
    var harvest_b := _get_harvest(entity_b)
    _init_harvest(harvest_a, "GDI_REFINERY")
    _init_harvest(harvest_b, "GDI_REFINERY")
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest_a)
    var result: bool = dock_comp.request_dock(harvest_b)

    (
        TestHelper
        . assert_true(
            not result and dock_comp.queue.has(harvest_b),
            (
                "second docker is queued when dock is occupied: result=%s, in_queue=%s"
                % [result, dock_comp.queue.has(harvest_b)]
            ),
        )
    )

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
    dock_comp._process(0.0)  # resolve vacate

    var key: int = CellUtil.cell_key(dock_cell)
    var still_reserved: bool = SpatialHash.instance._reserved.has(key)

    (
        TestHelper
        . assert_true(
            not still_reserved and dock_comp.current_docker == null,
            (
                (
                    "leave_dock releases dock cell and clears current_docker: "
                    + "still_reserved=%s, current_docker=%s"
                )
                % [still_reserved, dock_comp.current_docker]
            ),
        )
    )

    entity.queue_free()
    dock_entity.queue_free()


func test_leave_dock_reserves_cell_for_next_docker():
    var dock_entity := _make_dock_entity(-90.0, Vector2i(4, 3), "GDI_REFINERY")
    add_child(dock_entity)
    var entity_a := _make_entity("GDI_REFINERY")
    add_child(entity_a)
    var entity_b := _make_entity("GDI_REFINERY")
    add_child(entity_b)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest_a := _get_harvest(entity_a)
    var harvest_b := _get_harvest(entity_b)
    _init_harvest(harvest_a, "GDI_REFINERY")
    _init_harvest(harvest_b, "GDI_REFINERY")
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest_a)
    dock_comp.request_dock(harvest_b)  # queued
    var dock_cell := dock_comp._dock_cell

    dock_comp.leave_dock(harvest_a)  # triggers vacate
    dock_comp._process(0.0)  # resolve vacate → promotes B

    var key: int = CellUtil.cell_key(dock_cell)
    var reserved_for_b: bool = SpatialHash.instance._reserved.has(key)

    TestHelper.assert_true(
        reserved_for_b and dock_comp.current_docker == harvest_b,
        (
            (
                "leave_dock reserves dock cell for next queued docker: "
                + "reserved=%s, current_docker=%s"
            )
            % [reserved_for_b, dock_comp.current_docker]
        )
    )

    entity_a.queue_free()
    entity_b.queue_free()
    dock_entity.queue_free()


func test_leave_dock_emits_slot_available():
    var dock_entity := _make_dock_entity(-90.0, Vector2i(4, 3), "GDI_REFINERY")
    add_child(dock_entity)
    var entity_a := _make_entity("GDI_REFINERY")
    add_child(entity_a)
    var entity_b := _make_entity("GDI_REFINERY")
    add_child(entity_b)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest_a := _get_harvest(entity_a)
    var harvest_b := _get_harvest(entity_b)
    _init_harvest(harvest_a, "GDI_REFINERY")
    _init_harvest(harvest_b, "GDI_REFINERY")
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest_a)
    dock_comp.request_dock(harvest_b)  # queued

    _slot_emitted_flag = false
    dock_comp.slot_available.connect(_on_slot_signal)

    dock_comp.leave_dock(harvest_a)
    dock_comp._process(0.0)  # resolve vacate

    (
        TestHelper
        . assert_true(
            _slot_emitted_flag,
            (
                "leave_dock emits slot_available when queue has next docker: "
                + "slot_available was not emitted"
            ),
        )
    )

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

    (
        TestHelper
        . assert_true(
            not slot_emitted,
            (
                "leave_dock does not emit slot_available when queue is empty: "
                + "slot_available was emitted with empty queue"
            ),
        )
    )

    entity.queue_free()
    dock_entity.queue_free()


func test_full_dock_cycle_leave_transfers_to_next():
    var dock_entity := _make_dock_entity(-90.0, Vector2i(4, 3), "GDI_REFINERY")
    add_child(dock_entity)
    var entity_a := _make_entity("GDI_REFINERY")
    add_child(entity_a)
    var entity_b := _make_entity("GDI_REFINERY")
    add_child(entity_b)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest_a := _get_harvest(entity_a)
    var harvest_b := _get_harvest(entity_b)
    _init_harvest(harvest_a, "GDI_REFINERY")
    _init_harvest(harvest_b, "GDI_REFINERY")
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest_a)
    var docked_a: bool = dock_comp.current_docker == harvest_a

    dock_comp.request_dock(harvest_b)
    var queued_b: bool = dock_comp.queue.has(harvest_b)

    dock_comp.leave_dock(harvest_a)
    dock_comp._process(0.0)  # resolve vacate
    var transferred: bool = dock_comp.current_docker == harvest_b
    var queue_empty: bool = dock_comp.queue.is_empty()

    var key: int = CellUtil.cell_key(dock_comp._dock_cell)
    var cell_reserved: bool = SpatialHash.instance._reserved.has(key)

    (
        TestHelper
        . assert_true(
            docked_a and queued_b and transferred and queue_empty and cell_reserved,
            (
                "full dock cycle: A docks → B queued → A leaves → B docked + cell reserved: "
                + (
                    "docked_a=%s queued_b=%s transferred=%s queue_empty=%s cell_reserved=%s"
                    % [docked_a, queued_b, transferred, queue_empty, cell_reserved]
                )
            ),
        )
    )

    entity_a.queue_free()
    entity_b.queue_free()
    dock_entity.queue_free()


# --- DockUnloadComponent tests ---


func test_dock_unload_begin_unload_enables_processing():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)

    var dock_unload := _get_dock_unload(dock_entity)
    var was_before := dock_unload.is_processing()

    dock_unload.begin_unload()
    var is_after := dock_unload.is_processing()

    (
        TestHelper
        . assert_true(
            not was_before and is_after,
            "begin_unload() enables processing: before=%s, after=%s" % [was_before, is_after],
        )
    )

    dock_entity.queue_free()


func test_dock_unload_stops_on_undocked():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)

    var dock_unload := _get_dock_unload(dock_entity)
    dock_unload.begin_unload()
    var was_processing := dock_unload.is_processing()

    dock_unload._on_docker_undocked(dock_entity)
    var is_after := dock_unload.is_processing()

    (
        TestHelper
        . assert_true(
            was_processing and not is_after,
            "docker_undocked stops processing: before=%s, after=%s" % [was_processing, is_after],
        )
    )

    dock_entity.queue_free()


func test_dock_unload_credits_harvester_owner():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var entity := _make_entity("GDI_REFINERY", 700, 300)
    add_child(entity)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest := _get_harvest(entity)
    _init_harvest(harvest)
    _init_dock(dock_comp, dock_entity)
    var dock_unload := _get_dock_unload(dock_entity)
    dock_unload._economy_manager = _em
    var docked: bool = dock_comp.request_dock(harvest)

    var owner_before: int = _em.get_balance(300)
    var local_before: int = _em.get_balance(PlayerManager.get_local_player_id())
    dock_unload._process(0.5)
    var owner_after: int = _em.get_balance(300)
    var local_after: int = _em.get_balance(PlayerManager.get_local_player_id())

    (
        TestHelper
        . assert_true(
            docked and owner_after > owner_before,
            (
                "unload credits harvester owner: docked=%s, owner %d->%d"
                % [docked, owner_before, owner_after]
            ),
        )
    )
    (
        TestHelper
        . assert_true(
            local_after == local_before,
            "unload must not credit local player: local %d->%d" % [local_before, local_after],
        )
    )

    entity.queue_free()
    dock_entity.queue_free()


func test_dock_unload_unset_owner_credits_local():
    if _em == null:
        TestHelper.fail("EconomyManager not injected")
        return
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var entity := _make_entity()
    add_child(entity)

    var dock_comp := _get_dock_comp(dock_entity)
    var harvest := _get_harvest(entity)
    _init_harvest(harvest)
    _init_dock(dock_comp, dock_entity)
    var dock_unload := _get_dock_unload(dock_entity)
    dock_unload._economy_manager = _em
    var docked: bool = dock_comp.request_dock(harvest)

    var local_before: int = _em.get_balance(PlayerManager.get_local_player_id())
    dock_unload._process(0.5)
    var local_after: int = _em.get_balance(PlayerManager.get_local_player_id())

    (
        TestHelper
        . assert_true(
            docked and local_after > local_before,
            (
                "unset owner falls back to local player: docked=%s, local %d->%d"
                % [docked, local_before, local_after]
            ),
        )
    )

    entity.queue_free()
    dock_entity.queue_free()


func test_cargo_validation_accepts_matching_category():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var dock_unload := _get_dock_unload(dock_entity)
    dock_unload.accepted_resource_categories = PackedStringArray(["tiberium"])

    var transport := TransportComponent.new()
    transport.cargo = {"tiberium": 100.0}

    var result: bool = dock_unload._validate_cargo(transport)
    (
        TestHelper
        . assert_true(
            result,
            (
                "cargo validation accepts matching category: "
                + "cargo validation rejected matching category"
            ),
        )
    )

    dock_entity.queue_free()


func test_cargo_validation_rejects_unaccepted():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var dock_unload := _get_dock_unload(dock_entity)
    dock_unload.accepted_resource_categories = PackedStringArray(["tiberium"])

    var transport := TransportComponent.new()
    transport.cargo = {"vehicle_parts": 50.0}

    var result: bool = dock_unload._validate_cargo(transport)
    (
        TestHelper
        . assert_true(
            not result,
            (
                "cargo validation rejects unaccepted category: "
                + "cargo validation accepted unaccepted category"
            ),
        )
    )

    dock_entity.queue_free()


func test_cargo_validation_empty_accepts_all():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var dock_unload := _get_dock_unload(dock_entity)
    dock_unload.accepted_resource_categories = PackedStringArray()

    var transport := TransportComponent.new()
    transport.cargo = {"anything": 100.0}

    var result: bool = dock_unload._validate_cargo(transport)
    TestHelper.assert_true(
        result, "empty accepted_resource_categories accepts all: empty categories rejected cargo"
    )

    dock_entity.queue_free()


func test_configure_copies_categories_from_entity_data():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var dock_unload := _get_dock_unload(dock_entity)

    var data := EntityData.new()
    data.accepted_resource_categories = PackedStringArray(["tiberium", "minerals"])

    dock_unload.configure(data)

    (
        TestHelper
        . assert_true(
            (
                dock_unload.accepted_resource_categories.size() == 2
                and dock_unload.accepted_resource_categories.has("tiberium")
                and dock_unload.accepted_resource_categories.has("minerals")
            ),
            (
                "configure copies accepted_resource_categories from EntityData: categories = %s"
                % str(dock_unload.accepted_resource_categories)
            ),
        )
    )

    dock_entity.queue_free()


# --- DockHostComponent stale eviction tests ---


func test_stale_eviction():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var dock_comp := _get_dock_comp(dock_entity)
    dock_comp.stale_timeout = 0.1

    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    _init_harvest(harvest)
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest)
    dock_comp._process(0.2)

    (
        TestHelper
        . assert_true(
            dock_comp.current_docker == null,
            (
                "stale client evicted after stale_timeout: current_docker=%s"
                % dock_comp.current_docker
            ),
        )
    )

    entity.queue_free()
    dock_entity.queue_free()


func test_stale_eviction_emits_dock_timeout():
    var dock_entity := _make_dock_entity()
    add_child(dock_entity)
    var dock_comp := _get_dock_comp(dock_entity)
    dock_comp.stale_timeout = 0.1

    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)
    _init_harvest(harvest)
    _init_dock(dock_comp, dock_entity)

    dock_comp.request_dock(harvest)

    _timeout_emitted_flag = false
    _timeout_docker_ref = null
    dock_comp.dock_timeout.connect(_on_dock_timeout_test)

    dock_comp._process(0.2)

    (
        TestHelper
        . assert_true(
            _timeout_emitted_flag and _timeout_docker_ref == harvest,
            (
                "stale eviction emits dock_timeout signal: emitted=%s, docker=%s"
                % [_timeout_emitted_flag, _timeout_docker_ref]
            ),
        )
    )

    entity.queue_free()
    dock_entity.queue_free()


# --- HarvestComponent.get_order_for_target tests ---


func test_harvest_order_resource_target():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)

    var resource_entity := Node3D.new()
    resource_entity.name = "TiberiumNode"
    var resource_comp := ResourceComponent.new()
    resource_comp.name = "ResourceComponent"
    resource_entity.add_child(resource_comp)
    add_child(resource_entity)

    var order := harvest.get_order_for_target(resource_entity, Vector2i.ZERO, Vector3.ZERO, {})

    TestHelper.assert_true(order != null, "click resource -> order not null")
    TestHelper.assert_eq(order.cursor, CursorState.Type.HARVEST, "cursor -> HARVEST")
    TestHelper.assert_eq(order.priority, 20, "priority -> 20")

    resource_entity.queue_free()
    entity.queue_free()


func test_harvest_order_refinery_target():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)

    var dock_entity := _make_dock_entity()
    add_child(dock_entity)

    var order := harvest.get_order_for_target(dock_entity, Vector2i.ZERO, Vector3.ZERO, {})

    TestHelper.assert_true(order != null, "click refinery -> order not null")
    TestHelper.assert_eq(order.cursor, CursorState.Type.ENTER, "cursor -> ENTER")
    TestHelper.assert_eq(order.priority, 15, "priority -> 15")

    dock_entity.queue_free()
    entity.queue_free()


func test_harvest_order_null_target():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)

    var order := harvest.get_order_for_target(null, Vector2i.ZERO, Vector3.ZERO, {})

    TestHelper.assert_true(order == null, "null target -> null order")

    entity.queue_free()


func test_harvest_order_unrelated_target():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)

    var unrelated := Node3D.new()
    unrelated.name = "UnrelatedEntity"
    add_child(unrelated)

    var order := harvest.get_order_for_target(unrelated, Vector2i.ZERO, Vector3.ZERO, {})

    TestHelper.assert_true(order == null, "unrelated target -> null order")

    unrelated.queue_free()
    entity.queue_free()


func test_harvest_order_queued_modifier():
    var entity := _make_entity()
    add_child(entity)
    var harvest := _get_harvest(entity)

    var resource_entity := Node3D.new()
    resource_entity.name = "TiberiumNode"
    var resource_comp := ResourceComponent.new()
    resource_comp.name = "ResourceComponent"
    resource_entity.add_child(resource_comp)
    add_child(resource_entity)

    var modifiers := {OrderResult.MOD_QUEUED: true}
    var order := harvest.get_order_for_target(
        resource_entity, Vector2i.ZERO, Vector3.ZERO, modifiers
    )

    TestHelper.assert_true(order != null, "queued modifier -> order not null")
    TestHelper.assert_true(order.queued, "queued modifier -> order.queued = true")

    resource_entity.queue_free()
    entity.queue_free()
