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

### Entity System Integration
Terrain objects (trees, rocks, fauna, flora) are entities with minimal components (see GitHub Issue #22):

```
EntityData.tres (entity_type = TERRAIN)
    ↓ EntityFactory autoload
Entity.tscn + optional components
```

- **Terrain entities** use the same `EntityData.gd` resource as all other entities
- `entity_type = TERRAIN` — SelectComponent is NOT added (not selectable)
- `strength = 0` → HealthComponent NOT added (indestructible)
- `strength > 0` → HealthComponent added (destructible trees/rocks)
- `foundation: Vector2i` → FoundationComponent added (terrain objects can have footprints)
- Trees/rocks use `art_data: ArtData` for model and visual properties

### Terrain Object Data Example
```gdscript
# Example: TREE01 (destructible)
{
    "id": "TREE01",
    "display_name": "Tree",
    "entity_type": "TERRAIN",
    "strength": 200,          # from rules.ini TreeStrength=200
    "armor": "wood",
    "foundation": Vector2i(1, 1),
    "art_data": preload("res://resources/art/terrain/tree01_art.tres")
}

# Example: SROCK01 (indestructible)
{
    "id": "SROCK01",
    "display_name": "Small Rock",
    "entity_type": "TERRAIN",
    "strength": 0,            # 0 = indestructible
    "foundation": Vector2i(1, 1)
}
```

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

## Related
- **Entity System**: See GitHub Issue #22 — composition-based architecture (IMPLEMENTED)
- **Map Design**: See `6-2_map_design.md` for terrain layout guidelines
- **Navigation**: See `2-1_navigation.md` for pathfinding over terrain
- **Data Population**: See GitHub Issue #23 for terrain entity .tres files
- **MovementController**: Issue #34 — implement locomotor enforcement and movement zones

## Implementation Status
- ✅ EntityData.gd — terrain entities use `entity_type = TERRAIN`
- ✅ .tres file created for TREE01 (destructible tree)
- 🔄 Remaining: ~25 more terrain .tres files (Issue #23), locomotor enforcement (Issue #34)

## Future Enhancements
- Destructible terrain (craters from explosions)
- Seasonal terrain changes affecting gameplay
- Dynamic weather modifying terrain properties
- Terrain-based unit bonuses (forest cover defense)
