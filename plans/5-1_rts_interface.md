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

### 5. Build Menu Interface — Tabbed Sidebar

**GitHub Issue**: #66 — feat: tabbed build menu sidebar with 4 production categories

#### Tab Layout (Vinifera-style for TS)
```
┌──────────┬──────────┬──────────┬──────────┐
│ Buildings│ Infantry │ Vehicles │ Special  │
└──────────┴──────────┴──────────┴──────────┘
```

| Tab | Entity Type | Content | Production Building |
|-----|-------------|---------|---------------------|
| **Buildings** | BUILDING | Structures, defenses (sorted last) | Construction Yard |
| **Infantry** | INFANTRY | Infantry units | Barracks / Hand of Nod |
| **Vehicles** | VEHICLE | Tanks, buggies, harvesters, MCV | War Factory |
| **Special** | AIRCRAFT | Aircraft, superweapons | Airfield / Shipyard |

#### Sidebar Layout
```
┌─────────────────────────────────────────┐
│ $1500                                  │  ← Credits (top)
├─────────────────────────────────────────┤
│ [Build][Infantry][Vehicles][Special]   │  ← Tab bar
├─────────────────────────────────────────┤
│ ┌───────┐ ┌───────┐ ┌───────┐         │
│ │ ▓▓▓  │ │ ░░░  │ │  ░░  │ 5×3     │
│ │ConYard│ │ Power │ │Barracks│  grid    │
│ └───────┘ └───────┘ └───────┘         │
│ ... (5 rows × 3 cols = 15 visible)     │
├─────────────────────────────────────────┤
│ [▲]                           [▼]     │  ← Scroll by row
└─────────────────────────────────────────┘
```

- Width: 400px, Height: ~600px
- 5 rows × 3 columns, scrollable by row steps
- Middle mouse scroll on sidebar → scroll grid (consume event, don't zoom camera)
- Tab hotkeys: F1-F4

#### Cameo States
| State | Visual |
|-------|--------|
| Available | Normal cameo, full color |
| In queue (building) | Angular progress overlay (12 o'clock → clockwise) |
| In queue (paused) | Darkened, progress frozen |
| Prerequisites not met | Hidden |
| Build limit reached | Darkened "ghost" cameo |

#### Interaction
| Action | Effect |
|--------|--------|
| Left-click available | Add to queue, deduct cost |
| Left-click paused | Resume production |
| Right-click building | Pause production |
| Right-click paused | Cancel (refund) or decrement stack |
| Middle scroll on sidebar | Scroll grid row (not camera zoom)

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

## 6. Cursor System

**GitHub Issue**: #70 — feat: Tiberian Sun cursor system with per-unit resolution

### Overview
Context-sensitive cursors matching original Tiberian Sun. Placeholder SVGs, later PNG sequences for animation. Per-unit resolution — each entity component determines what cursor to show.

### Cursor Types (28 unique + 28 minimap)
- **Scroll (16)**: 8 directions × 2 (normal + blocked). Edge detection at 20px from viewport edge.
- **Core (12)**: default, select, move, move-blocked, attack, attack-out-of-range, harvest, enter, guard, sell, repair, generic-blocked
- **Minimap (28)**: Same sprites at 16×16 (asset-ready, not used yet)

### Resolution Architecture
1. **Global overrides**: dragging → SELECT, screen edge → SCROLL_*, sell/repair mode → SELL/REPAIR
2. **Per-unit resolution**: each selected entity's components return a cursor + priority. Highest priority wins.
3. **Fallback**: DEFAULT

### Component → Cursor Mapping
| Component | Target | Cursor | Priority |
|-----------|--------|--------|----------|
| CombatComponent | Enemy | ATTACK | 30 |
| HarvestComponent | Tiberium | HARVEST | 20 |
| HarvestComponent | Refinery | ENTER | 15 |
| TransportComponent | Friendly infantry | ENTER | 10 |
| MovementController | Ground | MOVE | 5 |

### Files
- `scripts/hud/CursorState.gd` — enum + texture registry
- `scripts/hud/MouseHandler.gd` — _update_cursor(), resolve_cursor(), scroll detection
- `scripts/components/{Combat,Harvest,Transport}Component.gd` + `MovementController.gd` — add get_cursor_for_target()
- `assets/cursors/*.svg` — 28 placeholder SVGs

## Future Enhancements
- Customizable UI scaling and positioning
- Compact vs expanded view modes
- Tooltip system for all UI elements
- Accessibility features (colorblind modes, high contrast)
