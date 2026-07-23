extends Node

# DeployComponent tests — component configuration, snapshot, and deploy/undeploy logic

const DEPLOY_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/DeployComponent.gd")

var _sm: Node = null
var _bm: Node = null
var _pm: Node = null
var _test_passed := 0
var _test_failed := 0


func test_deploy_component_defaults():
    var entity := Node3D.new()
    var component := Node.new()
    component.name = "DeployComponent"
    component.set_script(DEPLOY_COMPONENT_SCRIPT)
    entity.add_child(component)

    var deploy := component as DeployComponent
    if deploy.deploys_into == "" and deploy.undeploys_into == "":
        _test_passed += 1
        print("    PASS: DeployComponent defaults are empty strings")
    else:
        _test_failed += 1
        print("    FAIL: DeployComponent defaults should be empty")

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

    if deploy.deploys_into == "GDI_CONSTRUCTION_YARD":
        _test_passed += 1
        print("    PASS: DeployComponent.configure sets deploys_into")
    else:
        _test_failed += 1
        print("    FAIL: Expected deploys_into='GACNST', got '%s'" % deploy.deploys_into)

    entity.free()


func test_can_deploy():
    var entity := Node3D.new()
    var component := Node.new()
    component.name = "DeployComponent"
    component.set_script(DEPLOY_COMPONENT_SCRIPT)
    entity.add_child(component)

    var deploy := component as DeployComponent
    deploy.deploys_into = "GDI_CONSTRUCTION_YARD"

    if deploy.can_deploy() and not deploy.can_undeploy():
        _test_passed += 1
        print("    PASS: can_deploy() returns true when deploys_into set")
    else:
        _test_failed += 1
        print("    FAIL: can_deploy() should be true, can_undeploy() false")

    entity.free()


func test_can_undeploy():
    var entity := Node3D.new()
    var component := Node.new()
    component.name = "DeployComponent"
    component.set_script(DEPLOY_COMPONENT_SCRIPT)
    entity.add_child(component)

    var deploy := component as DeployComponent
    deploy.undeploys_into = "GDI_MCV"

    if deploy.can_undeploy() and not deploy.can_deploy():
        _test_passed += 1
        print("    PASS: can_undeploy() returns true when undeploys_into set")
    else:
        _test_failed += 1
        print("    FAIL: can_undeploy() should be true, can_deploy() false")

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

    if not select_component.is_selected and not select_component.is_hovering:
        _test_passed += 1
        print("    PASS: deselect_entity clears both is_selected and is_hovering")
    else:
        _test_failed += 1
        print("    FAIL: deselect_entity should clear both flags")

    entity.free()


func test_deselect_entity_noops_without_select_component():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()

    deploy._deselect_entity(entity)

    _test_passed += 1
    print("    PASS: deselect_entity does not crash without SelectComponent")

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

    if abs(snap["health_ratio"] - 0.5) < 0.001:
        _test_passed += 1
        print("    PASS: snapshot captures health_ratio = 0.5")
    else:
        _test_failed += 1
        print("    FAIL: Expected health_ratio 0.5, got %s" % snap["health_ratio"])

    entity.free()


func test_snapshot_defaults_health_to_one_when_no_component():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()

    var snap := deploy._snapshot_entity(entity)

    if abs(snap["health_ratio"] - 1.0) < 0.001:
        _test_passed += 1
        print("    PASS: snapshot defaults health_ratio to 1.0 without HealthComponent")
    else:
        _test_failed += 1
        print("    FAIL: Expected default health_ratio 1.0, got %s" % snap["health_ratio"])

    entity.free()


func test_snapshot_captures_player_id():
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = 3
    entity.add_child(stats)
    var deploy := DeployComponent.new()

    var snap := deploy._snapshot_entity(entity)

    if snap["player_id"] == 3:
        _test_passed += 1
        print("    PASS: snapshot captures player_id = 3")
    else:
        _test_failed += 1
        print("    FAIL: Expected player_id 3, got %s" % snap["player_id"])

    entity.free()


func test_snapshot_captures_selection():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
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

    if snap["was_selected"] == true:
        _test_passed += 1
        print("    PASS: snapshot captures was_selected = true")
    else:
        _test_failed += 1
        print("    FAIL: Expected was_selected true, got %s" % snap["was_selected"])

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

    if health.current_health == 500:
        _test_passed += 1
        print("    PASS: apply_snapshot sets health to 500 (50%% of 1000)")
    else:
        _test_failed += 1
        print("    FAIL: Expected current_health 500, got %d" % health.current_health)

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

    if stats.player_id == 2:
        _test_passed += 1
        print("    PASS: apply_snapshot sets player_id = 2")
    else:
        _test_failed += 1
        print("    FAIL: Expected player_id 2, got %d" % stats.player_id)

    target.free()


func test_apply_snapshot_restores_selection():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
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

    if _sm.selected_entities.has(select_component) and select_component.is_selected:
        _test_passed += 1
        print("    PASS: apply_snapshot restores selection on target")
    else:
        _test_failed += 1
        print("    FAIL: apply_snapshot should add target SelectComponent to SelectionManager")

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

    if health.current_health == 1000:
        _test_passed += 1
        print("    PASS: apply_snapshot skips health when transfer_health_ratio is false")
    else:
        _test_failed += 1
        var msg := "health should remain 1000, got %d" % health.current_health
        print("    FAIL: %s" % msg)

    target.free()


# --- Pending move target tests ---


func test_undeploy_stores_pending_move_target():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.undeploys_into = "GDI_MCV"
    entity.add_child(deploy)

    var target := Vector3(10.0, 0.0, 5.0)
    deploy.execute_undeploy(entity, target)

    if deploy._has_pending_move and deploy._pending_move_target == target:
        _test_passed += 1
        print("    PASS: execute_undeploy stores pending move target")
    else:
        _test_failed += 1
        print("    FAIL: _has_pending_move should be true, _pending_move_target should match")

    deploy._state = DeployComponent.DeployState.IDLE
    entity.free()


func test_undeploy_no_pending_move_when_no_target():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.undeploys_into = "GDI_MCV"
    entity.add_child(deploy)

    deploy.execute_undeploy(entity)

    if not deploy._has_pending_move:
        _test_passed += 1
        print("    PASS: execute_undeploy without target does not set pending move")
    else:
        _test_failed += 1
        print("    FAIL: _has_pending_move should be false when no target given")

    deploy._state = DeployComponent.DeployState.IDLE
    entity.free()


func test_move_cursor_for_undeployable_entity():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.undeploys_into = "GDI_MCV"
    entity.add_child(deploy)

    var cursor := deploy.get_cursor_for_target(null, Vector2i.ZERO)

    if cursor == CursorState.Type.MOVE:
        _test_passed += 1
        print("    PASS: get_cursor_for_target returns MOVE for undeployable entity")
    else:
        _test_failed += 1
        print("    FAIL: Expected MOVE cursor, got %s" % cursor)

    entity.free()


func test_deploy_cursor_for_deployable_entity():
    var entity := Node3D.new()
    var deploy := DeployComponent.new()
    deploy.deploys_into = "GDI_CONSTRUCTION_YARD"
    entity.add_child(deploy)

    var cursor := deploy.get_cursor_for_target(entity, Vector2i.ZERO)

    if cursor == CursorState.Type.DEPLOY:
        _test_passed += 1
        print("    PASS: get_cursor_for_target returns DEPLOY for deployable entity")
    else:
        _test_failed += 1
        print("    FAIL: Expected DEPLOY cursor, got %s" % cursor)

    entity.free()
