# Navigation & Pathfinding System - Redotian Sun

## Overview
The navigation system provides pathfinding capabilities for all moving entities, enabling units to traverse terrain efficiently while avoiding obstacles and respecting movement constraints.

## Core Requirements

### 1. Pathfinding Approach Selection
- **Algorithm**: A* (A-Star) with navmesh or grid-based approach
- **Grid Resolution**: 0.5m cells for precision, optimized for performance
- **Dynamic Updates**: Real-time obstacle avoidance during path execution
- **Multi-layer Navigation**: Different movement types use separate nav layers

### 2. Terrain Cost Modifiers
| Terrain Type | Movement Cost | Notes |
|--------------|---------------|-------|
| Flat Ground | 1.0x | Standard speed |
| Hills/Slopes | 1.5x | Reduced unit speed |
| Water/Shallow | 2.0x | Naval units only |
| Deep Water | ∞ (blocked) | Untaversable |
| Tiberium Fields | 1.2x | Toxicity penalty over time |
| Road Networks | 0.7x | Speed bonus for vehicles |

### 3. Dynamic Obstacle Avoidance
- Units act as moving obstacles to each other
- Path recalculates when blocked mid-navigation
- Separation forces prevent unit clustering
- Emergency stop on imminent collision detection

### 4. Path Smoothing
- Raw path points smoothed for natural movement curves
- Bezier interpolation between waypoints
- Unit-specific turning radii (tanks vs infantry)
- Speed-based waypoint skipping at high velocities

## Technical Implementation

### Scene Structure
```
NavigationRoot.tscn (Node3D)
├── NavMeshManager.gd (singleton)
├── PathFinder.gd (A* algorithm implementation)
└── ObstacleAvoidance.gd (steering behavior)
```

### Key Scripts

#### NavMeshManager.gd (Singleton)
- Manages navmesh generation from terrain data
- Handles multiple navigation layers per faction/terrain type
- Caches path queries for performance optimization
- Updates on map changes or new obstacles

#### PathFinder.gd
- A* implementation with heuristic function
- Node expansion based on movement costs
- Path reconstruction from parent pointers
- Fallback to fallback paths when primary blocked

### Navmesh Generation Algorithm
```gdscript
func generate_navmesh_from_terrain(terrain_data):
    var nav_nodes = []
    
    for tile in terrain_data.tiles:
        if is_walkable(tile.terrain_type, unit_type):
            # Create navigation node at tile center
            var node = NavMeshNode.new()
            node.position = tile.center
            node.cost_modifier = get_movement_cost(tile.terrain_type)
            
            # Connect to adjacent walkable tiles
            for neighbor in tile.get_neighbors():
                if is_walkable(neighbor.terrain_type, unit_type):
                    node.add_connection(neighbor, calculate_distance(node, neighbor))
            
            nav_nodes.append(node)
    
    return build_graph(nav_nodes)
```

### Path Smoothing Implementation
- Apply Catmull-Rom or Bezier curves to raw waypoints
- Skip intermediate points at high speeds (optimize path length)
- Respect unit turning radius by adjusting curve tightness
- Re-smooth when path updates mid-navigation

## Integration Points
- Connect to movement system for path-following execution
- Link with selection system for unit grouping navigation
- Coordinate with combat AI for tactical movement decisions
- Interface with minimap for visible path overlay (debug mode)

## Future Enhancements
- Hierarchical pathfinding for large maps (coarse-to-fine approach)
- Dynamic navmesh updates during gameplay (destructible terrain)
- Multi-agent path coordination (group formations)
- Machine learning optimized paths based on player behavior
