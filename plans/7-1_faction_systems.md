# Faction Systems - Redotian Sun

## Overview
Faction systems define unique mechanics, units, buildings, and strategies for each playable side. This creates asymmetric gameplay that mirrors the original C&C: Tiberian Sun experience.

## Core Requirements

### 1. GDI Faction Mechanics
- **Playstyle**: Defensive, balanced, technology-focused
- **Unique Features**:
  - Stronger base defenses
  - Advanced repair capabilities
  - Shield/armor upgrades available earlier
  - Superior air unit support
- **Base Color Palette**: Blue/green/white (clean military aesthetic)

### 2. Nod Faction Mechanics  
- **Playstyle**: Aggressive, stealth-focused, guerrilla tactics
- **Unique Features**:
  - Stealth technology (camo units/buildings)
  - Faster production times
  - Sabotage abilities (destroy enemy structures)
  - Suicide unit variants
- **Base Color Palette**: Red/black/orange (dark militant aesthetic)

### 3. Unique Unit/Structure Differences
| Aspect | GDI | Nod |
|--------|-----|-----|
| Infantry | Marines with rifles | Stealth operatives |
| Vehicles | Heavy tanks, APCs | Fast attack cars, nukes |
| Air Units | Fighters, bombers | Stealth aircraft |
| Base Buildings | Reinforced walls | Camo concealers |
| Special Ability | Orbital strike | Nuclear launch |

### 4. Tech Tree Variations
- Faction-specific research paths
- Different prerequisite structures for unlocking
- Unique upgrades per faction (e.g., GDI shields, Nod camo)
- Asymmetric power curves (early vs late game strengths)

## Technical Implementation

### Scene Structure
```
FactionSystem.tscn (Autoload Singleton)
├── FactionManager.gd (singleton faction logic)
├── UnitVariant.gd (faction-specific unit templates)
└── TechTreeResolver.gd (unlock validation)
```

### Key Scripts

#### FactionManager.gd (Singleton)
- Track active faction per player
- Provide faction bonuses and modifiers
- Resolve faction-specific unit/building variants
- Handle special ability cooldowns and costs

#### UnitVariant.gd
- Base template with faction overrides
- Adjust stats: speed, damage, cost based on faction
- Replace models/textures for visual differentiation
- Define unique abilities per faction unit

### Faction Data Structure
```gdscript
var factions = {
    "GDI": {
        "name": "Global Defense Initiative",
        "color": Color(0.2, 0.6, 0.9),
        "bonuses": {"repair_speed": 1.5, "shield_strength": 1.3},
        "units": ["marine", "apc", "tank_destroyer"],
        "buildings": ["con_yard", "power_plant", "tech_center"]
    },
    "NOD": {
        "name": "Children of Nod", 
        "color": Color(0.9, 0.2, 0.2),
        "bonuses": {"production_speed": 1.3, "stealth_duration": 2.0},
        "units": ["terrorist", "attack_car", "nuke_launcher"],
        "buildings": ["con_yard_stealth", "power_plant_dark", "temple"]
    }
}

func get_faction_bonus(faction, bonus_type):
    return factions[faction].bonuses[bonus_type]
```

### Tech Tree Resolution Logic
- Check prerequisite buildings exist before unlock
- Apply faction-specific prerequisites (different tech paths)
- Track research progress per player/faction
- Enable units/buildings when requirements met

## Integration Points
- Connect to unit production for variant spawning
- Link with economy system for faction cost modifiers
- Coordinate with combat AI for faction behavior patterns
- Interface with UI system for faction-specific menus

## Future Enhancements
- Additional factions (Scrin, Nod splinter groups)
- Faction reputation system affecting diplomacy
- Customizable faction loadouts in multiplayer
- Faction victory animations and cinematics
