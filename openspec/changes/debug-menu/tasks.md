## 1. LightingControls

- [ ] 1.1 Create `scripts/environment/LightingControls.gd` — Node3D script with 9 @export fields: sun_elevation (0-90), sun_rotation (0-360), sun_intensity (0-5), sun_color (Color), shadow_strength (0-1), ambient_light (0-2), fog_density (0-0.01), sky_rotation (-1 to 1), glow_intensity (0-2). Default values matching scene files.
- [ ] 1.2 Implement `apply_to_scene()` method — reads @export fields and applies to LightPivot (rotation), DirectionalLight3D (energy, color, shadow), WorldEnvironment (ambient, fog, sky_rotation, glow). Uses node paths to find siblings.
- [ ] 1.3 Implement `get_defaults() -> Dictionary` — returns current @export values for UI initialization.
- [ ] 1.4 Add LightingControls node to `scenes/maps/MapBase01.tscn` — Node3D child with LightingControls.gd script.

## 2. Debug Overlays (extend DebugVisualizer)

- [ ] 2.1 Add 5 boolean @export flags to `scripts/core/DebugVisualizer.gd`: show_spatial_hash, show_entity_bounds, show_health_bars, show_entity_ids. Keep existing enabled flag for pathfinding.
- [ ] 2.2 Implement `_process()` in DebugVisualizer — iterate `get_tree().get_nodes_in_group("entities")` and call drawing methods for enabled overlays.
- [ ] 2.3 Implement `draw_spatial_hash()` — draw grid lines and occupancy count labels using ImmediateMesh. Read from SpatialHashSingleton.
- [ ] 2.4 Implement `draw_entity_bounds()` — draw selection box outlines per entity using FoundationComponent.cell_size for buildings and default 1x1 for non-buildings.
- [ ] 2.5 Implement `draw_health_bars()` — draw ColorRect bar above each entity, width proportional to health ratio, color: green (>60%), yellow (30-60%), red (<30%). Use CanvasItem for 2D overlay.
- [ ] 2.6 Implement `draw_entity_ids()` — draw Label above each entity showing StatsComponent.display_name + id. Use CanvasItem for 2D text.
- [ ] 2.7 Implement `clear_all_overlays()` — clear all debug meshes and canvas items.

## 3. Debug Menu Panel

- [ ] 3.1 Create `scenes/ui/DebugMenu.tscn` — Outer Control (full-rect, MOUSE_FILTER_PASS) containing inner Content rect (400px wide, left-anchored, dark semi-transparent background, MOUSE_FILTER_STOP). VBoxContainer inside content with 4 header Buttons + content VBoxContainers.
- [ ] 3.2 Create `scripts/ui/DebugMenu.gd` — Panel controller script. Handles backtick key toggle, accordion section collapse/expand, stores toggle state persistently.
- [ ] 3.3 Implement `_input()` for click routing — check if click position is inside 400px content rect. If inside, consume event. If outside, let pass through.
- [ ] 3.4 Implement Overlays section — 5 checkboxes bound to DebugVisualizer flags: Pathfinding lines, Spatial hash grid, Entity bounds, Health bars, Entity IDs.
- [ ] 3.5 Implement Lighting section — 9 sliders/pickers bound to LightingControls @export fields. Initialize from LightingControls.get_defaults().
- [ ] 3.6 Implement Cheats section — 4 checkboxes (No prerequisites, No build time, No cost, Place anywhere) + 2 buttons (Clear All Paths, Add 100k Credits) + debug stats label (entity counts by EntityType, FPS, spatial hash occupancy %).
- [ ] 3.7 Implement Inspect section — empty by default. When entity clicked, expand and display all exported properties from all attached components using get_property_list() + get(), grouped by component name.
- [ ] 3.8 Implement `inspect_entity(entity: Node3D)` method — called by MouseHandler when entity clicked while debug panel open. Populates Inspect section.
- [ ] 3.9 Implement scene change reset — on `_ready()`, reset all overlay checkboxes and cheat toggles to defaults.
- [ ] 3.10 Add DebugMenu instance to `scenes/maps/MapBase01.tscn` — Under UI node, alongside Sidebar.
- [ ] 3.11 Add `toggle_debug` input action to `project.godot` — KEY_QUOTELEFT (backtick/grave key).

## 4. Cheat Mode Integration

- [ ] 4.1 Update `scripts/core/PrerequisiteSystem.gd` — In `can_build()`, check `DebugMenu.no_prereqs` flag via group reference. If true, return true immediately (bypasses both prerequisites and build_limit).
- [ ] 4.2 Update `scripts/economy/EconomyManager.gd` — In `deduct()`, check `DebugMenu.no_cost` flag. If true, no-op (return true). Add `add_credits(player_id, amount, reason)` method.
- [ ] 4.3 Update `scripts/production/ProductionManager.gd` — In `_process()`, check `DebugMenu.no_build_time` flag. If true, set item.progress to 1.0 to trigger immediate completion via existing code path.
- [ ] 4.4 Update `scripts/ui/Sidebar.gd` — In `_get_current_entities()`, check `DebugMenu.no_prereqs` flag. If true, skip PrerequisiteSystem.can_build() check and show all entities.
- [ ] 4.5 Update `scripts/hud/MouseHandler.gd` — When debug panel is open and entity is clicked, call `DebugMenu.inspect_entity(entity)`. Use group reference to find DebugMenu.

## 5. Testing

- [ ] 5.1 Create `test/unit/test_debug_menu.gd` — Tests for: toggle state persistence, cheat flag defaults, overlay flag defaults, LightingControls apply roundtrip, entity inspection property discovery.
- [ ] 5.2 Run full test suite — `redot --headless --quit-after 30 -s test/run_tests.gd`
- [ ] 5.3 Run linter — `gdlint scripts/**/*.gd` and `gdformat --check scripts/**/*.gd`
