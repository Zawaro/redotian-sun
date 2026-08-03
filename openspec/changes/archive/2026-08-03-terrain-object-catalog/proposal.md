## Why

The terrain tile set is hardcoded: `TerrainRenderer`/`TerrainCollision` map cell type+variant to GLB submeshes, land types are a sparse overlay, and the seed `TerrainObject` catalog (`cliff_straight_*`, `ramp_n`, `slope`, `clear`) was hand-authored to "reproduce current behavior" rather than match any real tile. Tiberian Sun defines the canonical tile footprints in its `isotem` `.tem` template files, and the placeholder terrain GLB ships the full mesh set — so the game cannot represent actual TS-shaped terrain today. We need data-driven tiles that reflect real TS footprints, authored once and reused across theaters.

## What Changes

- **New permanent dev tool** `tools/isotem/` (Python, stdlib-only — `scripts/` is reserved for `.gd` files):
  - `tem.py` — parser for the TS/RA2 TMP `.tem` template format: 16-byte header (`BlockWidth`, `BlockHeight`, image dims), cell index (0 = empty, else absolute offset), 52-byte per-cell headers (`Height`, `LandType`, `SlopeType`, radar colors, extra-face geometry). Exposes a `Tile` footprint.
  - `cli.py` — dump a tile's footprint grid + heights + land types; framework-free `--check` self-check against the known `cliff01` case (2×3, 4 cells, heights 4/0/4/0, land 0x0F).
  - `catalog.py` — batch-parse the TS `isotem` directory, cluster tiles into shape families under **90° rotation only** (mirrors stay distinct base shapes — `ramp01` ≠ `ramp02`), emit `isotem_catalog.json` with per-tile cells and `tile_lookup.json` with per-cell corner signatures and the reverse corner-pattern map.
  - `generate_tres.py` — emit one `TerrainObject` `.tres` per **directional variant** (every base family × 4 rotations: `cliff01_n/e/s/w`, `ramp01_n/e/s/w`, …), with baked per-cell `corners`, `crease`, `slope` (provenance), and `land`.
- **Baked 4-direction `TerrainObject` catalog**: `resources/terrain_objects/*.tres` — each cell carries `corners: [nw, ne, se, sw]` (4 absolute vertex heights, geometry authority), `crease: "flat"|"x"|"y"` (triangulation authority so entity height sampling and collision agree by construction), optional `slope` (TS RampType provenance), and `land` (surface type). Rotated variants are authored data, not runtime rotations — shared art is rotated by the variant's directional suffix.
- **Suffix-aware art seam**: `TerrainArtData.mesh_name(tile_id)` strips the directional suffix (`cliff01_n` → `cliff01`); the renderer derives the mesh rotation from the suffix (`n`→0°, `e`→90°, `s`→180°, `w`→270°). Seed ids (`cliff_straight_*`, `ramp_n`, `slope`, `clear`) fold into the catalog's directional variants.
- **Theater registration**: all catalog variants registered in `resources/theaters/temperate.tres`. Theater remains the container for the data + art bundle in this change (the "catalog global, theater art-only" refactor is deferred).
- **Connection roles**: `plateau` collapses into `ground`. The role set becomes `cliff / ramp / ground / water`; elevated-vs-base semantics live in `corners`, not in a role name.
- **Tests**: `test/unit/test_terrain_object_catalog.gd` rewritten for the baked-corners model.

## Capabilities

### New Capabilities
- `isotem-tooling`: the permanent Python parser + CLI for TS `.tem` files, the rotation-only shape-family dedup catalog, the corner lookup, and the `.tres` generator.
- `terrain-object-catalog`: the data-driven `TerrainObject` catalog — baked 4-direction variants with per-cell `corners`/`crease`/`slope`/`land`, registration in `temperate.tres`, and the suffix-aware art seam.

### Modified Capabilities
- `land-types`: none (no requirement changes — the catalog references existing land type ids `rock`/`clear`/`water`; `buildable` handling is out of scope here).

## Impact

- **New**: `tools/isotem/tem.py`, `cli.py`, `catalog.py`, `generate_tres.py`, `isotem_catalog.json`, `tile_lookup.json`, `README.md`; `resources/terrain_objects/<tile>_<dir>.tres` (~96 files); `scripts/data/TerrainObject.gd`, `TheaterData.gd`, `TerrainArtData.gd` + `.uid`; `resources/art/terrain/placeholder_terrain_art.tres`; `test/unit/test_terrain_object_catalog.gd` + `.uid`.
- **Modified**: `resources/theaters/temperate.tres` (new file).
- **Data provenance**: `.tem` files are read from the user's TS install via CLI arg / `TS_ISOTEM_DIR` env var; no game files are vendored into the repo.
- **Backward compatibility**: the placeholder GLB and its fallback mesh mapping remain the art seam; existing maps and tests are unaffected. `LandType` resources and JSON map format are untouched.
- **Deferred (follow-up sub-issues)**: theater-selectable global catalog (#203/#204), runtime resolver consuming all corner patterns (#207), `TerrainSystem` stamping applying `corners` (#202), `buildable`/land-type passability wiring.

## Non-Goals

- Replacing placeholder GLB meshes with real TS art (art swap stays on the `TerrainArtData` seam).
- Runtime loading of `.tem` files (parser is an offline authoring tool).
- Wiring catalog variants into editor facing-palette / placement (data-only this change).
- Global catalog / theater-art-only separation.
