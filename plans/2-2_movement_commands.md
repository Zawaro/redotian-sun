# Unit Movement & Commands System - Redotian Sun

## Overview
The movement system handles all unit navigation and command execution, translating player inputs into in-game actions. This includes basic movement, attack orders, patrol routes, and formation management.

## Core Requirements

### 1. Command Types
| Command | Input | Behavior |
|---------|-------|----------|
| Move | Right-click → destination | Pathfind to location, stop when arrived |
| Attack | Right-click on enemy unit/structure | Move to target and engage in combat |
| Attack-Move | Shift+Right-click area | Move through area while attacking enemies within radius |
| Patrol | Double-right-click or patrol button | Cycle between waypoints indefinitely |
| Gather | Right-click resource node | Navigate to resource, collect, return to base |
| Formation | Formation menu + position | Maintain specific formation during movement |

### 2. Path Following Execution
- Follow calculated path from NavMesh system
- Real-time obstacle avoidance steering
- Speed adjustment based on terrain and unit state
- Stop/restart functionality with smooth transitions

### 3. Attack-Move Logic
- Combine movement path with combat radius checks
- Engage enemies encountered along route automatically
- Priority: destroy threats before continuing path
- Fallback to simple move if no enemies detected

### 4. Formation System
| Formation | Use Case | Behavior |
|-----------|----------|----------|
| Line | Anti-infantry spread | Units in horizontal line, even spacing |
| Column | Fast movement through narrow terrain | Single file, faster travel |
| Wedge | Combat advance | V-shape with leader at front |
| Diamond | Balanced defense | Central unit protected by surrounding units |
| Scatter | Area coverage | Max separation for resource gathering |

## Technical Implementation

### Scene Structure
```
UnitController.tscn (Node3D)
├── MovementComponent.gd (path following logic)
├── CommandHandler.gd (input processing)
└── FormationManager.gd (group coordination)
```

### Key Scripts

#### MovementComponent.gd
- Path traversal with velocity-based interpolation
- Obstacle avoidance using steering behaviors (separation, alignment)
- Terrain cost application to movement speed
- State machine: idle → moving → attacking → gathering → fleeing

#### CommandHandler.gd
- Parse player input into command structures
- Validate commands against unit capabilities
- Queue multiple commands for execution
- Emit events when commands complete or fail

### Path Following Algorithm
```gdscript
func follow_path(target_path):
    if target_path.is_empty():
        state = "idle"
        return
    
    var next_waypoint = target_path[0]
    var direction = (next_waypoint.position - global_position).normalized()
    
    # Apply terrain speed modifier
    var current_speed = base_speed * get_terrain_modifier(global_position)
    
    # Move toward waypoint with smoothing
    global_position += direction * current_speed * delta
    
    # Check if arrived at waypoint
    if global_position.distance_to(next_waypoint.position) < arrival_threshold:
        target_path.remove_at(0)
        
        if target_path.is_empty():
            state = "idle"

# Obstacle avoidance (separation steering)
func avoid_obstacles(obstacles):
    var separation_force = Vector3.ZERO
    
    for obstacle in obstacles:
        var distance = global_position.distance_to(obstacle.position)
        if distance < avoidance_radius:
            separation_force += (global_position - obstacle.position).normalized() / distance
    
    return separation_force.normalized() * force_multiplier
```

### Formation Management
- Calculate formation offsets relative to leader unit
- Each unit maintains offset while following leader's path
- Dynamic reformation when terrain constraints prevent ideal spacing
- Break formation on attack-move commands (spread for combat)

## Integration Points
- Connect to navigation system for path calculation requests
- Link with combat system for attack-move integration
- Coordinate with selection system for group command handling
- Interface with minimap for movement preview visuals

## Future Enhancements
- Advanced formation morphing (smooth transitions between shapes)
- Terrain-aware formations (adapt to narrow passages automatically)
- Command queuing UI with drag-drop reordering
- Formation presets saved per faction/unit type
