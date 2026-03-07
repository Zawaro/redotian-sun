# Camera & Selection System - Redotian Sun

## Overview
The camera and selection system forms the foundation of RTS gameplay, enabling players to view, navigate, and control units on the battlefield. This system must replicate classic C&C controls while leveraging modern 3D rendering capabilities.

## Core Requirements

### 1. Camera Controls
| Input | Action |
|-------|--------|
| WASD / Arrow Keys | Pan camera in corresponding directions |
| Mouse Drag (right button) | Smooth camera panning with inertia |
| Scroll Wheel / +/- Keys | Zoom in/out with damping |
| Q/E Keys | Rotate camera view (optional 3D rotation) |
| R Key | Reset camera to default position |
| Shift + Drag | Fast pan acceleration |

### 2. Selection Mechanics
- **Box Selection**: Click-drag rectangle to select multiple units
- **Single Select**: Left-click on individual unit/building
- **Multi-Select with Shift**: Add/remove from current selection
- **Group Hotkeys**: 1-0 keys for saving/loading unit groups
- **Smart Centering**: Auto-center camera when selecting distant units

### 3. Visual Feedback
- Selection outline/glow around selected objects
- Highlight effect on hover over selectable entities
- Health bars above units/buildings (toggleable)
- Cursor changes based on context (move, attack, build)

## Technical Implementation

### Scene Structure
```
scenes/ui/
├── CameraRoot.tscn (Node3D)
│   ├── MainCamera (Camera3D + CameraController.gd)
scenes/maps/
└── MapBase01.tscn (Node3D)
    └── SelectionManager (Node + SelectionManager.gd @tool)
    └── MouseHandler.gd (@tool)
scripts/components/
└── SelectComponent.gd
```

### Key Scripts

#### CameraController.gd (scripts/ui/CameraController.gd)
- Orthographic projection with adjustable FOV/ortho size
- Input handling for pan, zoom, rotate operations
- Smooth interpolation using linear interpolation (lerp) or damping
- Boundary constraints to prevent camera from leaving playable area
- Zoom clamping: minimum 50 units, maximum 400 units
- Position interpolation with smoothing factor (0.1-0.3)
- Input event handling with deadzone for mouse panning
- State machine for camera modes

#### Bounds System
- World boundary detection via collision shapes
- Minimum zoom: see entire map or 25% of it
- Maximum zoom: detailed unit view (1-2 units visible)

#### SelectionManager.gd (scripts/core/SelectionManager.gd)
- Centralized selection state manager (@tool enabled)
- Track selected units via array: `selected_units: Array[SelectComponent]`
- Box selection with screen-space raycasting
- Group management with hotkey bindings (1-0 arrays)
- Event emission via signals for UI updates when selection changes
- Hover preview support without selection

#### MouseHandler.gd (scripts/ui/MouseHandler.gd, @tool enabled)
- Input handling for mouse clicks and drag operations
- Raycasting from screen positions to world coordinates
- Box selection visualization (semi-transparent quad mesh at ground level Y=0)
- Delegate state changes to SelectionManager singleton

### Raycasting & Selection Logic

#### MouseHandler.gd - Box Selection Flow:
```gdscript
func _input(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            # Start drag: record position, create box visual
            is_dragging = true
            drag_start_position = get_viewport().get_mouse_position()
            create_drag_box()
        
        else:
            # End drag: determine click vs drag
            var end_pos = get_viewport().get_mouse_position()
            if (end_pos - drag_start_position).length() < 5.0:
                # Single click: select unit at raycast position
                handle_single_click(drag_start_position)
            else:
                # Drag selection: box select all entities in range
                var shift_pressed = Input.is_key_pressed(KEY_SHIFT)
                selection_manager.select_in_box(drag_start_position, end_pos - drag_start_position, shift_pressed)
            
            remove_drag_box()
```

#### SelectionManager.gd - Box Selection Logic:
```gdscript
func select_in_box(box_position: Vector2, box_size: Vector2, shift_pressed: bool):
    var camera = get_node("../MouseHandler/camera_pivot/Camera3D")
    
    # Clear selection if not shift-pressing
    if not shift_pressed:
        for unit in selected_units:
            unit.set_is_selected(false)
        selected_units.clear()
    
    # Get all entities from group "game_entities"
    var all_entities = get_tree().get_nodes_in_group("game_entities")
    
    for entity in all_entities:
        if not entity.has_node("SelectComponent"):
            continue
        
        var select_component = entity.get_node("SelectComponent")
        
        # Project entity world position to screen space
        var entity_screen_pos = _project_to_screen(entity.global_position)
        
        # Check if inside selection box
        if is_point_in_box(entity_screen_pos, box_position, box_size):
            add_unit(select_component)

func _project_to_screen(world_pos: Vector3) -> Vector2:
    var viewport = get_viewport()
    var camera = viewport.get_camera_3d()
    return camera.project_position(world_pos)

func is_point_in_box(point: Vector2, box_pos: Vector2, box_size: Vector2) -> bool:
    var min_x = min(box_pos.x, box_pos.x + box_size.x)
    var max_x = max(box_pos.x, box_pos.x + box_size.x)
    var min_y = min(box_pos.y, box_pos.y + box_size.y)
    var max_y = max(box_pos.y, box_pos.y + box_size.y)
    
    return point.x >= min_x and point.x <= max_x and \
           point.y >= min_y and point.y <= max_y
```

#### Raycasting for Single Click:
```gdscript
func _get_entity_at_mouse(mouse_screen_pos: Vector2) -> SelectComponent:
    var camera = get_camera_3d()
    var from = camera.project_ray_origin(mouse_screen_pos)
    var to = from + (-camera.global_transform.basis.z.normalized()) * 5000.0
    
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1 << 15  # Layer 16 (SelectComponent layer)
    query.collide_with_areas = true
    
    var result = get_world_3d().direct_space_state.intersect_ray(query)
    
    if result:
        var current = result.collider
        while current and not current.has_method("set_is_selected"):
            current = current.get_parent()
        
        if current and current.has_method("set_is_selected"):
            return current as SelectComponent
    
    return null
```

#### Drag Box Visualization:
```gdscript
func create_drag_box():
    drag_box_mesh = MeshInstance3D.new()
    var quad_mesh = QuadMesh.new()
    quad_mesh.size = Vector2.ZERO
    drag_box_mesh.mesh = quad_mesh
    
    # Semi-transparent red material
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(1, 0, 0, 0.5)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    drag_box_mesh.material_override = material
    
    # Position at ground level (Y=0) using screen-to-world projection
    add_child(drag_box_mesh)

func update_drag_box(screen_center: Vector2):
    var quad_mesh = drag_box_mesh.mesh as QuadMesh
    if quad_mesh:
        quad_mesh.size = abs(box_size) * 2.0
    
    # Project center to world space, set Y=0
    drag_box_mesh.position = screen_to_world_position(camera, screen_center)
    drag_box_mesh.position.y = 0

func screen_to_world_position(camera: Camera3D, screen_pos: Vector2) -> Vector3:
    var ray_origin = camera.project_ray_origin(screen_pos)
    var ray_direction = camera.project_ray_normal(screen_pos).normalized()
    
    # Intersect with ground plane (Y=0)
    if abs(ray_direction.y) > 0.001:
        var t = -ray_origin.y / ray_direction.y
        return Vector3(
            ray_origin.x + ray_direction.x * t,
            0,
            ray_origin.z + ray_direction.z * t
        )
    
    return Vector3.ZERO
```

### Performance Considerations
- Box selection: Iterate only over entities in "game_entities" group (not all scene nodes)
- Raycasting per frame for hover preview is acceptable (single raycast)
- Reuse drag box mesh instance instead of creating new one each time
- Selection outlines: Use GPU instancing or shader-based glow effects

## Integration Points
- SelectComponent scene template in `scenes/components/SelectComponent.tscn` with:
  - Area3D (collision layer 16) for raycasting hits
  - Visual outline/highlight node
- Connect to UI system for health bars and selection panel updates via SelectionManager signals
- Link with minimap for highlighting selected units
- Coordinate with combat system for targeting feedback

## Future Enhancements
- Camera presets (zoom levels for different unit types)
- Dynamic camera shake on explosions/events
- Follow mode for specific units or buildings
- Replay system with smooth camera interpolation between frames
