## 1. Land types and locomotor speeds

- [x] 1.1 Add `group: String = ""` to `scripts/data/LandType.gd` (editor bottom-bar grouping, presentation only) and set `group` on the six existing `games/ts/land_types/*.tres`
- [x] 1.2 Author `games/ts/land_types/{sand,pavement,green,crystal,mold}.tres` mirroring `rough.tres` with id, display name, editor color, and group
- [x] 1.3 Register the five new land types in `games/ts/global_rules.tres` (`land_types` dictionary)
- [x] 1.4 Add clear-equivalent `terrain_speeds` entries for the five new types to every ground locomotor in `games/ts/locomotors/` that lists `clear`
- [x] 1.5 Extend `test/unit/test_land_type.gd`: new types registered/resolvable, `group` defaults empty, shipped types carry a group, locomotors pass the new types at clear's multiplier

## 2. Houses vocabulary

- [x] 2.1 Create `scripts/data/Houses.gd`: ids `GDI`/`Nod`/`Neutral`/`Special`, `id_for`/`index_for`/`display_name_for` helpers, ids matching the `EntityData.owner` vocabulary
- [x] 2.2 Create `test/unit/test_houses.gd`: index↔id round-trip, unknown id, display-name passthrough, ids present in the shipped `owner` strings

## 3. House persistence on placed entities

- [x] 3.1 `EntityPlacer`: add a selected house id, record `house_id` in placed-entity data when set, leave legacy `player_id`-only metadata when unset
- [x] 3.2 `EditorSaveLoad`: extract a `build_entity_entry(data)` that writes `house_id` and syncs `player_id` to the house index only when no explicit slot is present
- [x] 3.3 `MapLoader.resolve_house_id(entry)`: prefer explicit `house_id`, fall back to a valid house-index `player_id`, else none; record it on the loaded entity
- [x] 3.4 Extend tests: save-entry house/alias rules, explicit `player_id` preserved, legacy override keys survive

## 4. Cell pins and height locks

- [x] 4.1 `TerrainSystem`: add `_cell_pins` (`cell_key → object_id`), cleared by `clear()` and `_init_vertex_grid()`; add `pin_cell`/`unpin_cell`/`get_pin`/`is_cell_pinned` with the in-diamond guard and `cell_changed` emission on tracked cells
- [x] 4.2 Add `_is_vertex_editable(vx, vz)` (false when any sharing cell is pinned) and apply it in `set_vertex`, `raise_cell`, `lower_cell`, `flatten_footprint`, and the `_cascade_from_vertices` neighbor loop
- [x] 4.3 Persist pins: `export_to_json` writes `"cell_pins"` only when non-empty; `import_from_json` clears then restores in-diamond pins
- [x] 4.4 Create `test/unit/test_terrain_pins.gd`: pin/read/unpin, out-of-diamond rejection, raise/lower no-op on pinned cells, shared-vertex skip beside a pin, flatten skip, cascade stays legal, JSON round-trip, absent-key loads clean

## 5. Pin-aware art resolution

- [x] 5.1 `TerrainCatalog.resolve_cell_art(cell_data, cell := NO_CELL)`: resolve a pinned object first for the active theater, warn and fall back on an unknown pinned id, skip the check when no cell is supplied
- [x] 5.2 `TerrainRenderer.render_cell`: pass the cell to `resolve_cell_art`
- [x] 5.3 Extend `test/unit/test_terrain_catalog.gd`: pin drives resolution, unknown pin falls back, no-cell call ignores pins

## 6. Land-type overlay persistence

- [x] 6.1 `TerrainSystem.export_to_json`: write non-default `_land_types` entries as `"land_types"` (omit when empty); `import_from_json` restores the overlay
- [x] 6.2 Extend `test/unit/test_land_type.gd`: painted override round-trip, `clear` not persisted, absent key loads clean

## 7. Glossary and gates

- [x] 7.1 GLOSSARY.md: add `LAT`, `tileset`, `house`, `waypoint`, `framework mode`, `overlay`/`smudge` (with fog-overlay disambiguation); note `template` stays reserved for TS `.tem`
- [x] 7.2 Update `BuildingManager.flatten_footprint` coverage: prove foundation leveling still works with no pins and skips a pinned-cliff footprint
- [x] 7.3 Run `redot --headless -s test/run_tests.gd`
- [x] 7.4 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; after formatting run `grep -P '\t' scripts/**/*.gd`
- [x] 7.5 Backward compatibility: load a pre-change map JSON (no `cell_pins` / `land_types` / `house_id`) and re-save it
