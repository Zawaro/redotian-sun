## Context

The map editor can create maps with custom width/height and visible-bounds insets (New Map / Map Settings dialogs, already shipped). Terrain is serialized to JSON and reloaded via `TerrainSystem.export_to_json` / `import_from_json` and `MapLoader.load_map_into`.

Two independent pieces of "size" state exist at runtime:

- `TerrainSystem.grid_cells: Vector2i` — the full cell grid. This is already serialized (as `grid_cells`) and fully restored on load via `init_grid`, so the outer (red) map bounds already round-trip.
- `BoundsSystem.visible_offset_x` / `visible_offset_z: int` — how many cells the visible (blue) play-area edge is inset from the map edge on each half-axis. `get_play_area_extents()` returns `grid_cells / 2 - offset`. These are **not** serialized, so the visible bounds do not round-trip.

The JSON currently declares `"version": 4` but only carries `grid_cells`. Older files on disk are `"version": 3` with `grid_cells` as a bare scalar (e.g. `assets/test_terrain.json`, `grid_cells: 46`).

## Goals / Non-Goals

**Goals:**
- Persist and restore the visible play-area bounds so a saved map reloads with the same blue bounds.
- Keep older (v3) maps loading correctly via a fallback.
- Make the JSON self-describing by also recording `map_size`.

**Non-Goals:**
- Changing how bounds are drawn, computed, or clamped at runtime (terrain-following mesh, 1-cell outer inset, camera clamp all stay as-is).
- Changing the New Map / Map Settings dialogs or the editor toolbar.
- Reworking the `visible_offset` model into a different representation.

## Decisions

**Serialize bounds as full cell extents (`map_size`, `visible_bounds_size`), not raw insets.**
The JSON keys match the issue's format and read as human-meaningful dimensions:
- `map_size = [grid_cells.x, grid_cells.y]`
- `visible_bounds_size = [grid_cells.x - 2*offset_x, grid_cells.y - 2*offset_z]` (the full visible extent, since each inset applies to both half-axes).

On load the inset is recovered exactly: `offset = (grid_cells - visible_bounds_size) / 2`. Because we write the size from the same integer insets, the conversion round-trips without loss. Alternative — storing the raw `visible_offset_x/z` — was rejected because the issue specifies the `visible_bounds_size` key and dimensions are the more stable, self-documenting contract.

**Restore bounds in `MapLoader`, not in `TerrainSystem.import_from_json`.**
`MapLoader.load_map_into` is the single load path used by both the game (`TestMap02`) and the editor, and it already owns the parsed JSON dictionary. Terrain import happens first (emitting `grid_initialized`, which syncs `BoundsSystem.grid_cells`), then `BoundsSystem.apply_saved_bounds(json)` sets the insets. Keeping `TerrainSystem` free of a `BoundsSystem` reference avoids new coupling in the core terrain layer.

**Centralize the v3 fallback in `BoundsSystem.apply_saved_bounds()`.**
When `visible_bounds_size` is absent (v3 / hand-authored), the method falls back to the standard default insets `(10, 8)` — the same defaults the editor applies to a fresh map — so old maps keep their existing appearance. Setting `visible_offset_x/z` reuses the existing setters, which already trigger a `create_bounds_edges()` redraw.

**Save always writes.**
`EditorSaveLoad` previously skipped `export_to_json` entirely when no entities were placed. A terrain-only map with custom bounds must be saveable, so the guard is removed; the `entities` array is written even when empty.

## Risks / Trade-offs

- `map_size` duplicates `grid_cells` → Accepted: it is cheap, matches the documented v4 format, and makes files self-describing; `grid_cells` remains authoritative on load.
- `TerrainSystem.export_to_json` must read `BoundsSystem` (via `get_node_or_null("/root/BoundsSystem")`) → Guarded: if the autoload is absent (e.g. an isolated tool context) the field is simply omitted and load treats it as v3.
- Hand-authored `visible_bounds_size` larger than `grid_cells` would yield a negative inset → Mitigated: insets are clamped to `>= 0` on load.
