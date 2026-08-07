## Context

The map editor can create maps with custom width/height and visible-bounds insets (New Map / Map Settings dialogs, already shipped). Terrain is serialized to JSON and reloaded via `TerrainSystem.export_to_json` / `import_from_json` and `MapLoader.load_map_into`.

Two independent pieces of "size" state exist at runtime:

- `TerrainSystem.grid_cells: Vector2i` — the full cell grid. This is already serialized (as `grid_cells`) and fully restored on load via `init_grid`, so the outer (red) map bounds already round-trip.
- `BoundsSystem.left_inset` / `right_inset` / `top_inset` / `bottom_inset: int` — how many cells the visible (blue) play-area edge is inset from each of the four map edges. These are **not** serialized, so the visible bounds do not round-trip.

The JSON currently declares `"version": 4` but only carries `grid_cells`. Older files on disk are `"version": 3` with `grid_cells` as a bare scalar (e.g. `assets/test_terrain.json`, `grid_cells: 46`).

## Goals / Non-Goals

**Goals:**
- Persist and restore the visible play-area bounds so a saved map reloads with the same blue bounds.
- Keep older (v3) maps loading correctly via a fallback.
- Make the JSON self-describing by also recording `map_size`.

**Non-Goals:**
- Changing how bounds are drawn, computed, or clamped at runtime (terrain-following mesh, 1-cell outer inset, camera clamp all stay as-is).
- Reworking the `visible_offset` model into a different representation.

## Decisions

**Represent visible bounds as four independent edge insets.**
The previous symmetric `visible_offset_x/z` model (one inset per half-axis) could only shrink the visible diamond evenly; it could not move the play area off the map center. The dialogs now expose **Left / Right / Top / Bottom** insets in cells:
- `left_inset` shrinks the west edge (`difference >= -w + left`),
- `right_inset` shrinks the east edge (`difference < w - right`),
- `top_inset` shrinks the north edge (`sum >= -h + top`),
- `bottom_inset` shrinks the south edge (`sum < h - bottom`).

Asymmetric pairs shift the diamond center (e.g. `left != right` moves it along the X axis), replacing the earlier center-offset idea without any coupling rules — each edge is independent. Defaults are `left=right=5, top=bottom=4` (the previous editor look). Dialog spinbox maxes are dynamic: `top_max = 2h - bottom - 1`, `left_max = 2w - right - 1`, etc., so the visible bounds can never exceed the map or become empty.

**Serialize bounds as `visible_bounds`, not a derived size.**
Because insets are now per-edge, the size-based `visible_bounds_size = [W - 2*ox, H - 2*oz]` cannot represent asymmetry. v4 writes the raw insets:
- `visible_bounds = [left, right, top, bottom]`

`apply_saved_bounds` reads the four values directly (clamped `>= 0`), so the round-trip is lossless even for asymmetric bounds.

**Restore bounds in `MapLoader`, not in `TerrainSystem.import_from_json`.**
`MapLoader.load_map_into` is the single load path used by both the game (`TestMap02`) and the editor, and it already owns the parsed JSON dictionary. Terrain import happens first (emitting `grid_initialized`, which syncs `BoundsSystem.grid_cells`), then `BoundsSystem.apply_saved_bounds(json)` sets the insets. Keeping `TerrainSystem` free of a `BoundsSystem` reference avoids new coupling in the core terrain layer.

**Centralize the v3 fallback in `BoundsSystem.apply_saved_bounds()`.**
When `visible_bounds` is absent (v3 / hand-authored), the method falls back to the standard default insets `(5, 5, 4, 4)` — the same defaults the editor applies to a fresh map — so old maps keep their existing appearance. The insets reuse the existing setters, which already trigger a `create_bounds_edges()` redraw.

**Save always writes.**
`EditorSaveLoad` previously skipped `export_to_json` entirely when no entities were placed. A terrain-only map with custom bounds must be saveable, so the guard is removed; the `entities` array is written even when empty.

## Risks / Trade-offs

- `map_size` duplicates `grid_cells` → Accepted: it is cheap, matches the documented v4 format, and makes files self-describing; `grid_cells` remains authoritative on load.
- `TerrainSystem.export_to_json` must read `BoundsSystem` (via `get_node_or_null("/root/BoundsSystem")`) → Guarded: if the autoload is absent (e.g. an isolated tool context) the field is simply omitted and load treats it as v3.
- Hand-authored `visible_bounds` with negative values would invert the insets → Mitigated: insets are clamped to `>= 0` on load.
