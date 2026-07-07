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

### Entity System Integration
Buildings are defined via the **composition-based entity system** (see GitHub Issue #22):

```
EntityData.tres (entity_type = BUILDING)
    ↓ EntityFactory autoload
Entity.tscn + dynamically added components
```

- **One `EntityData.gd`** resource class with ALL properties
- Building-specific properties: `foundation`, `height`, `power`, `powered`, `adjacent`, `factory`, `capturable`, `radar`, `repairable`
- Components added dynamically:
  - `BuildingComponent` — foundation, placement rules
  - `PowerComponent` — power output/consumption
  - `RadarComponent` — radar availability
  - `FactoryComponent` — unit production capability
  - `CombatComponent` — if building has weapons (e.g., guard tower)
  - `StatsComponent` — name, cost, tech level, armor
  - `HealthComponent` — strength > 0
  - `HitboxComponent` — always
  - `SelectComponent` — always for buildings
  - `ArtComponent` — visual data

### Building Data Example
```gdscript
# Example: GDI Power Plant
{
    "id": "GAPOWR",
    "display_name": "GDI Power Plant",
    "entity_type": "BUILDING",
    "strength": 750,
    "armor": "wood",
    "cost": 300,
    "tech_level": 1,
    "sight": 4,
    "owner": ["GDI"],
    "foundation": Vector2i(2, 2),
    "height": 2.0,
    "power": 100,              # positive = output
    "powered": false,          # doesn't require power to function
    "adjacent": 2,
    "capturable": true,
    "prerequisite": [],
    "art_data": preload("res://resources/art/structures/gapowr_art.tres")
}
```

### Scene Structure
```
BuildingManager.tscn (Node)
├── PlacementPreview.tscn (Control node with ghost mesh)
├── ConstructionQueue.tscn (UI panel)
└── Building.gd (Base script for all structures)
```

### Key Scripts

#### BuildingManager.gd (EXISTING — updated)
- Handle build mode toggle and placement input
- Validate build locations against terrain/collision data
- Manage construction queue with priority ordering
- Deduct resources and spawn building instances via EntityFactory

#### EntityFactory.gd (Autoload)
- Creates any entity from EntityData resource
- Components added dynamically based on data properties
- BuildingManager calls `EntityFactory.create_entity("GAPOWR")` to spawn buildings

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

## Related
- **Entity System**: See GitHub Issue #22 — composition-based architecture (IMPLEMENTED)
- **Economy**: See `1-3_economy_resources.md` for resource management
- **Unit Production**: See `1-4_unit_production.md` for FactoryComponent integration
- **BuildingManager Integration**: See GitHub Issue #25 for migration from BuildingType to EntityFactory
- **PowerComponent**: See GitHub Issue #33 for power grid implementation

## Implementation Status
- ✅ EntityData.gd — buildings use `entity_type = BUILDING`
- ✅ EntityFactory.gd — creates buildings from data, adds components dynamically
- ✅ BuildingManager.gd — handles build mode, placement validation, construction
- ✅ .tres files created for: GACNST, GAPOWR, NAPOWR
- ✅ CivilianGuardTower01 — placed via build menu (BuildingType .tres)
- 🔄 Remaining: BuildingManager migration to EntityFactory (Issue #25), power grid (Issue #33)

## Future Enhancements
- Building upgrades with tech tree prerequisites
- Auto-repair mechanics over time
- Defensive placement suggestions (AI assistance)
- Destructible environment interaction during construction
