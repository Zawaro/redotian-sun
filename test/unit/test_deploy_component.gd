extends Node

# DeployComponent tests — component configuration and deploy/undeploy logic

const DEPLOY_COMPONENT_SCRIPT: GDScript = preload("res://scripts/components/DeployComponent.gd")

var _sm: Node = null
var _bm: Node = null
var _pm: Node = null
var _test_passed := 0
var _test_failed := 0


func test_deploy_component_defaults():
    var data := EntityData.new()
    data.id = "TEST_MCV"
    data.entity_type = EntityData.EntityType.VEHICLE
    data.strength = 1000
    data.owner = PackedStringArray(["GDI"])

    var entity := Node3D.new()
    entity.name = "TestMCV"
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
    data.deploys_into = "GACNST"

    var entity := Node3D.new()
    entity.name = "TestMCV"
    var component := Node.new()
    component.name = "DeployComponent"
    component.set_script(DEPLOY_COMPONENT_SCRIPT)
    entity.add_child(component)

    var deploy := component as DeployComponent
    deploy.configure(data)

    if deploy.deploys_into == "GACNST":
        _test_passed += 1
        print("    PASS: DeployComponent.configure sets deploys_into")
    else:
        _test_failed += 1
        print("    FAIL: Expected deploys_into='GACNST', got '%s'" % deploy.deploys_into)

    entity.free()


func test_can_deploy():
    var entity := Node3D.new()
    entity.name = "TestMCV"
    var component := Node.new()
    component.name = "DeployComponent"
    component.set_script(DEPLOY_COMPONENT_SCRIPT)
    entity.add_child(component)

    var deploy := component as DeployComponent
    deploy.deploys_into = "GACNST"

    if deploy.can_deploy() and not deploy.can_undeploy():
        _test_passed += 1
        print("    PASS: can_deploy() returns true when deploys_into set")
    else:
        _test_failed += 1
        print("    FAIL: can_deploy() should be true, can_undeploy() false")

    entity.free()


func test_can_undeploy():
    var entity := Node3D.new()
    entity.name = "TestConYard"
    var component := Node.new()
    component.name = "DeployComponent"
    component.set_script(DEPLOY_COMPONENT_SCRIPT)
    entity.add_child(component)

    var deploy := component as DeployComponent
    deploy.undeploys_into = "MCV"

    if deploy.can_undeploy() and not deploy.can_deploy():
        _test_passed += 1
        print("    PASS: can_undeploy() returns true when undeploys_into set")
    else:
        _test_failed += 1
        print("    FAIL: can_undeploy() should be true, can_deploy() false")

    entity.free()


func test_deploy_records_selected_source_for_transition():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return

    var entity := Node3D.new()
    var select_component := SelectComponent.new()
    select_component.name = "SelectComponent"
    entity.add_child(select_component)
    var deploy := DeployComponent.new()
    entity.add_child(deploy)

    _sm.add_entity(select_component)
    deploy._capture_selection(entity)
    _sm.deselect_all()

    if deploy._retain_selection:
        _test_passed += 1
        print("    PASS: deploy retains selection recorded at transition start")
    else:
        _test_failed += 1
        print("    FAIL: deploy should retain selection recorded at transition start")

    entity.free()


func test_deploy_does_not_record_unselected_source():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return

    var entity := Node3D.new()
    var select_component := SelectComponent.new()
    select_component.name = "SelectComponent"
    entity.add_child(select_component)
    var deploy := DeployComponent.new()
    entity.add_child(deploy)

    deploy._capture_selection(entity)

    if not deploy._retain_selection:
        _test_passed += 1
        print("    PASS: deploy does not retain an unselected source")
    else:
        _test_failed += 1
        print("    FAIL: deploy should not retain an unselected source")

    entity.free()


func test_deploy_records_visually_selected_source_for_transition():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return

    _sm.deselect_all()
    var entity := Node3D.new()
    var select_component := SelectComponent.new()
    select_component.name = "SelectComponent"
    select_component.set_is_selected(true)
    entity.add_child(select_component)
    var deploy := DeployComponent.new()
    entity.add_child(deploy)

    deploy._capture_selection(entity)

    if deploy._retain_selection:
        _test_passed += 1
        print("    PASS: deploy retains a visually selected source")
    else:
        _test_failed += 1
        print("    FAIL: deploy should retain a visually selected source")

    entity.free()


func test_transfer_selection_clears_source_when_target_has_no_select_component():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return

    _sm.deselect_all()
    var source := Node3D.new()
    var source_select := SelectComponent.new()
    source_select.name = "SelectComponent"
    source.add_child(source_select)
    var target := Node3D.new()
    var deploy := DeployComponent.new()

    _sm.add_entity(source_select)
    deploy._transfer_selection(source, target)

    if _sm.selected_entities.is_empty() and not source_select.is_selected:
        _test_passed += 1
        print("    PASS: selection transfer clears source without a target selection component")
    else:
        _test_failed += 1
        print(
            "    FAIL: selection transfer should clear source without a target selection component"
        )

    source.free()
    target.free()


func test_deselect_entity_clears_unmanaged_selection_visual():
    var entity := Node3D.new()
    var select_component := SelectComponent.new()
    select_component.name = "SelectComponent"
    select_component.set_is_selected(true)
    entity.add_child(select_component)
    var deploy := DeployComponent.new()

    deploy._deselect_entity(entity)

    if not select_component.is_selected:
        _test_passed += 1
        print("    PASS: deselect_entity clears unmanaged selection visual")
    else:
        _test_failed += 1
        print("    FAIL: deselect_entity should clear unmanaged selection visual")

    entity.free()


func test_complete_deploy_transfers_selection_to_result_entity():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return

    _sm.deselect_all()
    var source := EntityFactory.create_entity("MCV")
    if source == null:
        _test_failed += 1
        print("    FAIL: EntityFactory could not create MCV")
        return
    _sm.add_child(source)
    var source_select := source.get_node_or_null("SelectComponent") as SelectComponent
    var deploy := source.get_node_or_null("DeployComponent") as DeployComponent
    if source_select == null or deploy == null:
        _test_failed += 1
        print("    FAIL: MCV is missing selection or deploy components")
        source.free()
        return

    _sm.add_entity(source_select)
    deploy._retain_selection = true
    deploy._complete_deploy(source)

    var selected: Array[SelectComponent] = _sm.selected_entities
    var target_select: SelectComponent = null
    if selected.size() == 1:
        target_select = selected[0]
    var target: Node3D = target_select.get_parent() as Node3D if target_select else null
    if target and target.get_node_or_null("DeployComponent") and target != source:
        _test_passed += 1
        print("    PASS: complete deploy transfers functional selection to result entity")
        target.free()
    else:
        _test_failed += 1
        print("    FAIL: complete deploy should select the result entity")

    _sm.deselect_all()
    if is_instance_valid(source):
        source.free()
