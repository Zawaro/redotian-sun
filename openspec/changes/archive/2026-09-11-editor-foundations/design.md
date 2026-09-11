## Context

The map editor overhaul (#363) is split into child changes (#366–#372). This is
the foundations change (#366): the data and core primitives the later UI,
painting, cliff, and waypoint work depends on.

Current state on `main`:

- `LandType` has `id`, `display_name`, `color`; six types ship in
  `games/ts/land_types/`; gameplay reads them from `games/ts/global_rules.tres`.
- `TerrainSystem` truth model is a vertex heightfield (`_vertex_grid`) plus a
  sparse `_land_types` overlay; slope art is derived (`slope_object_id`). The
  land-type overlay is **not persisted** today and has no production writer.
- Entity ownership is a single integer `player_id` (`StatsComponent` →
  `PlayerManager`). `EntityData.owner` carries `GDI` / `Nod` / `Neutral`
  strings used for browser grouping and cameo colors. `Faction` resources exist
  under `games/ts/factions/` but nothing loads them.
- The stale `feat/363` branch already implemented an earlier version of these
  foundations against the pre-multi-game `resources/` layout; it is the
  reference, not the base.

## Goals / Non-Goals

**Goals:**

- Land types can be grouped for the editor bottom bar, with five new paintable
  surfaces that stay traversable.
- Painted land-type overlays persist in map JSON.
- A canonical house vocabulary that reuses the ownership strings already in the
  codebase, with `house_id` persisted on entities and a backward-compatible
  `player_id` alias.
- A cliff cell primitive (`_cell_pins`) that stamps, locks against height
  edits, and persists.
- Backward compatibility: old maps load unchanged.

**Non-Goals:**

- The editor UI shell, tool protocol, undo, painting tools, cliff/waypoint
  tools, and framework mode (later #367–#372).
- A faction registry or new `Faction` `.tres` files — nothing loads them; the
  house ids are enough until a real faction-selection feature exists.
- Transition ground art and `TerrainObject.tileset_id` grouping.

## Decisions

### D1. Houses are a separate axis from player slots, with the existing id casing
Houses model map-object ownership (the TS rules-side `[Houses]` list); player
slots are a different axis (start locations / waypoints 0–7 assigned at game
setup). The canonical ids are `GDI`, `Nod`, `Neutral`, `Special` — matching the
strings already shipped in `EntityData.owner` and `CAMEO_COLORS`, rather than
the reference branch's lowercase ids, which would have broken owner grouping.
Implemented as a small static helper module (`Houses.gd`); no enum-as-storage,
no new resources.
- **Alternatives**: reuse `Faction` resources (orphan — nothing loads them, so
  adding `neutral.tres`/`special.tres` would be dead data); lowercase ids
  (breaks existing `owner` matching); a free-form per-map house list (not needed
  for the maps being authored).

### D2. `house_id` persists; `player_id` stays a serialization alias only
`EditorSaveLoad` writes `house_id` when an entity carries one and keeps
`player_id` in sync by writing the house index when no explicit slot is set.
`MapLoader` prefers `house_id`, falling back to a `player_id` that is a valid
house index. Resolving a house does **not** change gameplay ownership — no
`PlayerManager` changes; this is data plumbing for the later editor.
- **Alternatives**: make houses gameplay owners now (out of scope, needs team
  semantics for Neutral/Special); drop `player_id` (breaks old readers).

### D3. `_cell_pins` — one primitive for stamp, lock, and delete
`TerrainSystem` gains `_cell_pins: {cell_key → TerrainObject id}`. Pins drive
art resolution, lock height edits at vertex granularity, and persist. This gives
the cliff tool (#370) its entire backend with no new storage layer.
- **Alternatives**: store placed `TerrainObject` instances per cell (new
  storage layer duplicating the heightfield); derive cliffs purely from heights
  (can't carry connection roles or lock editing).

### D4. Pin locks are vertex-granular, and the cascade stops at locked vertices
`raise_cell`/`lower_cell` no-op on a pinned cell. `set_vertex` and
`flatten_footprint` skip any vertex shared by a pinned cell; the cascade does not
smooth locked vertices but still re-slopes editable neighbors. This keeps stamped
cliff geometry constant while allowing terrain edits beside it.

### D5. Land-type overlay persistence folded into this change
`export_to_json` writes non-default `_land_types` entries as `"land_types"`;
`import_from_json` restores them; `set_land_type` already clears the override on
the default id. Both overlays (`cell_pins`, `land_types`) follow the same sparse,
omit-when-empty pattern. `set_land_type` still emits no `cell_changed`: painted
land types affect movement, minimap color, and framework-mode color, not 3D
ground art (no ground tiles exist), so consumers read them lazily.

### D6. `resolve_cell_art(cell_data, cell)` — optional cell context
The pin check needs a cell. The cell parameter is optional so callers without
context (catalog tests, family-only callers) keep working; `TerrainRenderer`
passes its cell. `get_cell_art` (minimap) stays cell-less and ignores pins.

### D7. Re-implement on `games/ts`, not rebase
The reference branch's code is portable but its paths (`resources/…`) and ids
(lowercase) are both stale. Re-implementing on the current layout keeps this
change scoped to #366 and avoids dragging the epic's OpenSpec artifacts and an
old base along. The branch diff is the source of truth for algorithms and tests.

## Risks / Trade-offs

- [Pin locks change gameplay terrain edits] → `BuildingManager.flatten_footprint`
  now skips pinned-cliff vertices. Intended (protect authored cliffs), but an
  integration test must prove normal building placement with no pins still
  levels, and pinned footprints are skipped.
- [House id casing drift] → ids are pinned to the `EntityData.owner` vocabulary
  and asserted in tests; any new owner string must be added to `Houses` in the
  same change.
- [`player_id` alias re-conflates house and slot] → documented as
  serialization-only; no gameplay consumer reads `house_id` yet.
- [Undo/redo not in this change] → height edits here are un-undoable until #368;
  acceptable because the cliff tool that needs atomic undo (#370) lands later.
- [Large new data files trail in git] → `.tres` only; no binary assets.

## Migration Plan

1. Land data first: `group` on existing land types, five new `.tres`,
   locomotor speeds, global-rules registry. Additive, no behavior change.
2. Add `Houses.gd` and `house_id` plumbing through save/load.
3. Add `_cell_pins` + pin-aware height mutations + `resolve_cell_art` pin check
   + renderer cell pass. Inert until a tool writes pins.
4. Add `land_types` overlay persistence.
5. Update GLOSSARY.
Rollback: revert the branch; new JSON keys are ignored by older builds.

## Open Questions

- None blocking. Exact framework-mode placeholder colors are deferred to #372.
