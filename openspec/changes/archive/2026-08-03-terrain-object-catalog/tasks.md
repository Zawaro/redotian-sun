## 1. Data model foundation

- [x] 1.1 Create `scripts/data/TerrainObject.gd` (`class_name TerrainObject extends Resource`): `id`, `cell_type`, `display_name`, `cells` (object-local `"x,z"` → `{land, corners: [4], crease, slope?}`), `connections` (edge → role dict).
- [x] 1.2 Create `scripts/data/TheaterData.gd` (`class_name TheaterData extends Resource`): `id`, `display_name`, `terrain_objects: Dictionary`, `art_data: TerrainArtData`, `default_land_type`, `get_terrain_object(id)`.
- [x] 1.3 Create `scripts/data/TerrainArtData.gd` (`class_name TerrainArtData extends Resource`): `id`, `glb_path`, `is_placeholder`, suffix-aware `mesh_name(tile_id)` that strips `_n/_e/_s/_w`, `FALLBACK_MESHES` (one entry per family), and renderer-facing rotation mapping.
- [x] 1.4 Create `resources/art/terrain/placeholder_terrain_art.tres` referencing `placeholder_terrain01.glb` with `is_placeholder = true`.

## 2. TS .tem parser tooling

- [x] 2.1 Create `tools/isotem/tem.py`: `parse_tem(path) -> Tile` decoding the TMP format (16-byte header, index, 52-byte cell headers), skipping empty cells, validating offsets/grid, stdlib-only.
- [x] 2.2 Create `tools/isotem/cli.py`: `python tools/isotem/cli.py <file.tem>` prints width/height, occupied-cell grid, per-cell height + land type + slope; `--check` asserts the known `cliff01` footprint (2×3, heights 4/0/4/0, land 0x0F).
- [x] 2.3 Create `tools/isotem/README.md` documenting the format, offsets, land types, and usage; correct the height claim (ramps legitimately use intermediate steps 1–3).
- [x] 2.4 Verify `python tools/isotem/cli.py --check` passes against the real TS `isotem` directory.

## 3. Rotation-only catalog + corner lookup

- [x] 3.1 Create `tools/isotem/catalog.py`: batch-parse source dir, cluster into shape families under 90° rotation only (mirrors stay separate: `ramp01` ≠ `ramp02`), kind-separated (cliff vs wcliff).
- [x] 3.2 Emit `tools/isotem/isotem_catalog.json` (per-family base, kind, dims, members, per-cell `x,y,height,land,slope`) and `tools/isotem/tile_lookup.json` (per-cell corner signatures + reverse corner-pattern map).
- [x] 3.3 Run extraction over the TS `isotem` directory and sanity-check family membership (rotations collapsed, mirrors separate).

## 4. Four-direction variant generation

- [x] 4.1 Create `tools/isotem/generate_tres.py`: for each base family, emit `_n/_e/_s/_w` variants with per-cell `corners` pre-rotated to that facing, `crease` derived from the corner pattern, `land`, and optional `slope`.
- [x] 4.2 Generate all `resources/terrain_objects/<base>_<dir>.tres`; uniform 4× expansion including symmetric/single-cell tiles.
- [x] 4.3 Cross-validate generated tiles against known TS footprints (e.g. `cliff01`, `ramp01` cell-for-cell against the `.tem` data).

## 5. Theater registration + seed folding

- [x] 5.1 Create `resources/theaters/temperate.tres` registering all catalog variants + `art_data` + `default_land_type = "clear"`.
- [x] 5.2 Fold the seed objects (`cliff_straight_*`, `ramp_n`, `slope`, `clear`) into the catalog's directional variants; ensure no `plateau` role remains anywhere (role set = `cliff / ramp / ground / water`).
- [x] 5.3 Confirm every `terrain_objects/*.tres` loads as a `TerrainObject` with 4-element `corners` and valid `crease`.

## 6. Tests + validation

- [x] 6.1 Rewrite `test/unit/test_terrain_object_catalog.gd`: `cliff01_n` loads with the TS footprint, variant `corners` are pre-rotated per facing, `crease` values are valid, all variants registered in `temperate.tres`, ramp-role edges face lower in-tile neighbors, unknown ids return null.
- [x] 6.2 Run `redot --headless -s test/run_tests.gd` — existing suite stays green; new catalog test passes.
- [x] 6.3 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check`; no tab regression (`grep -P '\t' scripts/**/*.gd`).
- [x] 6.4 Run `python tools/isotem/cli.py --check` and the catalog corner round-trip self-check.

## 7. Documentation + archive

- [x] 7.1 Update issue #201 acceptance criteria to the 4× baked-variant model (24 families × 4 variants, rotation-only dedup, corners/crease data).
- [x] 7.2 Review `tools/isotem/README.md` for accuracy against the shipped tooling.
- [x] 7.3 Archive the `terrain-object-catalog` openspec change so CI's openspec gate passes.
