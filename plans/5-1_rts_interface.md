# RTS Interface Elements - Redotian Sun

## Overview
The UI interface system provides players with essential information and control panels for managing their base, units, and resources during gameplay. This is critical for responsive RTS gameplay.

## Core Requirements

### 1. Selection Panel
- Displays health bars of selected units/buildings
- Shows available actions/commands per selection type
- Progress bars for construction/training queues
- Unit stats (health, armor, weapon info) on hover

### 2. Production Queue Display
- Visual list of queued buildings/units
- Progress indicators showing completion percentage
- Cancel button with refund confirmation
- Hotkey overlay showing queue slot numbers (1-5)

### 3. Resource HUD
| Element | Display Format | Update Frequency |
|---------|----------------|------------------|
| Credits | Numeric counter + income rate | Real-time (per frame) |
| Tiberium | Numeric counter + harvesting status | Every second |
| Power | Current/Max with color coding | When changes occur |

### 4. Minimap System
- Full map overview with fog of war overlay
- Unit markers colored by faction
- Build location indicators for queued structures
- Click-to-move functionality (right-click on minimap)

### 5. Build Menu Interface
- Categorized building/unit selection tabs
- Cost and production time display
- Availability states (locked/unavailable/ready)
- Preview panel showing model when hovered

## Technical Implementation

### Scene Structure
```
GameUI.tscn (Control root)
├── SelectionPanel.tscn (bottom-left corner)
├── ProductionQueue.tscn (bottom-center)
├── ResourceHUD.tscn (top-right corner)
├── MinimapContainer.tscn (bottom-right corner)
└── BuildMenu.tscn (hidden, toggle with hotkey)
```

### Key Scripts

#### GameUIController.gd
- Central coordinator for all UI panels
- Handle visibility toggling between states
- Update resource display every frame
- Process minimap click events for movement commands

#### SelectionPanel.gd
- Dynamically populate based on selected units
- Show health bars with color-coded damage levels
- Display action buttons for available commands
- Queue progress indicators for production

### Resource HUD Implementation
```gdscript
func update_resource_display(resources):
    credits_label.text = str(resources.credits) + " CR"
    tiberium_label.text = str(resources.tiberium) + " TIB"
    
    # Income rate display with color coding
    if resources.income_rate > 0:
        income_label.set_modulate(Color.GREEN)
    elif resources.income_rate < 0:
        income_label.set_modulate(Color.RED)
    
    income_label.text = str(resources.income_rate) + "/s"

func update_power_display(current, max):
    var percentage = float(current) / float(max)
    
    if percentage < 0.3:
        power_icon.set_modulate(Color.RED)
    elif percentage < 0.7:
        power_icon.set_modulate(Color.YELLOW)
    else:
        power_icon.set_modulate(Color.GREEN)
```

### Minimap Integration
- Render map tiles at reduced resolution for performance
- Draw unit markers as small colored circles/polygons
- Handle mouse clicks with raycast conversion to world coordinates
- Show build preview when placement mode active

## Integration Points
- Connect to economy system for resource updates
- Link with selection system for panel population
- Coordinate with production manager for queue display
- Interface with camera system for minimap position sync

## Future Enhancements
- Customizable UI scaling and positioning
- Compact vs expanded view modes
- Tooltip system for all UI elements
- Accessibility features (colorblind modes, high contrast)
