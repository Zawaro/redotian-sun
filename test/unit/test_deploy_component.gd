extends Node

# DeployComponent tests — component configuration, snapshot, and deploy/undeploy logic

const DEPLOY_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/DeployComponent.gd")

var _sm: Node = null
var _bm: Node = null
var _pm: Node = null


func test_deploy_component_defaults():
    var entity := Node3D.new()
    var component := Node.new()
    component.name = "DeployComponent"
    component.set_script(DEPLOY_COMPONENT_SCRIPT)
    entity.add_child(component)

    var deploy := component as DeployComponent
    (
        TestHelper
        . assert_true(
            deploy.deploys_into == "" and deploy.undeploys_into == "",
            "DeployComponent defaults are empty strings: DeployComponent defaults should be empty",
        )
    )

    entity.free()


func test_deploy_component_configure():
    var data := EntityData.new()
    data.id = "TEST_MCV"
    data.entity_type = EntityData.EntityType.VEHICLE
    data.strength = 1000
    data.owner = PackedStringArray(["GDI"])
    data.deploys_into = "GDI_CONSTRUCTION_YARD"

    var entity := Node3D.new()
    var component := Node.new()
    component.name = "DeployComponent"
    component.set_script(DEPLOY_COMPONENT_SCRIPT)
    entity.add_child(component)

    var deploy := component as DeployComponent
    deploy.configure(data)

    (
        TestHelper
        . assert_true(
            deploy.deploys_into == "GDI_CONSTRUCTION_YARD",
            (
                "DeployComponent.configure sets deploys_into: Expected deploys_into="
                + "'GDI_CONSTRUCTION_YARD', "
                + "got '%s'" % deploy.deploys_into
            ),
        )
    )

    entity.free()


func test_can_deploy():
    var entity := Node3D.new()
    var component := Node.new()
    component.name = "DeployComponent"
    component.set_script(DEPLOY_COMPONENT_SCRIPT)
    entity.add_child(component)

    var deploy := component as DeployComponent
    deploy.deploys_into = "GDI_CONSTRUCTION_YARD"

    (
        TestHelper
        . assert_true(
            deploy.can_deploy() and not deploy.can_undeploy(),
            (
                "can_deploy() returns true when deploys_into set: can_deploy() should be true, "
                + "can_undeploy() false"
            ),
        )
    )

    entity.free()


func test_can_undeploy():
    var entity := Node3D.new()
    var component := Node.new()
    component.name = "DeployComponent"
    component.set_script(DEPLOY_COMPONENT_SCRIPT)
    entity.add_child(component)

    var deploy := component as DeployComponent
    deploy.undeploys_into = "GDI_MCV"

    (
        TestHelper
        . assert_true(
            deploy.can_undeploy() and not deploy.can_deploy(),
            (
                "can_undeploy() returns true when undeploys_into set: "
                + "can_undeploy() should be true, can_deploy() false"
            ),
        )
    )

    entity.free()


func test_deselect_entity_clears_both_selected_and_hovering():
    var entity := Node3D.new()
    var select_component := SelectComponent.new()
    select_component.name = "SelectComponent"
    select_component.set_is_selected(true)
    select_component.set_is_hovering(true)
    entity.add_child(select_component)
    var deploy := DeployComponent.new()

    deploy._deselect_entity(entity)

    (
        TestHelper
        . assert_true(
            not select_component.is_selected and not select_component.is_hovering,
            (
                "deselect_entity clears both is_selected and is_hovering: "
                + "deselect_entity should clear both flags"
            ),
        )
    )

    entity.free()


func test_deselect_entity_noops_without_select_component():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()

    deploy._deselect_entity(entity)

    TestHelper.assert_true(true, "deselect_entity does not crash without SelectComponent")

    entity.free()


# --- Snapshot tests ---


func test_snapshot_captures_health_ratio():
    var entity := Node3D.new()
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    health.max_health = 1000
    health.current_health = 500
    entity.add_child(health)
    var deploy := DeployComponent.new()

    var snap := deploy._snapshot_entity(entity)

    (
        TestHelper
        . assert_true(
            abs(snap["health_ratio"] - 0.5) < 0.001,
            (
                "snapshot captures health_ratio = 0.5: Expected health_ratio 0.5, got %s"
                % snap["health_ratio"]
            ),
        )
    )

    entity.free()


func test_snapshot_defaults_health_to_one_when_no_component():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()

    var snap := deploy._snapshot_entity(entity)

    (
        TestHelper
        . assert_true(
            abs(snap["health_ratio"] - 1.0) < 0.001,
            (
                "snapshot defaults health_ratio to 1.0 without HealthComponent: "
                + "Expected default health_ratio 1.0, got %s" % snap["health_ratio"]
            ),
        )
    )

    entity.free()


func test_snapshot_captures_player_id():
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = 3
    entity.add_child(stats)
    var deploy := DeployComponent.new()

    var snap := deploy._snapshot_entity(entity)

    (
        TestHelper
        . assert_true(
            snap["player_id"] == 3,
            "snapshot captures player_id = 3: Expected player_id 3, got %s" % snap["player_id"],
        )
    )

    entity.free()


func test_snapshot_captures_selection():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return

    _sm.deselect_all()
    var entity := Node3D.new()
    var select_component := SelectComponent.new()
    select_component.name = "SelectComponent"
    entity.add_child(select_component)
    var deploy := DeployComponent.new()
    _sm.add_child(entity)

    _sm.add_entity(select_component)
    var snap := deploy._snapshot_entity(entity)

    (
        TestHelper
        . assert_true(
            snap["was_selected"] == true,
            (
                "snapshot captures was_selected = true: Expected was_selected true, got %s"
                % snap["was_selected"]
            ),
        )
    )

    _sm.deselect_all()
    entity.free()


# --- Apply snapshot tests ---


func test_apply_snapshot_sets_health():
    var target := Node3D.new()
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    health.max_health = 1000
    health.current_health = 1000
    target.add_child(health)
    var deploy := DeployComponent.new()

    var snap := {"health_ratio": 0.5, "was_selected": false, "player_id": 1}
    deploy._apply_snapshot(target, snap)

    TestHelper.assert_true(
        health.current_health == 500,
        (
            (
                "apply_snapshot sets health to 500 (50%% of 1000): "
                + "Expected current_health 500, got %d"
            )
            % health.current_health
        )
    )

    target.free()


func test_apply_snapshot_sets_player_id():
    var target := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = -1
    target.add_child(stats)
    var deploy := DeployComponent.new()

    var snap := {"health_ratio": 1.0, "was_selected": false, "player_id": 2}
    deploy._apply_snapshot(target, snap)

    (
        TestHelper
        . assert_true(
            stats.player_id == 2,
            "apply_snapshot sets player_id = 2: Expected player_id 2, got %d" % stats.player_id,
        )
    )

    target.free()


func test_apply_snapshot_restores_selection():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return

    _sm.deselect_all()
    var target := Node3D.new()
    var select_component := SelectComponent.new()
    select_component.name = "SelectComponent"
    target.add_child(select_component)
    var deploy := DeployComponent.new()
    _sm.add_child(target)

    var snap := {"health_ratio": 1.0, "was_selected": true, "player_id": 1}
    deploy._apply_snapshot(target, snap)

    (
        TestHelper
        . assert_true(
            _sm.selected_entities.has(select_component) and select_component.is_selected,
            (
                "apply_snapshot restores selection on target: "
                + "apply_snapshot should add target SelectComponent to SelectionManager"
            ),
        )
    )

    _sm.deselect_all()
    target.free()


func test_apply_snapshot_respects_transfer_health_ratio_flag():
    var target := Node3D.new()
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    health.max_health = 1000
    health.current_health = 1000
    target.add_child(health)
    var deploy := DeployComponent.new()
    deploy.transfer_health_ratio = false

    var snap := {"health_ratio": 0.25, "was_selected": false, "player_id": 1}
    deploy._apply_snapshot(target, snap)

    (
        TestHelper
        . assert_true(
            health.current_health == 1000,
            (
                "apply_snapshot skips health when transfer_health_ratio is false: "
                + "health should remain 1000, got %d" % health.current_health
            ),
        )
    )

    target.free()


# --- Pending move target tests ---


func test_undeploy_stores_pending_move_target():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.undeploys_into = "GDI_MCV"
    entity.add_child(deploy)

    var target := Vector3(10.0, 0.0, 5.0)
    deploy.execute_undeploy(entity, target)

    (
        TestHelper
        . assert_true(
            deploy._has_pending_move and deploy._pending_move_target == target,
            (
                "execute_undeploy stores pending move target: "
                + "_has_pending_move should be true, _pending_move_target should match"
            ),
        )
    )

    deploy._state = DeployComponent.DeployState.IDLE
    entity.free()


func test_undeploy_no_pending_move_when_no_target():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.undeploys_into = "GDI_MCV"
    entity.add_child(deploy)

    deploy.execute_undeploy(entity)

    (
        TestHelper
        . assert_true(
            not deploy._has_pending_move,
            (
                "execute_undeploy without target does not set pending move: "
                + "_has_pending_move should be false when no target given"
            ),
        )
    )

    deploy._state = DeployComponent.DeployState.IDLE
    entity.free()


# --- get_order_for_target tests ---


func test_order_self_with_can_deploy():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.name = "DeployComponent"
    deploy.deploys_into = "GDI_CONSTRUCTION_YARD"
    entity.add_child(deploy)
    var order := deploy.get_order_for_target(entity, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order != null, "click self with can_deploy -> order not null")
    TestHelper.assert_eq(order.cursor, CursorState.Type.DEPLOY, "cursor -> DEPLOY")
    TestHelper.assert_eq(order.priority, 15, "priority -> 15")
    TestHelper.assert_true(order.execute.is_valid(), "has valid execute callable")
    entity.free()


func test_order_other_entity_returns_null():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.name = "DeployComponent"
    deploy.deploys_into = "GDI_CONSTRUCTION_YARD"
    entity.add_child(deploy)
    var other := Node3D.new()
    other.name = "Other"
    var order := deploy.get_order_for_target(other, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "click other entity -> null")
    entity.free()
    other.free()


func test_order_no_target_can_undeploy():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.name = "DeployComponent"
    deploy.undeploys_into = "GDI_MCV"
    entity.add_child(deploy)
    var order := deploy.get_order_for_target(null, Vector2i.ZERO, Vector3(5.0, 0.0, 10.0), {})
    TestHelper.assert_true(order != null, "no target + can_undeploy -> order not null")
    TestHelper.assert_eq(order.cursor, CursorState.Type.MOVE, "cursor -> MOVE")
    TestHelper.assert_eq(order.priority, 5, "priority -> 5")
    entity.free()


func test_order_no_target_cannot_undeploy():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.name = "DeployComponent"
    entity.add_child(deploy)
    var order := deploy.get_order_for_target(null, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "no target + cannot undeploy -> null")
    entity.free()


func test_order_self_cannot_deploy():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.name = "DeployComponent"
    entity.add_child(deploy)
    var order := deploy.get_order_for_target(entity, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "click self + cannot deploy -> null")
    entity.free()


func test_order_queued_modifier():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.name = "DeployComponent"
    deploy.deploys_into = "GDI_CONSTRUCTION_YARD"
    entity.add_child(deploy)
    var modifiers := {OrderResult.MOD_QUEUED: true}
    var order := deploy.get_order_for_target(entity, Vector2i.ZERO, Vector3.ZERO, modifiers)
    TestHelper.assert_true(order != null, "queued modifier -> order not null")
    TestHelper.assert_true(order.queued, "queued modifier -> order.queued = true")
    entity.free()


func test_order_undeploy_stores_target_pos():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.name = "DeployComponent"
    deploy.undeploys_into = "GDI_MCV"
    entity.add_child(deploy)
    var pos := Vector3(15.0, 0.0, 25.0)
    var order := deploy.get_order_for_target(null, Vector2i.ZERO, pos, {})
    TestHelper.assert_eq(order.target_pos, pos, "order stores target_pos")
    entity.free()
