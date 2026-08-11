extends Node

# MovementController move-target API tests (backs SelectComponent move target line)

const SELECT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/SelectComponent.tscn")

var _ts: Node = null


func _make_mc() -> MovementController:
    # Parent lives in the tree so global_position is valid; the MovementController
    # itself stays detached so it does not start _physics_process during the test.
    var parent := Node3D.new()
    (Engine.get_main_loop() as SceneTree).root.add_child(parent)
    var mc := MovementController.new()
    mc._parent = parent
    return mc


func _free_mc(mc: MovementController) -> void:
    mc._parent.free()
    mc.free()


func test_get_target_position_returns_last_waypoint():
    var mc := _make_mc()
    mc._waypoints = PackedVector3Array([Vector3(1, 0, 1), Vector3(5, 0, 7)])
    (
        TestHelper
        . assert_true(
            mc.get_target_position() == Vector3(5, 0, 7),
            (
                "get_target_position returns last waypoint: get_target_position returned %s"
                % mc.get_target_position()
            ),
        )
    )
    _free_mc(mc)


func test_get_target_position_idle_returns_parent_position():
    var mc := _make_mc()
    mc._waypoints = PackedVector3Array()
    mc._parent.global_position = Vector3(2, 0, 3)
    (
        TestHelper
        . assert_true(
            mc.get_target_position() == Vector3(2, 0, 3),
            (
                "get_target_position falls back to parent position when idle: idle "
                + "get_target_position returned %s" % mc.get_target_position()
            ),
        )
    )
    _free_mc(mc)


func test_is_moving_tracks_state():
    var mc := _make_mc()
    mc._state = MovementController.State.IDLE
    var idle_ok := not mc.is_moving()
    mc._state = MovementController.State.MOVING
    var moving_ok := mc.is_moving()
    mc._state = MovementController.State.ROTATING
    var rotating_ok := mc.is_moving()
    (
        TestHelper
        . assert_true(
            idle_ok and moving_ok and rotating_ok,
            (
                "is_moving true unless IDLE: is_moving mismatch (idle=%s moving=%s rotating=%s)"
                % [idle_ok, moving_ok, rotating_ok]
            ),
        )
    )
    _free_mc(mc)


func test_movement_started_only_on_player_order():
    # movement_started drives the move-target line, so it must fire only for
    # genuine player orders — not internal re-paths or scatter/nudge on other units.
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    if SpatialHash.instance:
        SpatialHash.instance._grid.clear()
    var mc := _make_mc()
    mc._parent.global_position = Vector3(1, 0, 1)
    var count := [0]
    var seen_target: Array = []
    mc.movement_started.connect(
        func():
            count[0] += 1
            seen_target.append(mc.get_target_position())
    )

    # Internal re-path / scatter (internal = true): no signal.
    mc.set_target_position(Vector3(5, 0, 5), false, false, true)
    var suppressed: bool = count[0] == 0

    # Genuine player move order (internal defaults to false): signal fires once
    # and the destination is already the real target (snapped to its cell
    # center), not the start position.
    var dest := Vector3(5, 0, 5)
    var dest_cell_center := CellUtil.cell_to_world(CellUtil.world_to_cell(dest))
    mc.set_target_position(dest)
    var emitted: bool = count[0] == 1
    var correct_target: bool = not seen_target.is_empty() and seen_target[0] == dest_cell_center

    _ts.clear()
    (
        TestHelper
        . assert_true(
            suppressed and emitted and correct_target,
            (
                "movement_started fires only for player orders at real target: emit gating "
                + (
                    "wrong (suppressed=%s emitted=%s correct_target=%s)"
                    % [suppressed, emitted, correct_target]
                )
            ),
        )
    )
    _free_mc(mc)


func test_move_line_endpoint_tracks_attack_target():
    # While attacking, the move line must point at the enemy entity (tracking
    # its current position), not the fixed approach stop position. Without an
    # active attack target it falls back to the movement destination.
    var entity := Node3D.new()
    var cc := CombatComponent.new()
    entity.add_child(cc)
    var mc := MovementController.new()
    entity.add_child(mc)
    mc._waypoints = PackedVector3Array([Vector3(2, 0, 3)])
    var sc := SelectComponent.new()
    sc._combat_component = cc
    sc._movement_controller = mc
    var target := Node3D.new()
    (Engine.get_main_loop() as SceneTree).root.add_child(target)
    target.global_position = Vector3(10, 0, 20)

    cc.set_target(target)
    var attack_endpoint: Vector3 = sc._get_move_line_endpoint()
    var attack_ok := attack_endpoint == Vector3(10, 0, 20)

    cc.clear_target()
    var fallback_endpoint: Vector3 = sc._get_move_line_endpoint()
    var fallback_ok := fallback_endpoint == Vector3(2, 0, 3)

    sc.free()
    entity.free()
    target.free()
    (
        TestHelper
        . assert_true(
            attack_ok and fallback_ok,
            (
                "move line endpoint tracks attack target, else move destination: endpoint "
                + "wrong (attack=%s fallback=%s)" % [attack_endpoint, fallback_endpoint]
            ),
        )
    )


func test_reselect_shows_line_for_stationary_attacker():
    # An in-range attacker (not moving) that is deselected and re-selected must
    # still show the move line pointing at the enemy — movement alone is not
    # enough when the line tracks an active attack target. The line now flows
    # through the shared MoveLineRenderer: get_line_render_data() is the
    # renderer-facing contract the shared buffer consumes.
    var entity := Node3D.new()
    var cc := CombatComponent.new()
    entity.add_child(cc)
    var mc := MovementController.new()
    entity.add_child(mc)
    mc._state = MovementController.State.IDLE
    var target := Node3D.new()
    (Engine.get_main_loop() as SceneTree).root.add_child(target)
    target.global_position = Vector3(10, 0, 20)
    cc.set_target(target)

    var sc := SelectComponent.new()
    sc._combat_component = cc
    sc._movement_controller = mc
    var timer := Timer.new()
    sc.add_child(timer)
    sc._move_line_timer = timer

    sc.set_is_selected(true)
    var shown: bool = not sc.get_line_render_data().is_empty()

    sc.set_is_selected(false)
    var hidden: bool = sc.get_line_render_data().is_empty()

    sc.free()
    entity.free()
    target.free()
    var msg := (
        "reselect shows line for stationary attacker; deselect hides (shown=%s hidden=%s)"
        % [shown, hidden]
    )
    TestHelper.assert_true(shown and hidden, msg)


func test_move_line_timer_is_0_3s_and_fades():
    # The move-target line is an order-acknowledgement glyph: 0.3s lifetime with
    # a fade over the tail (alpha drops below 1 as the timer nears expiry).
    var parent := Node3D.new()
    (Engine.get_main_loop() as SceneTree).root.add_child(parent)
    var mc := MovementController.new()
    mc.name = "MovementController"
    mc._parent = parent
    parent.add_child(mc)
    var sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    parent.add_child(sc)

    var duration_ok: bool = (
        sc._move_line_timer != null and is_equal_approx(sc._move_line_timer.wait_time, 0.3)
    )
    sc._move_line_timer.wait_time = 0.05
    sc._move_line_timer.start()
    sc._show_move_line()
    var alpha: float = sc._line_alpha()
    var fade_ok := alpha > 0.0 and alpha < 1.0

    sc.free()
    parent.free()
    (
        TestHelper
        . assert_true(
            duration_ok and fade_ok,
            "move line timer is 0.3s and fades over the tail (alpha=%s)" % alpha,
        )
    )
