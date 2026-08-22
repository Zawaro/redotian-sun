## Context

MapEditor (`scripts/editor/MapEditor.gd`) is a runtime tool (`get_meta("is_map_editor")`) with a toolbar built entirely in `_setup_ui()`. Existing node tools (`HeightPainter`, `ResourcePainter`, `EntityPlacer`) attach as child Nodes and receive input via `MapEditor._input` dispatch. Persistence flows through `EditorSaveLoad` → `TerrainSystem.export_to_json` (JSON v4, top-level keys `version/grid_cells/map_size/vertices/cells` + `extra_data` merge) and back via `MapLoader.load_map_into`. Gameplay camera is `BoundsSystem.camera_pivot` (a `Node3D`), currently always centered at `(0, y, 0)` by `_center_camera_on_diamond()`. Player identity comes from `PlayerManager.get_local_player_id()` (defaults to 0). Start location data does not exist anywhere today.

## Goals / Non-Goals

**Goals:**
- Author per-player start cells in the editor: assign on click, reset to the map-center cluster on erase (FinalSun semantics).
- Persist only overrides in map JSON v4 (additive, backward compatible).
- On gameplay load, frame the camera to the **local player's** start.
- Default cluster so every map (old and new) has sensible starts.

**Non-Goals:**
- Player identity authoring (which player is human, faction, etc.) — already exists as `MapConfig`/`PlayerConfig` data, out of scope (#172).
- Minimap dots for start markers, undo/redo integration, multiplayer camera behavior per client — single-local-player camera only.
- Serializing default positions — they are computed, never written.

## Decisions

**D1 — Default cluster is computed, never serialized.**
One shared function produces a player's effective start cell: `default_start_cell(player_id)` for the cluster, overridden by an optional per-player cell. Editor and loader call the same code path so they cannot drift. Defaults are derived from `TerrainSystem.grid_cells` at runtime, so grid resizes recompute correctly. Cluster offsets fixed to `[(0,0),(1,0),(0,1),(1,1),(-1,0),(0,-1),(-1,-1),(1,-1)]` truncated to the player's index — all in-diamond for 2x2 and larger grids.

**D2 — Start storage in BoundsSystem.**
`BoundsSystem` already owns `camera_pivot`, diamond math, and load-time bounds restore (`apply_saved_bounds`). Add both:
- `default_start_cell(player_id) -> Vector2i` (cluster math, shared)
- `center_camera_on_cell(cell)` (set pivot x/z, keep pivot y — matches how `_center_camera_on_diamond` only patches x/z, preserving camera height)
Everything else calls into `BoundsSystem`; one owner, all maps get camera framing for free.

**D3 — New editor node-tool `PlayerStartTool`.**
Mirrors the existing `HeightPainter`/`ResourcePainter` pattern: child Node created in `_setup_ui()`, exposes `_overrides {player_id: cell}`, `assign(player, cell)`, `reset(player)`, `save_data() -> Array[Dictionary]`, `load_data(arr)`. It owns marker meshes (one colored quad per player, `top_level` world quads like `EditorGrid`'s use of immediate meshes; color from `PlayerManager.get_player_data(player).color` when available, else a fixed palette). Toolbar wires a toggle button, dispatches in `MapEditor._input` (left=assign hovered cell, right=reset hovered if it's that player's override), and slot on New/Settings dialogs to clear overrides when the grid resizes.

**D4 — Graphics mouse pick overlay handles rejection; clicks outside the diamond are no-ops + `push_warning`.**
Reuses the existing `_update_hovered_cell` path (world→cell via `CellUtil.world_to_cell`). Guard via `CellUtil.is_in_diamond` already implicit in terrain lookup; assignment check is explicit.

**D5 — Persistence via `extra_data` (same merge as existing `visible_bounds`).**
`EditorSaveLoad` passes `{"start_locations": tool.save_data()}` into `export_to_json` (with the raw JSON key already available in v3). `MapLoader` reads it under `json.get("start_locations", [])` and, in gameplay, center-cameras to the local player's effective start (`override ?? default`). Old maps: `{} `/absent key → all defaults, no behavior change.

**D6 — Round-trip editor/loader share format.**
`start_locations` entries are `{"player_id": int, "cell": "x,y"}` — mirrors the existing `entities[].cell` key-string convention and round-trips through `MapLoader` unchanged.

**D7 — Camera pivot resolution is lazy.**
`BoundsSystem` is an autoload ready before the gameplay scene exists, so `_find_camera_pivot()` at autoload `_ready` finds nothing. Pivot resolution recurses through the tree (`find_child("Camera3D", true, false)` under each root child) and is re-run from `_ready` (deferred) and on `grid_initialized` (which fires during map load, once the scene is present). The search returns the pivot owning the `Camera3D`, matching the real `MapBase01 → Camera → Camera3D` hierarchy — the pivot can be two levels deep, so a direct-child check is insufficient.

## Risks / Trade-offs

- **Fallback drift (editor vs loader default)** → both call `BoundsSystem.default_start_cell`, single source of truth.
- **Right-click reset could erase a deliberately placed start** → gated: only resets when the clicked cell equals the currently assigned cell for the selected player; `right-click` elsewhere remains deselect/cancel.
- **Camera height preserved**: we set x/z only, never overwrite pivot `y` — keeps camera at editor/played-as-set altitude rather than snapping to zero.
- **New maps without camera framing** → default cluster cell stays centered-ish; maps that previously footed at origin are now framed to a cell near center — behavior change for no-start maps (acceptable, the point of the feature; old assets stay playable, just framed differently).
- **Marker leaks / stale state on resize** → reset overrides on `_apply_new_map`/`_apply_map_settings`; redraw markers on grid-initialize.
- **Camera not resolving in gameplay** → pivot resolution is deferred until the scene exists and re-checked on every `grid_initialized`; a regression test builds the real pivot hierarchy and asserts resolution + framing.

## Migration Plan

1. Land `BoundsSystem` additions first (pure, testable).
2. `PlayerStartTool` + `MapEditor` wiring.
3. `EditorSaveManager` persistence (backward compatible — writes column only when overrides exist).
4. `MapLoader` read + gameplay camera framing.
No schema version bump — JSON v3 stays v3; `start_locations` is additive.