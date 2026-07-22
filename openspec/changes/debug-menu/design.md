## Context

The project has 12 autoloads, 37 scenes, and ~50 scripts. Debugging currently requires external tools or code changes. The game has a Sidebar (right-anchored, always visible), a MapBase01 scene that all maps inherit from, and no existing debug UI.

Key existing systems:
- `DebugVisualizer` — draws pathfinding lines via ImmediateMesh
- `SpatialHashSingleton` — spatial partitioning, no visual overlay
- `EntityFactory` — creates entities, does not track instances (use `get_tree().get_nodes_in_group("entities")`)
- `PrerequisiteSystem` — gates build menu on owned buildings
- `ProductionManager` — handles production queue with per-frame progress
- `EconomyManager` — credit tracking with deduct/add methods
- `BuildingManager` — placement validation and preview

## Goals / Non-Goals

**Goals:**
- Debug panel toggled with backtick key, top-left dropdown, 400px wide
- 5 overlay types: pathfinding, spatial hash, entity bounds, health bars, entity IDs
- 9 lighting controls: sun elevation/rotation/intensity/color, shadow, ambient, fog, sky rotation, glow
- 4 cheat toggles: no prereqs, no build time, no cost, place anywhere
- 2 action buttons: clear paths, add 100k credits
- Entity click-to-inspect showing all component data dynamically

**Non-Goals:**
- Live-editing entity fields (v2)
- MapEditor lighting integration (future phase)
- Pause game when panel is open
- Customizable panel position/size
- Separate LightingData resource class (inline on LightingControls for now)

## Decisions

### D1: DebugMenu access pattern

**Choice**: Scene instance under UI in MapBase01.tscn. Other systems access it via `get_tree().get_first_node_in_group("debug_menu")`.

**Rationale**: DebugMenu is UI — it belongs in the scene tree, not as a global singleton. Using a group reference keeps it decoupled from autoload order. The group is added in DebugMenu._ready().

### D2: Input handling

**Choice**: DebugMenu uses a two-layer Control structure:
- Outer Control: full-rect, `mouse_filter = MOUSE_FILTER_PASS` (allows clicks to pass through)
- Inner Content rect: 400px wide, `mouse_filter = MOUSE_FILTER_STOP` (captures clicks inside panel)

DebugMenu checks mouse position against the content rect in `_input()` to determine if a click is inside the panel. If inside, consume event. If outside, let it pass through to MouseHandler.

**Rationale**: MOUSE_FILTER_PASS on the outer Control prevents it from eating all clicks. The inner rect with MOUSE_FILTER_STOP handles panel interactions. `_input()` checks position for game-level click routing.

**Alternative considered**: Full-rect with MOUSE_FILTER_STOP — rejected because it eats all clicks, preventing entity inspection.

### D3: Entity inspection click flow

**Choice**: DebugMenu registers itself with MouseHandler. When debug panel is open and an entity is clicked, MouseHandler notifies DebugMenu with the clicked entity node. DebugMenu then populates the Inspect section.

**Rationale**: MouseHandler already does raycasting for entity selection. DebugMenu doesn't need its own raycast — it piggybacks on the existing selection flow. MouseHandler calls `DebugMenu.inspect_entity(entity)` when an entity is clicked while the debug panel is open.

### D4: Cheat flag ownership

**Choice**: DebugMenu.gd owns the 4 boolean flags (`no_prereqs`, `no_cost`, `no_build_time`, `placeAnywhere`). Other systems read these flags via group reference.

**Rationale**: No other system needs to query "is cheat mode on" except the ones DebugMenu directly modifies. The flags are read-only from the perspective of other systems.

### D5: Overlay rendering

**Choice**: Extend DebugVisualizer with overlay toggle flags and drawing methods for all 5 overlay types. DebugVisualizer already handles pathfinding lines — add spatial hash grid, entity bounds, health bars, and entity IDs as additional drawing methods.

**Rationale**: DebugVisualizer is the existing debug visualization system. Adding more overlay types to it keeps one file with toggle flags rather than creating a separate system with overlapping concerns.

### D6: Overlay rendering frequency

**Choice**: Every frame in `_process()`. Iterate `get_tree().get_nodes_in_group("entities")` and draw enabled overlays.

**Rationale**: Entity count is in the hundreds. Redrawing 200 health bars + labels per frame is trivial. Correctness matters more than performance for debug tools.

### D7: Lighting properties

**Choice**: 9 `@export` fields stored directly on LightingControls.gd. No separate LightingData resource class. Methods: `apply_from_controls()` (reads fields, applies to scene nodes), `get_data() -> Dictionary` (returns current values as dict for serialization).

**Rationale**: Only one consumer (debug panel) in v1. When MapEditor/MapLoader need lighting data, extract to LightingData resource then. YAGNI for now.

### D8: Instant production

**Choice**: When `no_build_time` is enabled, set `build_time` override to 0 on the entity data before production starts. ProductionManager already has `if build_time <= 0.0: _complete_item()` — this path is already implemented.

**Rationale**: Leverages existing code path. No need to multiply delta by 999 or modify the progress loop.

### D9: Accordion implementation

**Choice**: VBoxContainer with 5 header Buttons + content VBoxContainers. Toggle content visibility on button press. Simple, no custom class needed.

**Rationale**: Godot has no built-in Accordion. A Button that toggles sibling visibility is ~5 lines of code. No need for a CollapsibleSection class.

## Risks / Trade-offs

- **[Performance]** Drawing 5 overlays every frame for 200+ entities → Mitigation: Only draw enabled overlays. Use ImmediateMesh for lines, ColorRect for bars, Label for text. Profile before optimizing.
- **[Input conflicts]** Backtick key might conflict with text input fields → Mitigation: Use `_input()` with explicit position check against panel rect, not `_gui_input()`.
- **[LightingControls node placement]** Must find LightPivot/WorldEnvironment at runtime → Mitigation: Use node paths from MapBase01 (LightPivot and WorldEnvironment are siblings).
- **[Cheat flag persistence]** DebugMenu must survive panel close/open cycles → Mitigation: Flags are on the DebugMenu node itself, not on panel UI children. Node persists in tree.
- **[Entity inspection integration]** DebugMenu must receive clicked entity from MouseHandler → Mitigation: MouseHandler calls DebugMenu.inspect_entity() when debug panel is open.
