## Why

The MapEditor has no way to author player start locations, so gameplay always drops the camera at world origin `(0,0)` regardless of map design. Finishing this completes the map authoring loop from #179 and unblocks mission maps whose intro should open on the player's base.

## What Changes

- Add a **Set Player Start** tool to the MapEditor toolbar. Which player is being set is chosen by a SpinBox; left-click a cell to assign that player's start to it, right-click a placed start to reset it to the map-center cluster.
- Start locations persist in the map JSON v4 format as a new top-level `start_locations` array (per-player overrides only). Non-breaking: existing maps without the key load unchanged.
- On gameplay scene load, the camera pivots to the **local player's** start location instead of the fixed origin. Player identity continues to come from `PlayerManager.get_local_player_id()`.
- Editor shows a visible marker per player at its current start.

## Capabilities

### New Capabilities
- `map-editor-player-start`: authoring player start locations in the MapEditor — tool, markers, persistence to map JSON.

### Modified Capabilities
<!-- none: map-config and map-loader specs do not change; camera framing is new behavior -->

## Impact

- `scripts/editor/MapEditor.gd` — new `Tool.PLAYER_START`, toolbar button + player selector, input dispatch, new-map/settings redraw.
- `scripts/editor/PlayerStartTool.gd` (new) — owns per-player start cells, marker meshes, save/restore; follows the `HeightPainter`/`ResourcePainter` node-tool pattern.
- `scripts/editor/EditorSaveLoad.gd` — persist `start_locations` via `extra_data`, restore on load.
- `scripts/core/BoundsSystem.gd` — shared default-start-cell logic + `center_camera_on_cell()`; becomes the single home for camera placement.
- `scripts/maps/MapLoader.gd` — read `start_locations`, frame camera to local player's start in gameplay only.
- `scenes/editor/MapEditor.tscn` — no structural change (tools are built in `_setup_ui()`); backward compatible.
- Tests: new `test/unit/test_player_start_locations.gd` plus e2e coverage in `test/integration/test_map_editor_e2e.gd`.