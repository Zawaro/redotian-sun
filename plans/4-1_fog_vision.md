# Fog of War & Vision System - Redotian Sun

## Overview
The fog of war system creates strategic depth by hiding unexplored areas, limiting vision to what units/buildings can see, and enabling classic RTS exploration mechanics.

## Core Requirements

### 1. Fog Layers
| Layer | Visibility | Description |
|-------|------------|-------------|
| Unexplored | Completely black | Never visited area |
| Explored | Dimmed gray | Previously seen but currently hidden |
| Visible | Full brightness | Currently in unit/building vision range |

### 2. Vision Radius Mechanics
- Each unit/structure has a unique vision radius
- Vision updates dynamically as units move
- Buildings provide permanent vision at their location
- Stacking vision does not expand radius (no bonus stacking)

### 3. Line of Sight (LOS) Calculation
- Raycasting from unit center to target position
- Terrain elevation blocks vision over hills/mountains
- Buildings obstruct LOS for smaller units
- Water tiles block ground unit vision but not naval

### 4. Dynamic Updates
- Vision recalculates when units move or die
- Explored areas persist after units leave
- Unexplored reverts to black only on map reset
- Minimap updates in real-time as fog changes

## Technical Implementation

### Scene Structure
```
FogOfWarSystem.tscn (Autoload Singleton)
├── VisionManager.gd (singleton vision tracking)
├── LOSCalculator.gd (raycasting logic)
└── FogRenderer.gd (shader-based visual effects)
```

### Key Scripts

#### VisionManager.gd (Singleton)
- Track explored map regions via bitmask or tile grid
- Update vision radius for all active units/buildings each frame
- Emit events when significant exploration occurs
- Manage minimap visibility state synchronization

#### LOSCalculator.gd
- Cast rays from source to target positions
- Check terrain height and building collisions along path
- Return true if line is unobstructed, false otherwise
- Optimize with spatial partitioning for performance

### Vision Update Logic
```gdscript
func update_vision_for_unit(unit):
    var vision_radius = unit.vision_range
    
    # Mark all tiles within radius as visible
    for tile in get_tiles_in_circle(unit.position, vision_radius):
        if is_ground_tile(tile):
            explored_map.set_tile_visible(tile, true)
            
            # Check LOS to surrounding area
            for target in get_entities_nearby(tile):
                if has_line_of_sight(unit.position, target.position):
                    tile.set_fog_state("visible")

func has_line_of_sight(source, target):
    var raycast_result = world_space_raycast(source, target)
    return not raycast_result.has_hit_terrain() and not raycast_result.has_hit_building()
```

### Map Exploration Tracking
- Track explored percentage: `explored_tiles / total_tiles * 100`
- Win condition based on exploration (e.g., 95% for "domination")
- Fog persistence across game sessions in skirmish mode
- Minimap generation using explored tile data

## Integration Points
- Connect to minimap system for visibility updates
- Link with unit production for starting vision placement
- Coordinate with selection system for target acquisition feedback
- Interface with combat AI for enemy detection events

## Future Enhancements
- Fog of war reveals via scout units or abilities
- Dynamic fog density based on weather effects
- Vision sharing between allied players in multiplayer
- Night/day cycle affecting vision radius
