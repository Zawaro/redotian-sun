# Unit Roster - Redotian Sun

## Overview
The unit roster defines all playable units across factions, including their stats, abilities, and counter relationships. This creates strategic depth through rock-paper-scissors balance.

## Core Requirements

### 1. Infantry Units
| Unit | Faction | Role | Cost | Health | Special Ability |
|------|---------|------|------|--------|-----------------|
| Marine | GDI | Anti-infantry | 50 CR | 40 | Squad formation |
| Engineer | Both | Capture/repair | 250 CR | 30 | Build/capture structures |
| Terrorist | Nod | Sabotage | 600 CR | 25 | Self-destruct on death |

### 2. Vehicle Units  
| Unit | Faction | Role | Cost | Health | Special Ability |
|------|---------|------|------|--------|-----------------|
| APC | GDI | Transport | 700 CR | 300 | Carry 4 infantry |
| Tank Destroyer | GDI | Anti-tank | 1200 CR | 450 | Long-range anti-armor |
| Attack Car | Nod | Fast attack | 800 CR | 200 | Ramming damage |
| Nuke Launcher | Nod | Siege | 3000 CR | 600 | Nuclear strike ability |

### 3. Aircraft Units (Optional Phase)
- Fighter jets for anti-air coverage
- Bombers for ground assault capability  
- Transport helicopters for unit delivery
- All require airfield production structure

### 4. Hero/Special Units
| Unit | Faction | Role | Unlocks | Special Ability |
|------|---------|------|---------|-----------------|
| Commander GDI | GDI | Leader | Endgame | Call in orbital strike |
| Kane Clone | Nod | Leader | Endgame | Self-revive once |

### 5. Counter Relationships
- Infantry counters: Vehicles (via engineer capture)
- Anti-tank counters: Infantry with rockets, tank destroyers
- Air superiority counters: Anti-air units vs aircraft
- Base defense counters: Siege weapons vs buildings

## Technical Implementation

### Scene Structure
```
UnitRoster.tscn (Resource database)
├── UnitTemplate.gd (data asset for each unit type)
├── CounterSystem.gd (rock-paper-scissors logic)
└── UnlockManager.gd (tech progression tracking)
```

### Key Scripts

#### UnitTemplate.gd (Data Asset)
- Store all unit statistics in resource file format
- Define faction assignment and production requirements
- Specify weapon stats, health, speed, vision radius
- Include special ability configurations

#### CounterSystem.gd
- Calculate damage multipliers based on unit type matchups
- Apply counter bonuses (e.g., infantry vs vehicles = 2.0x)
- Provide strategic recommendations in UI tooltips
- Track unit losses for balance analysis

### Unit Template Example
```gdscript
@tool
extends Resource
class_name UnitTemplate

@export var name: String = "Marine"
@export var faction: String = "GDI"
@export var cost_credits: int = 50
@export var health: int = 40
@export var speed: float = 1.5
@export var vision_range: float = 200.0

@export_group("Weapons")
@export var damage_type: String = "bullet"
@export var base_damage: float = 8.0
@export var fire_rate: float = 0.5
@export var range: float = 150.0

@export_group("Abilities")
@export var has_special_ability: bool = false
@export var ability_cooldown: float = 30.0
```

### Counter System Logic
- Define counters in data structure: `{"infantry": {"vehicles": 2.0}}`
- Apply multiplier when unit attacks counter target
- Display advantage indicator in UI (green/red arrows)
- Track combat effectiveness for balance tuning

## Integration Points
- Connect to production system for spawning templates
- Link with faction system for variant selection
- Coordinate with combat AI for targeted engagement
- Interface with economy for cost validation

## Future Enhancements
- Dynamic unit balancing based on win rates
- Custom unit creation tools for modders
- Unit prestige systems ( veterancy levels)
- Synergy bonuses when combining specific units
