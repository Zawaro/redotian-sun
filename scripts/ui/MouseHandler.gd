extends Node3D
class_name MouseHandler

@export var camera_pivot: CameraPivot
@export var raycast_distance: float = 500.0
var selection_manager: SelectionManager = null

func _ready():
    if has_node("../SelectionManager"):
        selection_manager = get_node("../SelectionManager")
        print("✅ SelectionManager found!")
    else:
        push_error("❌ SelectionManager not found — please add it as a sibling")

func get_camera_3d() -> Camera3D:
    if camera_pivot and camera_pivot.has_node("Camera3D"):
        return camera_pivot.get_node("Camera3D") as Camera3D
    return null

func handle_left_click_selection():
    var camera = get_camera_3d()
    if not camera or not camera.is_current():
        push_error("❌ No active Camera3D")
        return

    var mouse_pos = get_viewport().get_mouse_position()
    print("🖱️ Mouse screen pos: ", mouse_pos)
    print("📷 Camera pos: ", camera.global_position)

    var from = camera.project_ray_origin(mouse_pos)
    var dir = -camera.global_transform.basis.z.normalized()  # your working forward

    from += dir * 0.1
    var to = from + dir * 5000.0

    # 🆕 GROUND HIT CALC (no physics needed)
    var ground_pos = Vector3.ZERO
    if abs(dir.y) > 0.001:
        var t = -from.y / dir.y
        if t > 0:
            ground_pos = from + t * dir
            print("🎯 Would hit Y=0 at XZ: ", Vector2(ground_pos.x, ground_pos.z))

    var space_state = get_world_3d().direct_space_state
    print("🌍 SpaceState valid: ", space_state != null)

    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 0xFFFFFFFF
    query.collide_with_areas = true

    var result = space_state.intersect_ray(query)

    if result:
        print("✅ HIT → ", result.collider.name, " at ", result.position)
        # selection...
    else:
        print("❌ MISS — check colliders at ground_pos above!")

func _process(_delta):
    if Input.is_action_just_pressed("select_unit"):
        handle_left_click_selection()

func _find_select_component_in_parent_chain(node):
    if node == null:
        return null
    if node.has_method("set_is_selected"):
        return node
    while node:
        for child in node.get_children():
            var found = _find_select_component_in_parent_chain(child)
            if found:
                return found
        node = node.get_parent()
    return null
