# Design: MapEditor Entity Placement with Player Assignment

## Architecture

### Component Structure (Post-Refactoring)

```
MapEditor (scripts/editor/MapEditor.gd) — orchestrator, shared state, input routing
├── EditorGrid (scripts/editor/EditorGrid.gd) — grid overlay, cell highlight, height label
├── EntityPlacer (scripts/editor/EntityPlacer.gd) — entity browser, preview, placement
├── ResourcePainter (scripts/editor/ResourcePainter.gd) — tiberium brush painting/erasing
├── EditorSaveLoad (scripts/editor/EditorSaveLoad.gd) — file dialogs, save/load serialization
├── HeightPainter (scripts/editor/HeightPainter.gd) — terrain height painting (existing)
├── Minimap (scripts/editor/Minimap.gd) — minimap viewport (existing)
└── EditorUI (CanvasLayer)
    ├── ToolBar (HBoxContainer) — save/load, tools, strength/radius, grid toggle, height label
    └── EntityBrowser (scripts/editor/EntityBrowser.gd) — left sidebar panel
        ├── CategoryTabs (TabBar) — Buildings, Infantry, Vehicles, Aircraft, Naval
        ├── OwnerDropdown (OptionButton) — Player 0, Player 1
        ├── SearchBar (LineEdit)
        └── EntityList (ItemList)
```

### Data Flow

```
User clicks entity in EntityBrowser
    → EntityBrowser.entity_selected.emit(entity_id)
    → EntityPlacer._on_entity_selected(entity_id)
    → Toggles _selected_entity_id (click same entity to deselect)
    → Sets editor._active_tool = Tool.PLACE_ENTITY
    → EntityPlacer._update_preview() — creates 50% opacity ghost

User moves mouse over map
    → MapEditor._update_hovered_cell() — raycasts to find cell
    → EntityPlacer._update_preview_position() — moves ghost to cell
    → EditorGrid._update_cell_highlight() — hidden during PLACE_ENTITY mode

User clicks map cell (left mouse)
    → MapEditor._input() → EntityPlacer.handle_input()
    → EntityPlacer._place_entity_on_cell(cell)
    → EntityFactory.create_entity(entity_id)
    → Positions via _cell_origin_world_pos(cell, foundation) for multi-cell buildings
    → Stores in editor._painted_entities with player_id
    → Refreshes preview for next placement

User right-clicks
    → EntityPlacer.handle_input() clears _selected_entity_id
    → MapEditor._active_tool = Tool.NONE
    → Preview removed

User saves map
    → EditorSaveLoad._on_save_file_selected(path)
    → Iterates _painted_entities, includes player_id in JSON
```

### Sub-Script Pattern

All sub-scripts follow the HeightPainter pattern:
```gdscript
extends Node

var editor: Node3D = null  # Reference to MapEditor

func setup() -> void:
    # Create child nodes, add to editor
```

Sub-scripts access shared state via `editor._hovered_cell`, `editor._active_tool`, `editor._painted_entities`.

## Key Implementation Details

### EntityBrowser

- **Always visible** — no toggle button; panel shown by default when MapEditor loads
- **Click-to-toggle** — clicking an entity selects it for placement; clicking again deselects
- **Category tabs** — all tabs active, filter by EntityData.EntityType
- **Owner dropdown** — populated from PlayerManager, default Player 0

### Preview Ghost

- 50% opacity entity follows cursor before placement
- Uses `_set_preview_transparency()` to recursively apply alpha to all MeshInstance3D nodes
- Hidden during height painting (PLACE_ENTITY check in EditorGrid)
- Positioned via `_cell_origin_world_pos()` for foundation-aware offset

### Foundation-Aware Positioning

```gdscript
func _cell_origin_world_pos(origin: Vector2i, footprint: Vector2i) -> Vector3:
    var grid_half: float = float(TerrainSystem.grid_cells) * Pathfinder.CELL_SIZE * 0.5
    var center_x := (origin.x + footprint.x * 0.5) * Pathfinder.CELL_SIZE - grid_half
    var center_z := (origin.y + footprint.y * 0.5) * Pathfinder.CELL_SIZE - grid_half
    # Find max height across foundation footprint
    var max_h := 0
    for dx in footprint.x:
        for dz in footprint.y:
            var cell := origin + Vector2i(dx, dz)
            var cell_data: Dictionary = TerrainSystem.get_cell(cell)
            if not cell_data.is_empty():
                var h: int = cell_data.get("max_height", cell_data.get("height", 0))
                if h > max_h:
                    max_h = h
    return Vector3(center_x, float(max_h) * TerrainSystem.HEIGHT_STEP, center_z)
```

### Save/Load with player_id

```gdscript
# Save
func _on_save_file_selected(path: String) -> void:
    var entities_array: Array[Dictionary] = []
    for cell_key in editor._painted_entities:
        var entry: Dictionary = editor._painted_entities[cell_key]
        var data: Dictionary = entry.get("data", {})
        var entity_entry: Dictionary = {
            "id": data.get("id", ""),
            "cell": cell_key,
        }
        if data.has("player_id"):
            entity_entry["player_id"] = data["player_id"]
        # ... override keys ...
        entities_array.append(entity_entry)
    TerrainSystem.export_to_json(path, {"entities": entities_array})

# Load (MapLoader.gd)
func load_map_into(path: String, parent: Node) -> Array[Dictionary]:
    # Reads "player_id" from JSON, defaults to 0 if missing
```

### ResourceGrowthSystem Guard

In `scripts/core/ResourceGrowthSystem.gd`, `_physics_process()` skips when MapEditor is active:
```gdscript
func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    if get_tree().current_scene and get_tree().current_scene.name == "MapEditor":
        return
    # ... growth/spread logic ...
```

## File Changes

### New Files
- `scripts/editor/EntityBrowser.gd` — Entity browser panel (always visible, left sidebar)
- `scripts/editor/EditorGrid.gd` — Grid overlay + cell highlight + height label
- `scripts/editor/EntityPlacer.gd` — Entity browser integration, preview, placement
- `scripts/editor/ResourcePainter.gd` — Tiberium brush painting/erasing
- `scripts/editor/EditorSaveLoad.gd` — File dialogs, save/load serialization

### Modified Files
- `scripts/editor/MapEditor.gd` — Refactored to orchestrate sub-scripts (752→314 lines)
- `scripts/entities/EntityFactory.gd` — Added `get_all_by_type()` method
- `scripts/maps/MapLoader.gd` — Extended to read `player_id` from JSON
- `scripts/core/ResourceGrowthSystem.gd` — Added MapEditor scene guard

### Data Changes
- Map JSON format extended with `player_id` field

## UI Layout Details

### Left Panel (EntityBrowser)
- Position: `Vector2(10, 50)` — below toolbar, left side
- Size: `Vector2(250, 500)` minimum
- Always visible (no toggle)
- Z-index: Above map viewport

### Category Tabs
- Tabs: Buildings, Infantry, Vehicles, Aircraft, Naval
- All tabs active — each filters entity list by EntityType
- Tab change refreshes entity list

### Owner Dropdown
- Position: Below category tabs
- Options: "Player 0", "Player 1" (from PlayerManager)
- Default: "Player 0"
- Change emits `player_changed` signal

### Search Bar
- Position: Below owner dropdown
- Placeholder: "Search entity..."
- Real-time filtering as user types

### Entity List
- Position: Below search bar, fills remaining panel height
- ItemList control with entity names
- Single selection mode
- Click to toggle placement mode for that entity
- Shows entity name and internal ID in parentheses

## Testing

### Unit Tests
- EntityBrowser populates list from EntityFactory
- Search filtering works correctly
- Player selection emits correct signal
- Entity selection emits correct entity_id

### Integration Tests
- Place entity creates node in scene tree
- Placed entity stored in _painted_entities with player_id
- Save includes player_id in JSON
- Load restores entity with correct player_id
- Multiple entities can be placed on different cells
- Cannot place entity on occupied cell
- Preview ghost follows cursor
- Right-click cancels placement mode
