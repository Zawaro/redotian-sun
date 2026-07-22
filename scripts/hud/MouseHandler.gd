extends Control
class_name MouseHandler

@export var camera_controller: CameraController
@export var raycast_distance: float = 500.0
@export var selection_manager: SelectionManager

@onready var selection_rect: ReferenceRect = $SelectionRect

var MOUSE_DRAG_THRESHOLD := 5.0

# Drag state — stored across _process() frames instead of event callbacks.
var mouse_dragging := false
var drag_start_position := Vector2.ZERO
var active_rect: Rect2
var _last_hover_pos := Vector2.INF
var _hover_miss_count := 0
var _skip_release := false

# Cursor state
var _current_cursor: CursorState.Type = CursorState.Type.DEFAULT
var _hovered_entity: Node3D = null


func _ready():
    selection_rect.hide()

    # Debug logging for raycasting infrastructure
    if not camera_controller:
        printerr(
            (
                "[MouseHandler] WARNING: camera_controller export is null. "
                + "All mouse-based interactions (selection, movement) will fail silently."
            )
        )
    else:
        var cam3d = _get_camera_3d()
        if !cam3d:
            printerr("[MouseHandler] Camera3D not found under camera_controller path.")

    if selection_manager:
        print("SelectionManager found!")


# Poll input directly (like CameraController.gd) instead of using _input().
# This is required because Control nodes embedded under Node3D root don't receive
# _input() events without focus in Play Scene mode. The Input singleton polls OS-level state
# and works regardless of scene hierarchy or node focus chains.
func _process(_delta):
    if Engine.is_editor_hint():
        return

    var bm := get_node_or_null("/root/BuildingManager") as Node
    if bm and bm.is_build_mode:
        return
    if bm and bm.exiting_build_mode:
        bm.exiting_build_mode = false
        mouse_dragging = false
        _skip_release = true
        return

    if _skip_release:
        if Input.is_action_just_released("select_entity"):
            _skip_release = false
        return

    # Deploy hotkey (Ctrl+D)
    if Input.is_action_just_pressed("deploy"):
        if selection_manager:
            selection_manager.request_deploy()
        return

    # Skip input handling when hovering UI — but still update cursor below.
    var hovered := get_viewport().gui_get_hovered_control()
    var over_sidebar := _is_over_sidebar()

    if not over_sidebar and not (hovered and _is_inside_build_menu(hovered)):
        var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

        # Left mouse button just pressed — start drag tracking.
        if Input.is_action_just_pressed("select_entity"):
            mouse_dragging = true
            drag_start_position = get_viewport().get_mouse_position()
            selection_rect.hide()
            selection_rect.position = drag_start_position
            selection_rect.size = Vector2.ZERO

        # Left mouse button just released — resolve as box-select or single click.
        if Input.is_action_just_released("select_entity"):
            var threshold_exceeded: bool = selection_rect.size.x >= MOUSE_DRAG_THRESHOLD

            if mouse_dragging and threshold_exceeded:
                if not shift_pressed and selection_manager:
                    selection_manager.deselect_all()
                if active_rect.has_area():
                    _select_entities_2d_projected(active_rect)
            elif selection_manager:
                var mouse_pos := get_viewport().get_mouse_position()
                _handle_single_click(mouse_pos, shift_pressed)

            mouse_dragging = false
            selection_rect.hide()

        # Right mouse button is RESERVED for deselect/cancel only — never issue commands.
        if Input.is_action_just_released("deselect_entity"):
            var sidebar := _find_sidebar()
            if sidebar and (sidebar.is_sell_mode() or sidebar.is_repair_mode()):
                sidebar.exit_action_mode()
            elif selection_manager:
                selection_manager.deselect_all()

        # ESC key — exit sell/repair mode.
        if Input.is_key_pressed(KEY_ESCAPE):
            var sidebar := _find_sidebar()
            if sidebar and (sidebar.is_sell_mode() or sidebar.is_repair_mode()):
                sidebar.exit_action_mode()

        # Update drag rectangle while left mouse held and moving (polling).
        if mouse_dragging:
            var m_end := get_viewport().get_mouse_position()
            var diff: Vector2 = m_end - drag_start_position
            active_rect = Rect2(drag_start_position, diff).abs()
            var over_threshold := (
                active_rect.size.x >= MOUSE_DRAG_THRESHOLD
                or active_rect.size.y >= MOUSE_DRAG_THRESHOLD
            )
            if over_threshold:
                selection_rect.show()
                selection_rect.position = active_rect.position
                selection_rect.size = active_rect.size

        # Hover preview during mouse motion (when not dragging).
        if not mouse_dragging:
            var mouse_pos := get_viewport().get_mouse_position()
            if mouse_pos.distance_to(_last_hover_pos) > 2.0:
                _last_hover_pos = mouse_pos
                _handle_hover_preview(mouse_pos)

    # Update cursor every frame — runs even when over sidebar or middle-clicking.
    _update_cursor()


func _get_camera_3d() -> Camera3D:
    if camera_controller and camera_controller.has_node("Camera3D"):
        return camera_controller.get_node("Camera3D") as Camera3D

    # Debug logging for diagnosis of missing camera in raycasting flow
    printerr(
        (
            "[MouseHandler] _get_camera_3d() returned null — "
            + (
                "camera_controller is not set. "
                if !camera_controller
                else "camera_controller has no 'Camera3D' child node. "
            )
        )
    )
    return null


## Handle left-click raycast for entity select.
func _handle_single_click(mouse_pos: Vector2, shift_pressed: bool):
    var camera := _get_camera_3d()
    if not camera or not camera.is_current():
        return

    var from = camera.project_ray_origin(mouse_pos)
    var dir := camera.project_ray_normal(mouse_pos).normalized()
    var space_state = camera.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from, from + dir * raycast_distance)
    query.collide_with_areas = true

    # Pass 1: layer 16 — SelectComponent (units, buildings).
    query.collision_mask = 1 << 15
    var result := space_state.intersect_ray(query)
    if result.has("collider"):
        var collider := result.collider as Node
        # Sell/Repair mode — handle building action
        var sidebar := _find_sidebar()
        if sidebar:
            var entity := _find_entity_parent(collider)
            if entity and entity.get_node_or_null("FoundationComponent"):
                if sidebar.is_sell_mode():
                    var bm := get_node("/root/BuildingManager") as BuildingManager
                    if bm:
                        bm.sell_building(entity)
                    sidebar.exit_action_mode()
                    return
                elif sidebar.is_repair_mode():
                    var bm := get_node("/root/BuildingManager") as BuildingManager
                    if bm:
                        bm.repair_building(entity)
                    sidebar.exit_action_mode()
                    return
        if not shift_pressed and _try_interact(collider):
            return
        var select_comp := _find_select_component(collider)
        if select_comp and selection_manager:
            # If entity is already selected and deployable, deploy on click
            var already_selected := selection_manager.is_entity_selected(select_comp)
            if already_selected:
                var entity := _find_entity_parent(collider)
                if entity:
                    var deploy := entity.get_node_or_null("DeployComponent") as DeployComponent
                    if deploy and deploy.can_deploy():
                        deploy.execute_deploy(entity)
                    else:
                        selection_manager.select_entity(select_comp, shift_pressed)
                else:
                    selection_manager.select_entity(select_comp, shift_pressed)
            else:
                selection_manager.select_entity(select_comp, shift_pressed)
        return

    # Pass 2: layer 17 — interact hitboxes (tiberium, dock).
    query.collision_mask = 1 << 16
    result = space_state.intersect_ray(query)
    if result.has("collider"):
        _try_interact(result.collider as Node)
        return

    # No entity — movement command.
    var ground_pos := _get_ground_position_at_mouse()
    var has_selection := selection_manager and not selection_manager.selected_entities.is_empty()
    if ground_pos != Vector3.INF and has_selection:
        selection_manager.request_move(ground_pos)


## Try harvest/dock interaction on an entity. Returns true if interaction issued.
func _try_interact(collider: Node) -> bool:
    var entity := _find_entity_parent(collider)
    if not entity or not selection_manager or selection_manager.selected_entities.is_empty():
        return false
    if entity.get_node_or_null("ResourceComponent"):
        return selection_manager.request_harvest(entity)
    if entity.get_node_or_null("DockHostComponent"):
        return selection_manager.request_dock(entity)
    return false


## Box-select: select entities whose projection falls inside the drag rectangle.
func _select_entities_2d_projected(rect: Rect2):
    var camera := _get_camera_3d()
    for entity in get_tree().get_nodes_in_group("drag_selectable"):
        var select_component := entity.get_node_or_null("SelectComponent") as SelectComponent
        if not select_component:
            continue

        if rect.has_point(camera.unproject_position(select_component.global_position)):
            if not selection_manager.is_entity_selected(select_component):
                selection_manager.add_entity(select_component)


## Walk up the node tree to find a SelectComponent descendant.
func _find_select_component(node: Node) -> SelectComponent:
    while is_instance_valid(node):
        if node is SelectComponent:
            return node as SelectComponent
        node = node.get_parent()
    return null


## Walk up the node tree to find the entity root (first Node3D parent with components).
func _find_entity_parent(node: Node) -> Node3D:
    while is_instance_valid(node):
        if (
            node is Node3D
            and (
                node.get_node_or_null("ResourceComponent")
                or node.get_node_or_null("DockHostComponent")
                or node.get_node_or_null("SelectComponent")
            )
        ):
            return node as Node3D
        node = node.get_parent()
    return null


## Handle hover preview by raycasting at entities under the cursor.
func _handle_hover_preview(mouse_pos: Vector2) -> void:
    var camera := _get_camera_3d()
    if not camera:
        return

    var from = camera.project_ray_origin(mouse_pos)
    var dir := camera.project_ray_normal(mouse_pos).normalized()

    var space_state = camera.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(from, from + dir * raycast_distance)
    query.collide_with_areas = true

    # Pass 1: layer 16 — SelectComponent (units, buildings).
    query.collision_mask = 1 << 15
    var result = space_state.intersect_ray(query)

    if result.has("collider"):
        var collider := result.collider as Node
        var select_comp := _find_select_component(collider)
        if select_comp:
            _hover_miss_count = 0
            selection_manager.set_hover_preview(true, select_comp)
            _hovered_entity = _find_entity_parent(collider)
            return

    # Pass 2: layer 17 — interact hitboxes (tiberium, dock).
    query.collision_mask = 1 << 16
    result = space_state.intersect_ray(query)

    if result.has("collider"):
        var collider := result.collider as Node
        var entity := _find_entity_parent(collider)
        if entity:
            _hover_miss_count = 0
            _hovered_entity = entity
            return

    _hover_miss_count += 1
    if _hover_miss_count > 3:
        selection_manager.clear_hover_preview()
        _hover_miss_count = 0
        _hovered_entity = null


## Return where the camera ray through mouse cursor intersects terrain surface (iterative solve).
func _get_ground_position_at_mouse() -> Vector3:
    var camera := _get_camera_3d()
    if not camera:
        return Vector3.INF

    var mouse_pos := get_viewport().get_mouse_position() as Vector2
    var from = camera.project_ray_origin(mouse_pos)
    var dir := camera.project_ray_normal(mouse_pos).normalized()

    var ground_plane := Plane(Vector3.UP, 0.0) as Plane
    var intersection = ground_plane.intersects_ray(from, dir)

    if intersection == null:
        return Vector3.INF

    var hit_pos := intersection as Vector3
    for i in 4:
        var terrain_y := TerrainSystem.get_height_at_world_smooth(hit_pos)
        var adjusted := Plane(Vector3.UP, terrain_y)
        var new_hit = adjusted.intersects_ray(from, dir)
        if new_hit == null:
            break
        hit_pos = new_hit as Vector3

    var dist_sq: float = from.distance_squared_to(hit_pos)
    if 0.0 < dist_sq and dist_sq <= raycast_distance * raycast_distance:
        return hit_pos

    return Vector3.INF


func _is_inside_build_menu(node: Node) -> bool:
    while is_instance_valid(node):
        if node.name == "Sidebar":
            return true
        node = node.get_parent()
    return false


func _find_sidebar() -> Node:
    var root := get_tree().current_scene
    if not root:
        return null
    return _find_sidebar_recursive(root)


func _find_sidebar_recursive(node: Node) -> Node:
    if node.name == "Sidebar" and node is Control:
        return node
    for child in node.get_children():
        var result := _find_sidebar_recursive(child)
        if result:
            return result
    return null


func _is_over_sidebar() -> bool:
    var sidebar := _find_sidebar()
    return sidebar and sidebar.get_global_rect().has_point(get_viewport().get_mouse_position())


func _update_cursor() -> void:
    var cursor_type: CursorState.Type

    # Sidebar hover always shows system cursor
    var sidebar := _find_sidebar()
    if sidebar and sidebar.get_global_rect().has_point(get_viewport().get_mouse_position()):
        cursor_type = CursorState.Type.DEFAULT
    elif mouse_dragging and active_rect.size.x >= MOUSE_DRAG_THRESHOLD:
        cursor_type = CursorState.Type.SELECT
    else:
        # Middle-click panning — joystick cursor
        var joystick := _resolve_joystick_cursor()
        if joystick != CursorState.Type.DEFAULT:
            cursor_type = joystick
        # Edge scroll cursor
        elif _resolve_scroll_cursor() != CursorState.Type.DEFAULT:
            cursor_type = _resolve_scroll_cursor()
        # Sell mode — always show SELL or SELL_BLOCKED
        elif sidebar and sidebar.is_sell_mode():
            if _hovered_entity and _hovered_entity.get_node_or_null("FoundationComponent"):
                cursor_type = CursorState.Type.SELL
            else:
                cursor_type = CursorState.Type.SELL_BLOCKED
        # Repair mode — always show REPAIR or REPAIR_BLOCKED
        elif sidebar and sidebar.is_repair_mode():
            if _hovered_entity and _hovered_entity.get_node_or_null("FoundationComponent"):
                cursor_type = CursorState.Type.REPAIR
            else:
                cursor_type = CursorState.Type.REPAIR_BLOCKED
        else:
            cursor_type = _resolve_cursor_for_selection()

    _apply_cursor(cursor_type)


func _resolve_cursor_for_selection() -> CursorState.Type:
    if not selection_manager or selection_manager.selected_entities.is_empty():
        return _resolve_scroll_cursor()

    var target := _hovered_entity
    var target_cell := Vector2i.ZERO
    if target:
        target_cell = Pathfinder.world_to_cell(target.global_position)

    var best_cursor: CursorState.Type = CursorState.Type.DEFAULT
    var best_priority: int = -1

    for select_comp in selection_manager.selected_entities:
        if not is_instance_valid(select_comp):
            continue
        if not selection_manager._is_local_entity(select_comp):
            continue
        var entity := select_comp.get_parent() as Node3D
        if not entity:
            continue
        for component in entity.get_children():
            if component.has_method("get_cursor_for_target"):
                if not is_instance_valid(target):
                    target = null
                var cursor: CursorState.Type = component.get_cursor_for_target(target, target_cell)
                var priority: int = CursorState.get_priority(cursor)
                if priority > best_priority:
                    best_priority = priority
                    best_cursor = cursor

    if best_cursor != CursorState.Type.DEFAULT:
        return best_cursor
    return CursorState.Type.DEFAULT


func _resolve_scroll_cursor() -> CursorState.Type:
    var mouse_pos := get_viewport().get_mouse_position()
    var viewport_size := get_viewport().get_visible_rect().size
    var margin := 20.0

    var dx := 0
    var dy := 0

    if mouse_pos.x < margin:
        dx = -1
    elif mouse_pos.x > viewport_size.x - margin:
        dx = 1

    if mouse_pos.y < margin:
        dy = -1
    elif mouse_pos.y > viewport_size.y - margin:
        dy = 1

    if dx == 0 and dy == 0:
        return CursorState.Type.DEFAULT

    var direction := Vector2i(dx, dy)
    var blocked := _is_scroll_blocked(direction)

    var cursor_map := {
        Vector2i(0, -1): [CursorState.Type.SCROLL_T, CursorState.Type.SCROLL_T_BLOCKED],
        Vector2i(1, -1): [CursorState.Type.SCROLL_TR, CursorState.Type.SCROLL_TR_BLOCKED],
        Vector2i(1, 0): [CursorState.Type.SCROLL_R, CursorState.Type.SCROLL_R_BLOCKED],
        Vector2i(1, 1): [CursorState.Type.SCROLL_BR, CursorState.Type.SCROLL_BR_BLOCKED],
        Vector2i(0, 1): [CursorState.Type.SCROLL_B, CursorState.Type.SCROLL_B_BLOCKED],
        Vector2i(-1, 1): [CursorState.Type.SCROLL_BL, CursorState.Type.SCROLL_BL_BLOCKED],
        Vector2i(-1, 0): [CursorState.Type.SCROLL_L, CursorState.Type.SCROLL_L_BLOCKED],
        Vector2i(-1, -1): [CursorState.Type.SCROLL_TL, CursorState.Type.SCROLL_TL_BLOCKED],
    }

    var default_pair: Array = [CursorState.Type.DEFAULT, CursorState.Type.DEFAULT]
    var pair: Array = cursor_map.get(direction, default_pair)
    return pair[1] if blocked else pair[0]


func _is_scroll_blocked(direction: Vector2i) -> bool:
    if not camera_controller or not camera_controller.bounds_system:
        return true
    var bounds_rect := camera_controller.bounds_system.get_bounds_rect()
    var cam_pos := camera_controller.global_position

    var rotated_pos := cam_pos.rotated(Vector3(0, 1, 0), -deg_to_rad(45))
    var half_width := bounds_rect.size.x / 2.0
    var half_height := bounds_rect.size.y / 2.0

    if direction.x == -1 and rotated_pos.x <= -half_width + 1.0:
        return true
    if direction.x == 1 and rotated_pos.x >= half_width - 1.0:
        return true
    if direction.y == -1 and rotated_pos.z <= -half_height + 1.0:
        return true
    if direction.y == 1 and rotated_pos.z >= half_height - 1.0:
        return true

    return false


func _resolve_joystick_cursor() -> CursorState.Type:
    if not camera_controller or not camera_controller.is_panning:
        return CursorState.Type.DEFAULT

    var mouse_pos := get_viewport().get_mouse_position()
    var click_pos: Vector2 = camera_controller.fixed_toggle_point
    var diff := mouse_pos - click_pos

    # Within 20px of click point — center (no pan direction yet)
    if diff.length() < 20.0:
        return CursorState.Type.JOYSTICK_CENTER

    # Map angle to 8 directions
    var angle := diff.angle()  # 0 = right, PI/2 = down, PI = left, -PI/2 = up
    var sector := wrapi(floori((angle + PI) / (PI / 4.0)), 0, 7)

    var direction_map := {
        0: Vector2i(-1, 0),  # left
        1: Vector2i(-1, -1),  # up-left
        2: Vector2i(0, -1),  # up
        3: Vector2i(1, -1),  # up-right
        4: Vector2i(1, 0),  # right
        5: Vector2i(1, 1),  # down-right
        6: Vector2i(0, 1),  # down
        7: Vector2i(-1, 1),  # down-left
    }

    var direction: Vector2i = direction_map.get(sector, Vector2i.ZERO)
    var blocked := _is_scroll_blocked(direction)

    var cursor_map := {
        Vector2i(0, -1): [CursorState.Type.JOYSTICK_T, CursorState.Type.JOYSTICK_T_BLOCKED],
        Vector2i(1, -1): [CursorState.Type.JOYSTICK_TR, CursorState.Type.JOYSTICK_TR_BLOCKED],
        Vector2i(1, 0): [CursorState.Type.JOYSTICK_R, CursorState.Type.JOYSTICK_R_BLOCKED],
        Vector2i(1, 1): [CursorState.Type.JOYSTICK_BR, CursorState.Type.JOYSTICK_BR_BLOCKED],
        Vector2i(0, 1): [CursorState.Type.JOYSTICK_B, CursorState.Type.JOYSTICK_B_BLOCKED],
        Vector2i(-1, 1): [CursorState.Type.JOYSTICK_BL, CursorState.Type.JOYSTICK_BL_BLOCKED],
        Vector2i(-1, 0): [CursorState.Type.JOYSTICK_L, CursorState.Type.JOYSTICK_L_BLOCKED],
        Vector2i(-1, -1): [CursorState.Type.JOYSTICK_TL, CursorState.Type.JOYSTICK_TL_BLOCKED],
    }

    var default_pair: Array = [
        CursorState.Type.JOYSTICK_CENTER,
        CursorState.Type.JOYSTICK_CENTER,
    ]
    var pair: Array = cursor_map.get(direction, default_pair)
    return pair[1] if blocked else pair[0]


func _apply_cursor(type: CursorState.Type) -> void:
    if type == _current_cursor:
        return
    _current_cursor = type

    if type == CursorState.Type.DEFAULT:
        Input.set_custom_mouse_cursor(null)
        return

    var texture := CursorState.get_texture(type)
    var hotspot := CursorState.get_hotspot(type)
    Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)
