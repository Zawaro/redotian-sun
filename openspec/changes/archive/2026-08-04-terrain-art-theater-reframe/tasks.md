## 1. Data model reshapes

- [x] 1.1 Slim `scripts/data/TheaterData.gd` to `id`, `display_name` (no land-type field); remove `terrain_objects`, `art_data`, `default_land_type`, `get_terrain_object()`
- [x] 1.2 Add `@export var art_data: TerrainArtData = null` to `scripts/data/TerrainObject.gd`
- [x] 1.3 Reshape `scripts/data/TerrainArtData.gd`: fields `id`, `model_path`, `submesh_id`, `theater_overrides: Dictionary`; keep `DIRECTION_ROTATIONS` and `mesh_rotation(object_id)`; remove `mesh_name()`, `base_mesh_id()`, `FALLBACK_MESHES`
- [x] 1.4 Add typed `ArtResolution` inner struct (`glb_path`, `submesh_id`, `rotation`, `valid`) and `resolve(object_id, theater_id)` to `TerrainArtData` (glb = `theater_overrides.get(theater_id, model_path)`, submesh = `submesh_id` or base id, rotation from suffix)

## 2. TerrainCatalog autoload

- [x] 2.1 Create `scripts/core/TerrainCatalog.gd` mirroring `EntityFactory`: `register_data_set(path)` + recursive `_scan_directory`, caches `_objects` / `_art` / `_theaters`
- [x] 2.2 Scan `resources/terrain_objects/`, `resources/art/terrain/`, `resources/theaters/` at `_ready()`; register only resources of the expected type
- [x] 2.3 Add `get_object(id)`, `get_art(id)`, `get_theater(id)` returning null for unknown ids
- [x] 2.4 Add active-theater state: `set_active_theater(theater_id)` (unknown id → first registered + warning), `get_active_theater()` (defaults to first registered)
- [x] 2.5 Add `resolve_art(object_id, theater_id)` delegating to object → `art_data.resolve()`; null `art_data` → invalid resolution
- [x] 2.6 Register `TerrainCatalog` autoload in `project.godot` before terrain consumers

## 3. Data migration and new resources

- [x] 3.1 Author ~16 per-family `resources/art/terrain/*.tres` (`cliff01/02/05/09/14/23/24`, `wcliff01`, `ramp01`, `clear01`, slope family) with `model_path` = placeholder GLB and `submesh_id` where aliased; `theater_overrides` empty
- [x] 3.2 One-time migration: add `art_data` refs to all 144 `resources/terrain_objects/*.tres` (shared family files; `cliff12` → `cliff09`, etc.)
- [x] 3.3 Slim `resources/theaters/temperate.tres` to `id`/`display_name`
- [x] 3.4 Delete `resources/art/terrain/placeholder_terrain_art.tres`

## 4. Consumer re-pointing

- [x] 4.1 `scripts/core/TerrainRenderer.gd`: replace hardcoded `_get_mesh_name(type, variant)` with `TerrainCatalog.resolve_art(...)`; load resolved GLB, pick submesh, apply rotation; invalid → pink `BoxMesh` + warning
- [x] 4.2 `scripts/core/TerrainCollision.gd`: same resolution path for collision meshes; invalid → skip body + warning
- [x] 4.3 `scripts/maps/MapLoader.gd`: read `json.get("theater_id")` after parse → `TerrainCatalog.set_active_theater(id)`
- [x] 4.4 `scripts/editor/AssetPreviewController.gd`: re-point `_theater.art_data.mesh_name()` / `_theater.terrain_objects` / `FALLBACK_MESHES` to `TerrainCatalog` + `resolve()`

## 5. CI / tooling

- [x] 5.1 Remove isotem variant-count check from `.github/workflows/test.yml`; keep `tools/isotem/` as documented manual tooling

## 6. Tests

- [x] 6.1 Rewrite `test/unit/test_terrain_art_data.gd` for `resolve()`: theater override, submesh default (suffix), rotation, invalid→pink
- [x] 6.2 Rewrite `test/unit/test_theater_data.gd` for the light theater shape
- [x] 6.3 New `test/unit/test_terrain_catalog.gd`: scan/register, getters, active theater (map id, first-default, unknown-fallback), `resolve_art` delegation, pink on null art
- [x] 6.4 Update `test/unit/test_terrain_object_catalog.gd`: keep data-integrity checks; drop theater-registration assertions; add "every object resolves art"
- [x] 6.5 Update `test/integration/test_asset_preview_scene.gd` and `test/unit/test_asset_preview_data.gd` for the new seam
- [x] 6.6 New `test/integration/test_theater_selection.gd`: map `theater_id` → `set_active_theater` → snow override swaps glb vs temperate default

## 7. Validation

- [x] 7.1 Run full suite `redot --headless -s test/run_tests.gd`
- [x] 7.2 Run `gdlint` and `gdformat --check` on changed scripts; tab regression check

## 8. Spec sync

- [x] 8.1 Update `openspec/specs/terrain-object-catalog/spec.md` with the new art-seam and theater-registration requirements (fold in `terrain-catalog` capability on archive)

## 9. Corner-pivot rendering

- [x] 9.1 Switch `TerrainRenderer`/`TerrainCollision` from the deprecated centered `.glb` to the corner-pivoted `.gltf` (via the active art's `resolve_art.glb_path`, const fallback)
- [x] 9.2 Add `CellUtil.tile_transform(center, rotation_deg, half)` — rotation about the foundation center, not the corner pivot
- [x] 9.3 `TerrainRenderer.render_cell` stores per-mesh `half` from the AABB and places instances via `CellUtil.tile_transform`; `_update_multimesh_aabb` uses the mesh half
- [x] 9.4 `TerrainCollision.create_collision` mirrors the same offset (body position = `tile_transform().origin`)
- [x] 9.5 Remove both deprecated `placeholder_terrain01.glb` copies + import artifacts
- [x] 9.6 New `test/unit/test_terrain_renderer_pivot.gd` (pure `tile_transform` math + renderer/collision smoke checks); full suite green + lint/format clean

## 10. Catalog-driven slope rotation

- [x] 10.1 `TerrainSystem.slope_object_id(corners)` — static lookup built from the catalog's baked slope corner patterns (prefers the natural `_n` orientation for degenerate saddles)
- [x] 10.2 `_make_slope` emits the resolved `object_id` and the catalog rotation (`resolve_art(object_id).rotation`); legacy variant/direction remain as fallback
- [x] 10.3 `TerrainRenderer`/`TerrainCollision` prefer `data.object_id` for art resolution so the map editor renders the same tile + rotation as the asset preview
- [x] 10.4 New `test/unit/test_slope_rotation.gd` (known id mappings, all-catalog pattern resolution, cell classification, renderer submesh); full suite green + lint/format clean

## 11. Shared resolution seam + light theater cleanup

- [x] 11.1 `TerrainCatalog.resolve_cell_art(cell_data)` — one mesh-resolution dispatch (object_id → legacy type/variant family fallback → active theater); `_get_mesh_family` moved into `TerrainCatalog`, deleted from `TerrainRenderer`/`TerrainCollision`; both use the shared helper
- [x] 11.2 `TerrainArtData.direction_rotation(object_id)` static suffix lookup; `mesh_rotation` delegates; `_make_slope` bakes facing via the static instead of calling the catalog (no TerrainSystem→TerrainCatalog dependency in the gameplay model)
- [x] 11.3 `TerrainCatalog.load_terrain_scene()` — cached shared scene loader (+ `TERRAIN_GLB_PATH` const); used by renderer and collision; per-file copies and the hardcoded `"clear01"` probe removed
- [x] 11.4 `TheaterData` drops `default_land_type` (game-wide default stays in `TerrainSystem.DEFAULT_LAND_TYPE`); updated `temperate.tres`, `AssetPreviewController` displays, `test_theater_data.gd`, spec delta + synced main spec
- [x] 11.5 New `resolve_cell_art` tests in `test_terrain_catalog.gd` (object_id path, legacy fallback, invalid); full suite green + lint/format clean + spec validates
