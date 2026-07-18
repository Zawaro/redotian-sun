# Entity Placement Spec

## Overview

Entity placement allows map editors to place game entities (buildings, infantry, vehicles) on the map with player assignment. This is essential for setting up starting conditions, mission scenarios, and test maps.

## Requirements

### Functional Requirements

1. **Entity Type Selection**
   - User can select entity type from a list in the left sidebar panel
   - List is populated from EntityFactory.get_all_by_type()
   - Filtered by entity category (Buildings, Infantry, Vehicles, Aircraft, Naval)
   - Searchable by name or ID
   - Click to toggle placement mode; click same entity to deselect

2. **Player Assignment**
   - User can select player/owner from dropdown in entity browser
   - Dropdown populated from PlayerManager
   - Default to Player 0
   - Each placed entity stores `player_id` in metadata

3. **Entity Placement**
   - Click map cell to place selected entity
   - Entity created via EntityFactory.create_entity()
   - Single-cell entities positioned at cell center
   - Multi-cell entities (buildings) positioned via `_cell_origin_world_pos()` to account for foundation footprint
   - Cannot place on occupied cells (checks `_painted_entities` dictionary)
   - Entity added to scene tree
   - Right-click cancels placement mode

4. **Preview Ghost**
   - 50% opacity entity follows cursor before placement
   - Uses `_set_preview_transparency()` to recursively apply alpha to all MeshInstance3D nodes
   - Positioned with foundation-aware offset for multi-cell buildings
   - Hidden during height painting (PLACE_ENTITY mode check)

5. **Data Persistence**
   - Placed entities stored in `_painted_entities` dictionary
   - Key format: `"x,y"` (cell coordinates)
   - Value: `{"node": Node3D, "data": Dictionary}`
   - Data includes: `id`, `player_id`, optional overrides

6. **Save/Load**
   - Save includes `player_id` field in JSON
   - Load restores entity with correct player assignment
   - Backward compatible with existing maps (no player_id = Player 0)

### Non-Functional Requirements

1. **Performance**
   - Entity list population < 100ms
   - Entity placement < 16ms (60fps)
   - Search filtering < 50ms

2. **Usability**
   - Industry standard UI pattern (WAE, OpenRA)
   - Intuitive workflow: select player → select entity → click to place
   - Visual feedback on cell hover (preview ghost)
   - Clear indication of selected entity and player
   - Right-click to cancel placement

3. **Extensibility**
   - Support for additional entity categories (infantry, vehicles, aircraft, naval)
   - Support for additional player properties (faction, color)
   - Support for entity overrides (health, facing, mission)

## Data Model

### Entity Entry

```gdscript
{
    "id": "GACNST",           # Entity type ID
    "cell": "15,20",          # Cell coordinates
    "player_id": 0,           # Owner player ID
    "strength": 256,          # Optional: health override
    "facing": 0,              # Optional: facing override
    "mission": "Guard",       # Optional: mission override
}
```

### Map JSON Format

```json
{
    "entities": [
        {
            "id": "TIB",
            "cell": "5,10",
            "strength": 300
        },
        {
            "id": "GACNST",
            "cell": "15,20",
            "player_id": 0
        },
        {
            "id": "BGGY",
            "cell": "25,20",
            "player_id": 1
        }
    ]
}
```

## API Changes

### EntityFactory

```gdscript
# New method
func get_all_by_type(entity_type: EntityData.EntityType) -> Array[EntityData]:
    # Returns array of EntityData for all entities of given type
    # Example: get_all_by_type(EntityData.EntityType.BUILDING) returns all buildings

# Existing method (used for preview/placement)
func get_entity_data(entity_id: String) -> EntityData:
    # Returns EntityData for given entity ID

func create_entity(entity_id: String, overrides: Dictionary = {}) -> Node3D:
    # Creates entity instance with optional overrides
```

### MapEditor (via EntityPlacer sub-script)

```gdscript
# Tool enum
enum Tool { NONE, PAINT_HEIGHT, PAINT_RESOURCE, PLACE_TREE, ERASE, PLACE_ENTITY }

# EntityPlacer methods
func _on_entity_selected(entity_id: String) -> void
func _on_player_changed(player_id: int) -> void
func _place_entity_on_cell(cell: Vector2i) -> void
func _update_preview() -> void
func _update_preview_position() -> void
func _remove_preview() -> void
func handle_input(event: InputEvent) -> void
func handle_tree_input(event: InputEvent) -> void

# MapEditor position helpers
func _cell_world_pos(cell: Vector2i) -> Vector3
func _cell_origin_world_pos(origin: Vector2i, footprint: Vector2i) -> Vector3
```

### MapLoader

```gdscript
# Extended to read player_id
func load_map_into(path: String, parent: Node) -> Array[Dictionary]:
    # Reads "player_id" from JSON entities, defaults to 0 if missing
```

## UI Components

### EntityBrowser

- **Location**: Left sidebar panel (always visible)
- **Size**: 250px wide, 500px minimum height
- **Components**:
  - CategoryTabs (TabBar) — Buildings, Infantry, Vehicles, Aircraft, Naval
  - OwnerDropdown (OptionButton) — Player 0, Player 1
  - SearchBar (LineEdit) — real-time filtering
  - EntityList (ItemList) — single-click to toggle placement

### Toolbar Integration

- **No dedicated "Place Entity" button** — entity selection via browser panel
- **Existing tools**: Save, Load, Paint Height, Paint Resource, Place Tree, Erase
- **Controls**: Strength slider, Radius spinbox, Grid toggle checkbox, Height label

## Testing Strategy

### Unit Tests

1. EntityBrowser populates list from EntityFactory
2. Search filtering returns correct results
3. Player selection emits correct signal
4. Entity selection emits correct entity_id

### Integration Tests

1. Place entity creates node in scene tree
2. Placed entity stored with player_id
3. Save includes player_id in JSON
4. Load restores entity with correct player_id
5. Cannot place entity on occupied cell
6. Multiple entities can be placed
7. Preview ghost follows cursor
8. Right-click cancels placement mode
9. Foundation-aware positioning for multi-cell buildings

### Manual Testing

1. Open MapEditor scene
2. Select Player 1 from Owner dropdown
3. Select Construction Yard from Buildings list
4. Verify preview ghost follows cursor
5. Click map to place entity
6. Verify entity appears with correct player assignment
7. Right-click to cancel, verify placement mode exits
8. Save and reload map
9. Verify entity persists with player assignment

## Dependencies

- PlayerManager (#77) for player data
- EntityFactory for entity creation
- MapLoader for save/load integration
- TerrainSystem for cell height data

## Future Enhancements

1. Entity rotation (facing) control
2. Entity property editing (health, mission)
3. Spawn point markers
4. Undo/redo for entity placement
5. Minimap entity rendering
