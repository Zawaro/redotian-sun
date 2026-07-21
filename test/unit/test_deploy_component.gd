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
