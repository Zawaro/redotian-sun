## ADDED Requirements

### Requirement: TerrainSystem singleton shall manage global terrain state
The TerrainSystem SHALL be registered as an autoload singleton in project.godot and act as the central data store for all terrain. It owns the vertex grid (canonical data) and maintains a cell cache (derived view).

#### Scenario: TerrainSystem is accessible from any script
- **WHEN** any script calls `TerrainSystem.get_cell(Vector2i(0, 0))`
- **THEN** the system returns the cell data for that position or an empty Dictionary if the position has no terrain

#### Scenario: Vertex state is queryable
- **WHEN** any script calls `TerrainSystem.get_vertex(5, 3)`
- **THEN** the system returns the integer height at that vertex coordinate

### Requirement: Terrain shall use a fixed-size vertex grid
The TerrainSystem SHALL allocate a 2D array of vertex heights sized (`GRID_CELLS + 1`) × (`GRID_CELLS + 1`). The default grid is 32×32 cells = 33×33 vertices. Each vertex stores an integer height (0–10).

#### Scenario: Grid initialization
- **WHEN** TerrainSystem initializes with default settings
- **THEN** a 33×33 vertex grid is created, all vertices at height 0

#### Scenario: Vertex addressing
- **WHEN** vertex (vx, vz) is accessed
- **THEN** its world position is (vx * CELL_SIZE, height * HEIGHT_STEP, vz * CELL_SIZE)

### Requirement: Vertex heights shall be integer, normalized by HEIGHT_STEP
Each vertex stores an integer height level. The world Y position is calculated as `height * HEIGHT_STEP` where HEIGHT_STEP = 0.815. CELL_SIZE = 2.0, MAX_HEIGHT = 10.

#### Scenario: Height to world conversion
- **WHEN** a vertex at (3, 5) has height 2
- **THEN** its world Y position is 2 * 0.815 = 1.63

### Requirement: Cell data shall be derived from 4 corner vertices
Each cell's type, variant, direction, rotation, and base height SHALL be computed purely from the heights of its 4 corner vertices. A cell at grid position (cx, cz) uses vertices at (cx, cz), (cx+1, cz), (cx, cz+1), and (cx+1, cz+1).

#### Scenario: Cell corner vertices
- **WHEN** cell (3, 5) is queried
- **THEN** its data is computed from vertices (3,5), (4,5), (3,6), (4,6)

#### Scenario: Cell base height
- **WHEN** a cell's 4 vertices have heights [2, 3, 2, 2]
- **THEN** the cell's base height is 2 (the minimum of all 4)

#### Scenario: Empty cell returns empty Dictionary
- **WHEN** a cell outside the grid bounds is queried
- **THEN** an empty Dictionary is returned

### Requirement: Cell type shall be determined by corner height pattern
Given a cell's 4 corner heights [v00, v10, v01, v11] relative to base height H (the minimum):

| Pattern (v00,v10,v01,v11) | Count raised | Type | Variant | Description |
|---|---|---|---|---|
| 0,0,0,0 | 0 | clear | 1 | Flat quad at H |
| 1,0,0,0 | 1 | slope | 2 | Outer corner, high at TL |
| 0,1,0,0 | 1 | slope | 2 | Outer corner, high at TR |
| 0,0,1,0 | 1 | slope | 2 | Outer corner, high at BL |
| 0,0,0,1 | 1 | slope | 2 | Outer corner, high at BR |
| 1,1,0,0 | 2 adjacent | slope | 1 | Single ramp, top edge high |
| 0,0,1,1 | 2 adjacent | slope | 1 | Single ramp, bottom edge high |
| 1,0,1,0 | 2 adjacent | slope | 1 | Single ramp, left edge high |
| 0,1,0,1 | 2 adjacent | slope | 1 | Single ramp, right edge high |
| 1,0,0,1 | 2 opposite | slope | 5 | Saddle A (high TL+BR) |
| 0,1,1,0 | 2 opposite | slope | 6 | Saddle B (high TR+BL) |
| 1,1,1,0 | 3 | slope | 3 | Inner corner, BL low |
| 1,1,0,1 | 3 | slope | 3 | Inner corner, BR low |
| 1,0,1,1 | 3 | slope | 3 | Inner corner, TR low |
| 0,1,1,1 | 3 | slope | 3 | Inner corner, TL low |
| 1,1,1,1 | 4 | clear | 1 | Flat quad at H+1 |
| Any corner at 2 (e.g. 2,1,1,1) | varies | slope | 4 | Double ramp, direction toward max |

#### Scenario: All vertices same height → clear01
- **WHEN** all 4 corners of a cell have height 3
- **THEN** the cell is type "clear", variant 1, base height 3

#### Scenario: One corner higher → slope02
- **WHEN** cell corners are [3, 2, 2, 2] (TL raised)
- **THEN** the cell is type "slope", variant 2 (outer corner)

#### Scenario: Two adjacent corners higher → slope01
- **WHEN** cell corners are [2, 3, 2, 3] (top and right edges raised — adjacent)
- **THEN** the cell is type "slope", variant 1 (single ramp)

#### Scenario: Two opposite corners higher → saddle
- **WHEN** cell corners are [3, 2, 2, 3] (TL and BR raised — opposite)
- **THEN** the cell is type "slope", variant 5 (saddle A)

#### Scenario: Three corners higher → slope03
- **WHEN** cell corners are [3, 3, 2, 3] (only BL at base)
- **THEN** the cell is type "slope", variant 3 (inner corner)

#### Scenario: Corner at relative height 2 → slope04
- **WHEN** cell corners are [3, 2, 2, 2] with TL at 3 vs base 1... actually [2, 1, 1, 1] relative
- Wait, more precisely: corners [3, 2, 2, 2] where base H=2, so relative [1,0,0,0] → slope02
- For slope04: corners [3, 2, 2, 1] where base H=1, relative [2,1,1,0] → slope04
- **THEN** the cell is type "slope", variant 4 (double ramp)

### Requirement: Direction and rotation shall be derived from vertex pattern
Each slope variant maps to a direction string and Y-rotation based on which corners are raised:

| Variant | Pattern | Direction | Y Rotation |
|---------|---------|-----------|------------|
| 1 (ramp) | Top edge high (v00,v10) | north | 0° |
| 1 (ramp) | Bottom edge high (v01,v11) | south | 180° |
| 1 (ramp) | Left edge high (v00,v01) | west | 90° |
| 1 (ramp) | Right edge high (v10,v11) | east | 270° |
| 2 (outer) | TL high (v00) | west | 90° |
| 2 (outer) | TR high (v10) | north | 0° |
| 2 (outer) | BL high (v01) | south | 180° |
| 2 (outer) | BR high (v11) | east | 270° |
| 3 (inner) | TL low (v00) | north | 0° |
| 3 (inner) | TR low (v10) | east | 270° |
| 3 (inner) | BL low (v01) | west | 90° |
| 3 (inner) | BR low (v11) | south | 180° |
| 4 (double) | Direction toward the highest corner | — | — |
| 5 (saddle A) | TL+BR high | west | 90° |
| 6 (saddle B) | TR+BL high | east | 270° |

#### Scenario: Slope direction matches rotation
- **WHEN** a slope has direction "north"
- **THEN** rotation.y = 0° (north=0°, east=270°, south=180°, west=90°)

### Requirement: Vertex-to-vertex cascade shall enforce ±1 height constraint
When a vertex changes height, the system SHALL propagate the change to adjacent vertices (4-axis: N, S, E, W) if the height difference exceeds 1. Each affected vertex is adjusted by ±1 toward equality and recursively checked.

#### Scenario: Raising vertex cascades outward
- **WHEN** vertex (5, 5) is raised from height 0 to 3
- **THEN** its neighbor (5, 6) is raised to 1, then (5, 7) is raised to 2, cascading until max diff ≤ 1

#### Scenario: Cascade is 4-directional only
- **WHEN** cascade propagates
- **THEN** only N, S, E, W vertex neighbors are checked (not diagonal)

#### Scenario: No opposite-cardinal or diagonal rules needed
- **WHEN** cascade runs
- **THEN** no special rules are applied — the ±1 constraint alone determines propagation

### Requirement: Cascade shall execute as single batch with deferred signals
All vertex height changes and cell recomputations SHALL complete before any `cell_changed` signal is emitted. Each affected cell emits exactly once.

#### Scenario: No premature rendering during cascade
- **WHEN** a vertex is changed by the cascade
- **THEN** no `cell_changed` signal is emitted until all cascade phases complete

#### Scenario: Batch emission includes all affected cells
- **WHEN** cascade affects 5 vertices and 12 cells
- **THEN** exactly 12 `cell_changed` signals are emitted with final cell data

### Requirement: System shall expose raise_cell and lower_cell methods
The system SHALL provide `raise_cell(cell: Vector2i)` and `lower_cell(cell: Vector2i)` methods that modify all 4 vertex heights of a cell by ±1 (clamped to 0–MAX_HEIGHT) and trigger a single cascade batch.

#### Scenario: Raising a cell
- **WHEN** `TerrainSystem.raise_cell(Vector2i(3, 5))` is called
- **THEN** all 4 vertices of cell (3,5) are incremented by 1 (capped at MAX_HEIGHT), then cascade runs

#### Scenario: Lowering a cell
- **WHEN** `TerrainSystem.lower_cell(Vector2i(3, 5))` is called
- **THEN** all 4 vertices of cell (3,5) are decremented by 1 (floored at 0), then cascade runs

#### Scenario: Direct vertex mutation bypasses raise/lower
- **WHEN** `TerrainSystem.set_vertex(5, 3, 4)` is called
- **THEN** a single vertex is directly set to height 4, then cascade runs from that vertex

### Requirement: Cell cache shall store computed data
The system SHALL maintain a Dictionary caching computed cell data. Cached per cell: { "height": int, "type": String, "variant": int, "direction": String, "rotation": float }. The cache is rebuilt from vertices after any cascade.

#### Scenario: Cache is read-only
- **WHEN** an external script modifies cell data via `set_cell()`
- **THEN** the call is a no-op (cells are derived from vertices, not directly settable)

#### Scenario: Cache is emptied on grid reset
- **WHEN** `TerrainSystem.clear()` is called
- **THEN** the vertex grid and cell cache are reset to defaults

#### Scenario: init_grid reinitializes grid
- **WHEN** `TerrainSystem.init_grid(64)` is called
- **THEN** the vertex grid is reallocated to the new size (old data lost), existing cell cache persists until explicitly cleared

#### Scenario: get_all_cells returns deep copy
- **WHEN** `TerrainSystem.get_all_cells()` is called
- **THEN** the returned Dictionary is a deep copy — mutations to nested cell dictionaries do not affect internal state

### Requirement: System shall export terrain to JSON
The TerrainSystem SHALL export terrain to JSON format including both vertex data and cached cell data.

```json
{
    "version": 2,
    "grid_cells": 32,
    "vertices": {
        "vx,vz": height_int
    },
    "cells": {
        "cx,cz": {
            "height": int,
            "type": "clear"|"slope",
            "variant": int,
            "direction": "north"|"south"|"east"|"west",
            "rotation": float
        }
    }
}
```

- `vertices`: stores only non-zero height vertices (sparse storage). Default is 0.
- `cells`: pre-computed cell data cache for fast loading. Recomputable from vertices.

#### Scenario: Exporting terrain to file
- **WHEN** `TerrainSystem.export_to_json("res://maps/test.json")` is called
- **THEN** a JSON file is written containing vertex grid, cell cache, and metadata

#### Scenario: Non-zero vertices only
- **WHEN** terrain has 5 raised vertices out of 1089 total (33×33)
- **THEN** the JSON only stores those 5 vertex entries, not all 1089

#### Scenario: Import clears and rebuilds
- **WHEN** terrain is imported from JSON
- **THEN** existing grid is cleared, vertex heights are loaded, and cell cache is recomputed from vertices

### Requirement: System shall provide cell queries for external consumers
Existing terrain consumers (Pathfinder, MovementController, Minimap) SHALL use the same `get_cell()`, `get_cell_at_world()`, `get_height_at_world()`, `get_all_cells()` API. No changes needed to consumers.

#### Scenario: Pathfinder height query
- **WHEN** `Pathfinder.find_path()` calls `TerrainSystem.get_cell()`
- **THEN** it receives the same cell data format as before

#### Scenario: Movement controller Y-interpolation
- **WHEN** `MovementController._interpolate_height()` calls `TerrainSystem.get_cell()`
- **THEN** it receives cell data with type, height, direction — unchanged interface

### Requirement: System shall emit signals on terrain changes
The TerrainSystem SHALL emit `cell_changed(cell_key: String, cell_data: Dictionary)` for each affected cell after a cascade completes.

#### Scenario: Signal emitted after batch cascade
- **WHEN** a cascade completes affecting 12 cells
- **THEN** 12 `cell_changed` signals are emitted

#### Scenario: set_vertex triggers cascade and signals
- **WHEN** `TerrainSystem.set_vertex(5, 3, 4)` is called
- **THEN** cascade runs and affected cells emit `cell_changed`

### Requirement: Cliff system slot shall exist for future use
The architecture SHALL support future cliff overrides via a separate table mapping vertex positions to { bottom_h, top_h }. Vertices are single-valued by default; cliffs override specific vertex indices with a second height.

#### Scenario: Cliff data structure placeholder
- **WHEN** a future cliff system is added
- **THEN** cliff overrides are stored in a separate `_cliff_overrides: Dictionary` mapping "(vx,vz)" → { "bottom": int, "top": int }