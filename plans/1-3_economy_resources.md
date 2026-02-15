# Economy & Resources System - Redotian Sun

## Overview
The economy system manages resource generation, collection, and spending—core mechanics that define RTS gameplay balance. This includes credits (primary currency) and Tiberium (harvestable resource).

## Core Requirements

### 1. Resource Types
| Resource | Primary Use | Generation Method |
|----------|-------------|-------------------|
| Credits | Building construction, unit production | Credit farms, refineries, passive income |
| Tiberium | Advanced units/buildings, tech upgrades | Harvesting nodes via harvesters |

### 2. Credit Economy
- **Income Sources**:
  - Credit Farms: Passive generation per second
  - Refineries: Convert Tiberium to credits (harvest loop)
  - Structures: Some buildings generate income over time
- **Expense Tracking**: 
  - Unit production costs deducted immediately
  - Building construction queued with upfront cost
  - Upgrades and abilities require payment

### 3. Tiberium Harvesting
- **Nodes**: Scattered resource fields of varying richness (small, medium, large)
- **Harvesters**: Specialized units that collect Tiberium
- **Refineries**: Process stations where harvesters unload cargo
- **Collection Loop**: Harvester → Node → Refinery → Credits
- **Depletion**: Nodes gradually deplete; some may become unusable

### 4. Production Cost System
- All units/buildings have credit/Tiberium costs
- Costs scale with tech levels/factions
- Affordability check before production queue addition
- Resource display in HUD (always visible)

## Technical Implementation

### Scene Structure
```
EconomySystem.tscn (Autoload Singleton)
├── ResourceManager.gd (singleton script)
├── CreditGenerator.gd (component for income sources)
└── TiberiumHarvester.gd (harvester unit logic)
```

### Key Scripts

#### ResourceManager.gd (Singleton)
- Global resource tracking: `credits`, `tiberium`
- Income rate calculation per frame
- Expense validation and deduction
- Event emission for UI updates when resources change

#### CreditGenerator.gd
- Inherited by income-producing structures
- Generates credits at defined intervals
- Handles bonus multipliers (tech upgrades, nearby buildings)

### Economy Data Structure
```gdscript
var current_resources = {
    "credits": 1000,
    "tiberium": 500,
    "income_rate": 2.5,  # credits per second
    "max_storage": 9999
}

func add_credits(amount):
    current_resources.credits = min(current_resources.credits + amount, max_storage)
    emit_signal("resources_changed")

func spend_credits(cost):
    if can_afford(cost):
        current_resources.credits -= cost
        return true
    return false
```

### Tiberium Harvesting Logic
- Harvester unit with `harvest()` method targeting node
- Node depletes: `node_amount -= harvest_amount`
- When full, harvester returns to refinery
- Refinery converts cargo to credits: `credits += cargo_value * efficiency`

## Integration Points
- Connect to UI system for resource HUD display
- Link with base building for credit farm placement validation
- Coordinate with unit production for cost deduction timing
- Interface with faction systems for unique economic bonuses

## Future Enhancements
- Tiberium toxicity effects on units over time
- Resource sabotage mechanics (enemy can destroy harvesters)
- Dynamic pricing based on supply/demand
- Trade system between players in multiplayer
