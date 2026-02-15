# Unit Production Pipeline - Redotian Sun

## Overview
The unit production pipeline manages the creation of new units through factories, barracks, and other production structures. This system handles queue management, tech prerequisites, and spawn logic.

## Core Requirements

### 1. Production Structures
| Structure Type | Produces | Special Requirements |
|----------------|----------|---------------------|
| Factory/ Barracks | Ground units | Power required, specific tech level |
| Airfield | Aircraft units | Runway space, higher power cost |
| Shipyard | Naval units | Must be near water tiles |
| Defense Platform | Turrets/Walls | Fixed position, no movement |

### 2. Training Queue System
- Multiple slots for queued units (typically 3-5)
- Priority ordering: first in = first out
- Cancel option returns partial refund
- Visual progress bar showing construction time
- Unit preview icon during production

### 3. Tech Tree Integration
- Prerequisite buildings must exist before unlocking
- Research upgrades enable new unit types
- Faction-specific tech paths (GDI vs Nod differences)
- Level requirements for advanced units

### 4. Spawn Logic
- Units spawn at designated production locations
- Pathfinding to nearest valid area
- Immediate availability for player commands
- Reinforcement waves for AI opponents

## Technical Implementation

### Scene Structure
```
ProductionManager.tscn (Node)
├── ProductionQueue.tscn (UI component)
├── Factory.gd (base script for production buildings)
└── UnitSpawner.gd (handles instantiation logic)
```

### Key Scripts

#### ProductionManager.gd
- Global queue management across all production structures
- Handle unit creation requests and validate prerequisites
- Manage queue state: empty, producing, full
- Event emission when queue status changes

#### Factory.gd (Inherited by all production buildings)
- Queue array storing pending units: `var production_queue = []`
- Production timer tracking progress toward completion
- Unlock check against tech tree requirements
- Spawn unit at designated location on completion

### Unit Spawning Logic
```gdscript
func spawn_unit(unit_type, spawn_position):
    # Load unit scene/template from resource cache
    var unit_scene = load("res://scenes/units/" + unit_type + ".tscn")
    var unit_instance = unit_scene.instantiate()
    
    # Set owner and faction properties
    unit_instance.owner_id = self.owner_id
    unit_instance.faction = self.faction
    
    # Position at spawn point with slight offset
    unit_instance.global_position = spawn_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
    
    # Add to scene tree and enable
    get_tree().root.add_child(unit_instance)
    unit_instance.ready_to_use = true
    
    emit_signal("unit_spawned", unit_type)
```

### Queue Management System
- FIFO queue with max capacity check
- Each entry: `{type, progress, cost, prerequisites}`
- Progress increments every frame based on build_time
- On completion: spawn unit, remove from queue, continue next item

## Integration Points
- Connect to economy system for cost deduction timing
- Link with tech tree for unlock validation
- Coordinate with selection system for newly spawned units
- Interface with minimap for production progress indicators

## Future Enhancements
- Batch production (train multiple units simultaneously)
- Priority reordering in queue via drag-drop UI
- Emergency recall function for partially trained units
- Production speed bonuses from tech upgrades
