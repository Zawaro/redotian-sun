# Base Building System - Redotian Sun

## Overview
The base building system enables players to construct, upgrade, and manage their structures throughout the game. This is a core RTS mechanic that requires careful design for placement validation, resource costs, and strategic depth.

## Core Requirements

### 1. Placement Mechanics
- **Build Mode**: Activate via build menu or hotkey (B)
- **Placement Preview**: Ghost outline showing proposed location
- **Validation Rules**: 
  - Terrain compatibility check (no water, cliffs for certain buildings)
  - Proximity constraints (distance from other structures)
  - Power grid requirements (must connect to existing power)
  - Buildable area restrictions (within player territory only)

### 2. Construction Process
- **Cost Display**: Show credit/Tiberium cost before placement
- **Construction Queue**: Multiple buildings can be queued simultaneously
- **Build Timers**: Visual progress indicator during construction
- **Resource Deduction**: Immediate deduction of costs upon queue addition
- **Production Logic**: Buildings construct over time (5-30 seconds typical)

### 3. Power Grid System
- Each building consumes power based on type
- Power plants generate capacity
- Overload protection: buildings shut down when power negative
- Visual feedback for power status (green/red indicators)

### 4. Building States
| State | Description |
|-------|-------------|
| Idle | Ready to accept commands |
| Constructing | Currently being built |
| Upgrading | Being upgraded with tech |
| Damaged | Health < 100% |
| Destroyed | Removed from world, can be rebuilt |

## Technical Implementation

### Scene Structure
```
BuildingManager.tscn (Node)
├── PlacementPreview.tscn (Control node with ghost mesh)
├── ConstructionQueue.tscn (UI panel)
└── Building.gd (Base script for all structures)
```

### Key Scripts

#### BuildingManager.gd
- Handle build mode toggle and placement input
- Validate build locations against terrain/collision data
- Manage construction queue with priority ordering
- Deduct resources and spawn building instances on completion

#### Building.gd (Inherited by all structures)
- Health/armor system for damage calculation
- Power consumption tracking
- Build state transitions (idle → constructing → complete)
- Destruction logic with drop-on-death resource refunds

### Placement Validation Logic
```gdscript
func can_build_at(position, building_type):
    # Check terrain type compatibility
    if not is_terrain_suitable(position, building_type.terrain_requirements):
        return false
    
    # Check power grid capacity
    if not has_power_capacity(building_type.power_cost):
        return false
    
    # Check proximity to other structures
    if distance_to_nearest_building(position) < building_type.min_spacing:
        return false
    
    # Verify within player territory
    if not is_in_territory(position, owner):
        return false
    
    return true
```

### Construction Queue System
- FIFO queue with max entries (typically 5-10 buildings)
- Each entry contains: building_type, position, spawn_time
- Progress tracking via timer updates every frame
- Completion triggers: resource refund on cancel, unit spawning on finish

## Integration Points
- Connect to economy system for cost validation and deductions
- Link with camera system for auto-centering on new builds
- Coordinate with minimap for construction progress indicators
- Integrate with faction systems for unique building variants

## Future Enhancements
- Building upgrades with tech tree prerequisites
- Auto-repair mechanics over time
- Defensive placement suggestions (AI assistance)
- Destructible environment interaction during construction
