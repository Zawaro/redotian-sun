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
CameraRoot.tscn (Node3D)
├── MainCamera (Camera3D + CameraController.gd)
├── SelectionSystem.gd (singleton)
└── SelectionHighlighters (instanced at runtime)
```

### Key Scripts

#### CameraController.gd
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

#### SelectionSystem.gd (Autoload Singleton)
- Track selected nodes via dictionary: `selected_units = {id: node}`
- Box selection raycasting from multiple corners
- Group management with hotkey bindings (1-0 arrays)
- Event emission for UI updates when selection changes

### Raycasting & Selection Logic
```gdscript
func _get_screen_points():
    # Get 4 camera screen corners for box selection
    return [
        get_viewport().get_mouse_position(),
        Vector2(0, 0),
        Vector2(get_viewport().size.x, 0),
        Vector2(get_viewport().size.x, get_viewport().size.y)
    ]

func _raycast_from_points(points):
    # Cast rays from screen points into world space
    # Collect all hits and filter for selectable entities
    pass
```

### Performance Considerations
- Batch raycasts when possible
- Cache selection highlight meshes (reusable instances)
- Limit selection highlight count to avoid draw call overhead
- Use GPU-based selection outlines where feasible

## Integration Points
- Connect to UI system for health bars and selection panel updates
- Link with minimap for highlighting selected units
- Coordinate with combat system for targeting feedback

## Future Enhancements
- Camera presets (zoom levels for different unit types)
- Dynamic camera shake on explosions/events
- Follow mode for specific units or buildings
- Replay system with smooth camera interpolation between frames
