# Terrain Systems - Redotian Sun

## Overview
The terrain system defines the physical foundation of the game world, affecting unit movement, building placement, and resource distribution. This creates strategic depth through varied landscapes.

## Core Requirements

### 1. Terrain Types & Movement Modifiers
| Terrain Type | Speed Modifier | Notes |
|--------------|----------------|-------|
| Flat Ground | 100% (baseline) | Standard movement speed |
| Hills/Slopes | 65-80% | Reduced vehicle speed, infantry unaffected |
| Rocky/Rough | 50% | Significant slowdown for all units |
| Water - Shallow | 30% | Naval only, ground blocked |
| Water - Deep | 0% (blocked) | Untaversable by any unit |
| Tiberium Fields | 90% + toxicity | Slow movement with health drain |
| Road Networks | 140% | Vehicle speed bonus |
| Forest/Wooded | 70% | Cover bonus, slowed movement |

### 2. Elevation System
- Height values determine buildable vs unbuildable areas
- Cliff edges prevent building placement
- Slope calculations for unit traversal feasibility
- Visual height representation via terrain mesh

### 3. Tiberium Distribution
- Random generation with seed control for replayability
- Cluster patterns (small, medium, large fields)
- Depletion mechanics over time during matches
- Special "rich" nodes with higher resource value

### 4. Environmental Hazards (Optional)
- Radiation zones damage units over time
- Lava/acid destroys structures instantly
- Storms reduce visibility or unit effectiveness
- Dynamic terrain changes mid-game

## Technical Implementation

### Scene Structure
```
TerrainSystem.tscn (Autoload Singleton)
├── TerrainManager.gd (singleton terrain data)
├── ElevationCalculator.gd (height/slope logic)
└── TiberiumGenerator.gd (resource placement)
```

### Key Scripts

#### TerrainManager.gd (Singleton)
- Store tile-based terrain data in 2D array
- Query tile properties for movement/building validation
- Cache frequently accessed terrain info for performance
- Emit signals when terrain changes (depletion, destruction)

#### ElevationCalculator.gd
- Calculate slope between adjacent tiles
- Determine if unit can traverse elevation change
- Generate heightmap for visual rendering
- Provide buildability data based on terrain type

### Terrain Data Structure
```gdscript
var terrain_tiles = {
    "flat": {"speed_mod": 1.0, "buildable": true},
    "hill": {"speed_mod": 0.75, "buildable": false},
    "rocky": {"speed_mod": 0.5, "buildable": true},
    "water_shallow": {"speed_mod": 0.3, "naval_only": true},
    "water_deep": {"speed_mod": 0.0, "blocked": true},
    "tiberium": {"speed_mod": 0.9, "resource_value": 100},
    "road": {"speed_mod": 1.4, "vehicle_only": true}
}

func get_terrain_modifier(position):
    var tile = terrain_tiles_at.get_tile(position)
    return tile.terrain_type.speed_mod
```

### Tiberium Generation Algorithm
- Seed-based random placement for consistency
- Cluster generation: create groups of tiles with resource value
- Depletion tracking per match instance
- Rich nodes have higher harvest yield and slower depletion

## Integration Points
- Connect to pathfinding system for movement cost calculation
- Link with base building for build placement validation
- Coordinate with economy system for resource harvesting
- Interface with minimap for terrain visualization

## Future Enhancements
- Destructible terrain (craters from explosions)
- Seasonal terrain changes affecting gameplay
- Dynamic weather modifying terrain properties
- Terrain-based unit bonuses (forest cover defense)
