# Proposal: MapEditor Entity Placement with Player Assignment

## Problem

The MapEditor can paint terrain, resources, and trees, but cannot place game entities (buildings, units) or assign them to players. This is needed to set up starting conditions for matches.

## Solution

Add entity placement to the MapEditor with a left sidebar panel for entity selection and player assignment. The panel follows the industry standard pattern (WAE, OpenRA) with category tabs, owner dropdown, and searchable entity list. Clicking an entity in the browser toggles placement mode; clicking the map places the selected entity.

## UI Design

### Left Sidebar Panel

```
┌─────────────────────────────┐
│ [Buildings] [Infantry]      │  ← Category tabs (all active)
│ [Vehicles] [Aircraft]       │
├─────────────────────────────┤
│ Owner: [Player 0       ▼]   │  ← Player dropdown
├─────────────────────────────┤
│ Search entity...            │  ← Search bar
├─────────────────────────────┤
│ - Buildings -               │  ← Filtered list
│   Construction Yard (GACNST)│
│   Power Plant (GAPOWR)      │
│   Barracks (GAPILE)         │
│   War Factory (GAWEAP)      │
│   ...                       │
└─────────────────────────────┘
```

### Workflow

1. Select player from Owner dropdown (Player 0, Player 1)
2. Click entity type from list (or search) — toggles placement mode
3. Preview ghost (50% opacity) follows cursor over map
4. Click map cell to place entity (right-click cancels)
5. Entity created with `player_id` metadata and foundation-aware positioning
6. Save/load includes `player_id` field

### Placement Behavior

- **Single-cell entities** (infantry, vehicles): placed at cell center
- **Multi-cell entities** (buildings): positioned via `_cell_origin_world_pos()` to account for foundation footprint
- **Preview ghost**: translucent entity follows cursor, hidden during height painting
- **Cancel**: right-click or click same entity in browser to deselect

## Data Format

### Map JSON Extension

Current format:
```json
{
  "entities": [
    {"id": "TIB", "cell": "5,10", "strength": 300}
  ]
}
```

Extended format:
```json
{
  "entities": [
    {"id": "TIB", "cell": "5,10", "strength": 300},
    {"id": "GACNST", "cell": "15,20", "player_id": 0},
    {"id": "BGGY", "cell": "25,20", "player_id": 1}
  ]
}
```

## Scope

- Place buildings, infantry, and vehicles (all entity types via category tabs)
- Player dropdown with Player 0 and Player 1
- Save/load includes `player_id`
- Left sidebar panel always visible with category tabs
- Search functionality
- Preview ghost before placement (50% opacity)
- Foundation-aware positioning for multi-cell buildings
- Right-click to cancel placement
- ResourceGrowthSystem disabled in MapEditor scene

## Depends on

- #77 (PlayerManager — player_id system)
- EntityFactory.create_entity() with overrides (already works)
- EntityFactory.get_all_by_type() for entity list population

## Blocks

- Cannot set up test scenarios with enemy buildings
- Cannot assign starting buildings to specific players
- Full game loop requires pre-placed enemy base
