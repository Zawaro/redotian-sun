## 1. LightingControls

- [x] 1.1 Create `scripts/environment/LightingControls.gd` — Node3D script with 9 @export fields: sun_elevation (0-90), sun_rotation (0-360), sun_intensity (0-5), sun_color (Color), shadow_strength (0-1), ambient_light (0-2), fog_density (0-0.01), sky_rotation (-1 to 1), glow_intensity (0-2). Default values matching scene files.
- [x] 1.2 Implement `_apply_sun()`, `_apply_shadow()`, `_apply_environment()` methods — reads @export fields and applies to LightPivot (rotation), DirectionalLight3D (energy, color, shadow), WorldEnvironment (ambient, fog, sky_rotation, glow). Uses `_find_node()` to find siblings.
- [x] 1.3 Implement `get_defaults() -> Dictionary` — captures scene's initial values via `_capture_scene_defaults()` and returns them for UI initialization.
- [x] 1.4 Add LightingControls node to `scenes/maps/MapBase01.tscn` — Node3D child with LightingControls.gd script.

## 2. Debug Overlays (extend DebugVisualizer)

- [x] 2.1 Add 6 boolean @export flags to `scripts/core/DebugVisualizer.gd`: show_spatial_hash, show_entity_bounds, show_health_bars, show_entity_ids, show_occupied_cells. Keep existing enabled flag for pathfinding.
- [x] 2.2 Implement `_process()` in DebugVisualizer — calls drawing methods for enabled overlays, cleans up meshes when disabled.
- [x] 2.3 Implement `_draw_spatial_hash()` — draw grid lines using ImmediateMesh. Read from SpatialHashSingleton._grid.
- [x] 2.4 Implement `_draw_entity_bounds()` — draw selection box outlines per entity using FoundationComponent.cell_size for buildings and default 1x1 for non-buildings.
- [x] 2.5 ~~Implement `draw_health_bars()`~~ Replaced: Health bars now toggle `SelectionOverlay` visibility instead of duplicating with ColorRect pool. Health text included in entity ID labels.
- [x] 2.6 Implement `_draw_entity_ids()` — draw Label above each entity showing StatsComponent.display_name, id, and health (current/max). Uses CanvasItem for 2D text.
- [x] 2.7 Implement `clear_all()` and `_clear_overlay_mesh()` / `_clear_bounds_meshes()` — clear all debug meshes when overlays are disabled.

## 3. Debug Menu Panel

- [x] 3.1 Create `scenes/ui/DebugMenu.tscn` — Outer Control (full-rect, MOUSE_FILTER_PASS) containing inner Content rect (400px wide, left-anchored, 10px margin, dark panel, MOUSE_FILTER_STOP). VBoxContainer inside content with 4 header Buttons + content VBoxContainers.
- [x] 3.2 Create `scripts/ui/DebugMenu.gd` — Panel controller script. Handles backtick key toggle (_input with KEY_QUOTELEFT), accordion section collapse/expand, scene change reset via _on_node_added.
- [x] 3.3 Implement input routing — Content panel uses MOUSE_FILTER_STOP to capture clicks inside, DebugMenu root uses MOUSE_FILTER_PASS to let clicks outside pass through.
- [x] 3.4 Implement Overlays section — 6 checkboxes bound to DebugVisualizer flags: Pathfinding lines, Spatial hash grid, Entity bounds, Health bars, Entity IDs + Health, Occupied cells.
- [x] 3.5 Implement Lighting section — 8 sliders + ColorPickerButton bound to LightingControls @export fields. Initialize from LightingControls._capture_scene_defaults().
- [x] 3.6 Implement Cheats section — 4 checkboxes (No prerequisites, No build time, No cost, Place anywhere) + 2 buttons (Clear All Paths, Add 100k Credits) + stats label (entity counts by EntityType, FPS).
- [x] 3.7 Implement Inspect section — selection-driven via SelectionManager.selection_changed signal. Shows health summary + all component properties dynamically.
- [x] 3.8 ~~Implement `inspect_entity()`~~ Replaced: Inspection driven by `SelectionManager.selection_changed` signal. No separate click handler needed.
- [x] 3.9 Implement scene change reset — on `_on_node_added()`, reset all overlay checkboxes, cheat toggles, and clear inspection.
- [x] 3.10 Add DebugMenu instance to `scenes/maps/MapBase01.tscn` — Under root node, alongside LightingControls.
- [x] 3.11 Add `toggle_debug` input action to `project.godot` — KEY_QUOTELEFT (backtick/grave key).

## 4. Cheat Mode Integration

- [x] 4.1 Update `scripts/production/PrerequisiteSystem.gd` — In `can_build()`, check `DebugMenu.no_prereqs` flag via group reference. If true, return true immediately.
- [x] 4.2 Update `scripts/economy/EconomyManager.gd` — In `deduct()`, check `DebugMenu.no_cost` flag. If true, no-op (return true).
- [x] 4.3 ~~Update `scripts/production/ProductionManager.gd`~~ Replaced: `_spawn_unit()` now routes through `EntityPlacer.place_entity()`. No_build_time handled by setting progress to 1.0 in existing code path.
- [x] 4.4 Update `scripts/ui/Sidebar.gd` — In `_get_current_entities()`, check `_debug_place_mode` flag. If true, skip PrerequisiteSystem.can_build() check and show all entities. Debug placement uses EntityPlacer.
- [x] 4.5 ~~Update `scripts/hud/MouseHandler.gd`~~ Replaced: `inspect_entity` call removed. Entity inspection driven by SelectionManager instead.

## 5. Testing

- [x] 5.1 Create `test/unit/test_debug_menu.gd` — Tests for: toggle state persistence, cheat flag defaults, overlay flag defaults, LightingControls apply roundtrip, entity inspection property discovery.
- [x] 5.2 Run full test suite — 258 tests pass.
- [x] 5.3 Run linter — `gdlint` and `gdformat --check` clean on all changed files.

## Extras (not in original spec)

- [x] EntityPlacer singleton — Centralized entity placement with inert preview system, material storage/restoration.
- [x] Occupied cells overlay — Green for building cells, red for blocked (idle unit) cells.
- [x] Shadow blur fix — Removed incorrect 10× multiplier in LightingControls._apply_shadow().
- [x] `.uid` files convention added to AGENTS.md.
