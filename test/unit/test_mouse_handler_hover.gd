extends Node

# MouseHandler hover takeover: moving from a hovered selectable unit onto a
# resource interact hitbox must clear the unit's hover preview immediately.

const SELECT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/SelectComponent.tscn")
const HITBOX_SCENE: PackedScene = preload("res://scenes/components/HitboxComponent.tscn")

var _sm: Node = null


func _setup_world() -> Dictionary:
    var cc := CameraController.new()
    cc.name = "CameraController"
    var cam := Camera3D.new()
    cam.name = "Camera3D"
    cam.position = Vector3(0, 12, 14)
    cc.add_child(cam)
    _sm.add_child(cc)
    cam.look_at(Vector3.ZERO, Vector3.UP)

    var rules := GlobalRules.get_current()
    var saved_shroud: bool = rules.shroud_enabled
    var saved_fog: bool = rules.fog_of_war
    rules.shroud_enabled = false
    rules.fog_of_war = false
    return {
        "cam": cam,
        "cc": cc,
        "rules": rules,
        "saved_shroud": saved_shroud,
        "saved_fog": saved_fog,
    }


func _make_unit() -> Dictionary:
    var entity := Node3D.new()
    entity.name = "HoverUnit"
    entity.position = Vector3(0, 0.5, 0)
    var select_comp := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    select_comp.name = "SelectComponent"
    entity.add_child(select_comp)
    _sm.add_child(entity)
    return {"entity": entity, "select_comp": select_comp}


func _make_resource() -> Dictionary:
    var entity := Node3D.new()
    entity.name = "Tiberium"
    entity.position = Vector3(0, 0.5, 4)
    var rc := Node.new()
    rc.name = "ResourceComponent"
    entity.add_child(rc)
    var hitbox := HITBOX_SCENE.instantiate() as Area3D
    hitbox.collision_layer = 1 << 16
    entity.add_child(hitbox)
    _sm.add_child(entity)
    return {"entity": entity}


func test_unit_hover_preview_clears_on_resource_takeover() -> void:
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var setup := _setup_world()
    var cam := setup["cam"] as Camera3D
    var unit := _make_unit()
    var res := _make_resource()
    var sc := unit["select_comp"] as SelectComponent

    var mouse := MouseHandler.new()
    mouse.selection_manager = _sm
    mouse.camera_controller = setup["cc"]

    var unit_mouse_pos := cam.unproject_position((unit["entity"] as Node3D).global_position)
    mouse._handle_hover_preview(unit_mouse_pos)
    TestHelper.assert_true(
        sc.is_hovering, "hovering the unit sets its hover preview (setup branch reached)"
    )

    var res_mouse_pos := cam.unproject_position((res["entity"] as Node3D).global_position)
    mouse._handle_hover_preview(res_mouse_pos)
    TestHelper.assert_true(
        not sc.is_hovering, "moving onto a resource clears the unit's hover preview immediately"
    )
    (
        TestHelper
        . assert_true(
            _sm.hovered_entity == null,
            "SelectionManager drops the hovered unit when hover moves onto a resource",
        )
    )
    var same_node: bool = _sm.hovered_node == (res["entity"] as Node3D)
    (
        TestHelper
        . assert_true(
            same_node,
            "SelectionManager tracks the resource as the hovered node (tooltip target)",
        )
    )

    _sm.clear_hover_preview()
    _sm.deselect_all()
    unit["entity"].free()
    res["entity"].free()
    (setup["cc"] as Node).free()
    var rules := setup["rules"] as GlobalRules
    rules.shroud_enabled = setup["saved_shroud"]
    rules.fog_of_war = setup["saved_fog"]


func test_shroud_hover_detection_follows_rules() -> void:
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var setup := _setup_world()
    var cam := setup["cam"] as Camera3D
    var mouse := MouseHandler.new()
    mouse.selection_manager = _sm
    mouse.camera_controller = setup["cc"]
    var rules := setup["rules"] as GlobalRules

    rules.shroud_enabled = true
    (
        TestHelper
        . assert_true(
            mouse._is_hovering_shrouded(),
            "with shroud enabled, unrevealed ground under the cursor is reported shrouded",
        )
    )

    rules.shroud_enabled = false
    (
        TestHelper
        . assert_true(
            not mouse._is_hovering_shrouded(),
            "with shroud disabled, ground under the cursor is not reported shrouded",
        )
    )

    rules.shroud_enabled = setup["saved_shroud"]
    rules.fog_of_war = setup["saved_fog"]
    mouse.free()
    (setup["cc"] as Node).free()
