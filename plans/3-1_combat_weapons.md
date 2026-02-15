# Combat & Weapons System - Redotian Sun

## Overview
The combat system handles all damage calculation, weapon mechanics, and unit health management. This is critical for balanced gameplay and engaging tactical decisions.

## Core Requirements

### 1. Damage Types
| Type | Effective Against | Resistance Examples |
|------|-------------------|---------------------|
| Bullet | Infantry, light vehicles | Armor reduces effectiveness |
| Explosive | Structures, armored units | Buildings take more damage |
| Energy | Vehicles, structures | Shields mitigate energy |
| Anti-Air | Aircraft only | Ground units immune |
| Siege | Buildings only | Units take reduced damage |

### 2. Weapon System Stats
- **Damage**: Base damage per shot/projectile
- **Fire Rate**: Time between shots (seconds)
- **Range**: Maximum target distance
- **Accuracy**: Probability of hitting (0.0 - 1.0)
- **Projectiles**: Number fired per volley
- **Splash Radius**: Area damage for explosives

### 3. Armor & Resistance
- Each unit has armor value reducing incoming damage
- Damage formula: `final_damage = base_damage * (1 - armor_resistance)`
- Resistances vary by damage type (e.g., tanks resist bullets)
- Overpenetration mechanics for high-damage weapons

### 4. Health Mechanics
- **Health Points**: Unit durability pool
- **Regeneration**: Passive healing over time when not in combat
- **Repair**: Active repair via engineer or self-repair ability
- **Death Effects**: Particle explosion, debris scatter, resource drop

## Technical Implementation

### Scene Structure
```
CombatSystem.tscn (Autoload Singleton)
├── WeaponComponent.gd (attached to units)
├── HealthComponent.gd (damage/take damage logic)
└── CombatAI.gd (target selection & engagement)
```

### Key Scripts

#### WeaponComponent.gd
- Fire rate timer management
- Range check against target distance
- Accuracy roll for hit determination
- Spawn projectiles or apply hitscan damage directly

#### HealthComponent.gd
- Track current health/max health ratio
- Apply damage with armor calculation
- Trigger death when health ≤ 0
- Handle repair/regeneration over time

### Damage Calculation Logic
```gdscript
func calculate_damage(damage_type, base_damage, target_armor):
    # Get resistance values from unit stats
    var resistance = target_armor.get_resistance(damage_type)
    
    # Apply armor reduction
    var final_damage = base_damage * (1.0 - resistance)
    
    # Floor at minimum damage (1 point always gets through)
    return max(1, floor(final_damage))

func take_damage(amount, damage_type):
    current_health -= calculate_damage(damage_type, amount, armor)
    
    if current_health <= 0:
        on_unit_destroyed()
```

### Weapon Firing System
- Check range before firing
- Perform accuracy roll (random 0.0-1.0 vs weapon accuracy)
- On hit: apply damage to target's HealthComponent
- On miss: spawn impact effect at target location
- Cooldown timer prevents spamming attacks

## Integration Points
- Connect to unit system for weapon/health component attachment
- Link with pathfinding for movement while attacking
- Coordinate with selection for targeting feedback visuals
- Interface with economy for death resource refunds

## Future Enhancements
- Cover mechanics (units gain defense behind obstacles)
- Flanking bonuses based on attack angle
- Weapon upgrade trees per faction
- Special abilities with cooldowns and resource costs
