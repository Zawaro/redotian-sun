## Why

The map editor UI overhaul (#363) needs a small set of backend primitives before
any of its shell, painting, or cliff tools can be built: land types that can be
grouped and painted, a house (faction) vocabulary for map-object ownership, and
a cliff cell primitive that stamps, locks, and persists terrain. Building the UI
on top of missing backends would produce dead controls, so these land first as
one inert, additive change.

## What Changes

- `LandType` gains `group: String` (editor bottom-bar grouping, no gameplay
  effect); five new paint types ship in `games/ts/land_types/` — `sand`,
  `pavement`, `green`, `crystal`, `mold` — registered in `games/ts/global_rules.tres`
  with clear-equivalent terrain speeds on every ground locomotor.
- Painted land-type overlays persist in map JSON as `"land_types"` (only
  non-default entries), rounding out the sparse per-cell overlay alongside pins.
- New `Houses` vocabulary module: canonical ids `GDI` / `Nod` / `Neutral` /
  `Special`, matching the strings already used by `EntityData.owner` and
  `CAMEO_COLORS`. Houses are factions; player slots stay separate (waypoints
  0–7). No new `Faction` resources are added — nothing loads them today.
- Placed entities carry an optional `house_id`; `player_id` remains a
  serialization alias for older readers (not a gameplay ownership change).
- `TerrainSystem` gains `_cell_pins` (cell → `TerrainObject` id): the stamp,
  height-lock, and delete primitive for cliffs. Pinned cells reject height edits
  at vertex granularity; the cascade re-slopes unpinned neighbors; the overlay
  persists as `"cell_pins"`.
- `TerrainCatalog.resolve_cell_art` resolves a cell's pin before height-derived
  art, falling back with a warning on unknown pinned ids; `TerrainRenderer`
  passes the cell through.
- GLOSSARY gains `LAT`, `tileset`, `house`, `waypoint`, `framework mode`,
  `overlay`/`smudge`.

## Capabilities

### New Capabilities
- `map-houses`: canonical house (faction) id vocabulary for map-object
  ownership, and how a placed entity records its house.
- `terrain-cell-pins`: the `_cell_pins` primitive — pin/unpin API, pin-aware
  height mutation locks, and pin persistence.

### Modified Capabilities
- `land-types`: `group` field on `LandType`; five new registered paint types;
  painted land-type overlay persistence in map JSON.
- `terrain-catalog`: `resolve_cell_art` checks a cell pin before the baked
  object id and legacy family fallbacks.
- `map-loader`: map JSON ingestion of the optional `cell_pins` and `house_id`
  keys, plus `land_types` overlay restore (all backward compatible).
- `entity-placement`: the editor assigns a house to placed entities and
  round-trips it through save/load alongside the legacy `player_id`.

## Impact

- **Scripts**: `scripts/core/TerrainSystem.gd` (pins, locks, overlay
  persistence), `scripts/core/TerrainCatalog.gd` (pin resolution),
  `scripts/core/TerrainRenderer.gd` (pass cell), `scripts/data/LandType.gd`
  (`group`), new `scripts/data/Houses.gd`, `scripts/editor/EditorSaveLoad.gd`
  and `EntityPlacer.gd` (house on placement/save), `scripts/maps/MapLoader.gd`
  (house_id load), plus a `BuildingManager.flatten_footprint` caller whose
  pinned-cliff behavior changes.
- **Data**: 5 new `games/ts/land_types/*.tres`; `group` on the 6 existing;
  clear-speed entries in `games/ts/locomotors/*.tres`; 5 registry entries in
  `games/ts/global_rules.tres`; GLOSSARY.md.
- **Tests**: `test/unit/test_land_type.gd` extended; new
  `test/unit/test_terrain_pins.gd` and `test/unit/test_houses.gd`.
- **Backward compatibility**: existing maps load unchanged — new JSON keys are
  optional and `player_id` stays a valid alias.
