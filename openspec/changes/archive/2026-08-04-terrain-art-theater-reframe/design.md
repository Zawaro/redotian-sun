# Design: Terrain Art & Theater Reframe

## Context

On `main` the terrain theater seam is data-only and fat. `resources/theaters/temperate.tres` embeds all 144 `TerrainObject` directional variants plus a single `TerrainArtData` (one per theater) with a global `FALLBACK_MESHES` table. Nothing consumes the seam at runtime: `TerrainRenderer._get_mesh_name` / `TerrainCollision._get_mesh_name` still map `type + variant → GLB submesh` from hardcoded logic. `TerrainObject` carries no art link, so gameplay data and visuals are only loosely coupled by naming.

The entity side already does this differently and better: `EntityData` (gameplay) is scanned by the `EntityFactory` autoload and references its `ArtData` (loading) directly. This change ports that model to terrain: per-element art files, a light theater tag, a global catalog registry, and map JSON as the sole authority for the active theater.

Stakeholders: `TerrainRenderer`/`TerrainCollision` (mesh resolution), `TerrainSystem` (stamping/geometry — theater-independent), `MapLoader` (theater authority ingestion), `AssetPreviewController` (asset-preview browsing from #213), the map editor's future theater swap (#206), and real-art authoring (#210).

## Goals / Non-Goals

**Goals:**
- Invert ownership: `TerrainObject` = global gameplay catalog; `TerrainArtData` = one file per mesh family (shared by many objects); `TheaterData` = light tag.
- Dynamic, directory-scanned loading mirroring `EntityFactory` (`TerrainCatalog` autoload).
- Art resolution encapsulated in `TerrainArtData.resolve(object_id, theater_id)` → glb/submesh/rotation; pink placeholder for unresolvable art.
- Map JSON `theater_id` is the authoritative selection source, ingested by `MapLoader`, passed forward to `TerrainCatalog`.
- Rendering/collision driven by the seam; the hardcoded `_get_mesh_name` path removed.
- One-time committed data migration of the 144 object `.tres`; ~16 hand-authored per-family art `.tres`.

**Non-Goals:**
- #202 stamping/passability internals (`stamp_object`, `is_cliff_wall`, `rock.tres`, BuildingManager flat-footprint, `MAX_HEIGHT` 10→16).
- #206 editor theater dropdown / ART↔HEIGHT view toggle UI.
- #210 real TS art assets (the `theater_overrides` mechanism ships empty).
- Removing `tools/isotem/` (stays as manual legacy, soft reference only).
- Collapsing the 4 baked directional `TerrainObject` variants into one base + runtime rotation.

## Decisions

### D1. `TerrainObject` becomes a global, theater-independent catalog
Geometry, passability, and corners are theater-independent (movement costs are global in `Locomotor`; the branch comments that stored cell data stays theater-independent), so the 144 baked-direction objects move out of `TheaterData` into a global `resources/terrain_objects/` registry.
- **Alternatives**: keep the catalog theater-owned (contradicts a light theater; would duplicate 144 files per future theater).
- **Why**: one catalog, many theaters; mirrors entity scanning.

### D2. One `TerrainArtData` per mesh family, shared by reference
`TerrainObject.art_data: TerrainArtData` — a direct resource reference, exactly like `EntityData.art_data`. Many objects reference the same art entry (alias objects like `cliff12` point at the `cliff09` family file). The old global `FALLBACK_MESHES` table dissolves into per-file `submesh_id` (defaults to the element's base id).
- **Alternatives**: runtime convention (strip suffix → art id) with an alias map; rejects because it diverges from the entity pattern the change is modeled on.
- **Why**: static, inspectable links; override-sharing falls out of art sharing.

### D3. Art data owns resolution — `resolve(object_id, theater_id)`
`TerrainArtData` keeps `DIRECTION_ROTATIONS` + rotation-from-suffix and gains a typed `resolve()` returning `{glb_path, submesh_id, rotation, valid}`:
- glb = `theater_overrides.get(theater_id, model_path)` — override is a plain GLB path (TS art ships one theater GLB with a submesh per tile id)
- submesh = `submesh_id` or the object's base id
- rotation = from the object id suffix (`_n`→0°, `_e`→270°, `_s`→180°, `_w`→90°) — rotation is a gameplay/placement fact, so it comes from the object id, not the shared art file
- `valid` false → pink placeholder mesh
- Removes `mesh_name()`, `base_mesh_id()`, `FALLBACK_MESHES`.
- **Why**: cohesion (all art knowledge in the art class), pure-resource testability, one-way dependency (only the object *id*, never the whole object).

### D4. `TerrainCatalog` autoload owns registries + active theater + resolution
New autoload mirroring `EntityFactory`: `register_data_set(path)` + recursive `_scan_directory` over `resources/terrain_objects/`, `resources/art/terrain/`, `resources/theaters/`; caches by id; exposes `get_object/get_art/get_theater`, `set_active_theater(id)` / `get_active_theater()`, and `resolve_art(object_id, theater_id)` (object → `art_data` → `resolve()`; null art → invalid).
- **Alternatives**: fold into `TerrainSystem` (bloats the wrong file); separate object/art/theater autoloads (over-split).
- **Why**: the exact pattern the change emulates; one choke point for resolution shared by renderer, collision, and the future #206 swap.

### D5. Map JSON is the theater authority; `GlobalRules` stays out
`MapLoader.load_map_into` reads `json.theater_id` and calls `TerrainCatalog.set_active_theater(id)`. Selection state lives on `TerrainCatalog`, not `GlobalRules`.
- **Alternatives**: keep `GlobalRules.current_theater` + delegators; rejected — split-brain ownership (dict in catalog, selection in settings), per-map state in a process-lifetime settings resource, and "passing forward" is a pipeline, not a global parking lot.
- **Why**: single owner, no stale-theater-across-maps bug, matches the forward-pass model.

### D6. Missing art = pink placeholder, strict (warn), not silent fallback
Unresolvable `resolve_art` → `BoxMesh` + pink `StandardMaterial3D` + `push_warning`.
- **Alternatives**: fall back to a default (`clear01`) — rejects; masks broken seams exactly where cliff art breaks.
- **Why**: missing art is a data bug surfaced loudly; the generator/ tests guarantee the happy path.

### D7. `is_placeholder` dissolves
"Placeholder art" is now derived: a theater uses the default `model_path` until it has overrides. The #206 ART↔HEIGHT toggle stays orthogonal. No flag.

### D8. isotem is soft reference only
`tools/isotem/` remains as documented manual extraction tooling; the CI variant-count cross-check is removed. Structural invariants live in the game test suite (`test_terrain_object_catalog.gd`).

## Risks / Trade-offs

- **144-file migration** → one-time committed pass (throwaway script or editor/inspector); the generator is not involved, so it cannot be a verifier. Verify by a "every object resolves art" catalog test.
- **Autoload init order** → `TerrainCatalog` must register in `project.godot` before renderer/collision consume it; scan at `_ready()` and document order.
- **Rotation correctness with shared art** → rotation derives from the object id suffix, never the shared art file; covered by `test_terrain_art_data.resolve` unit tests.
- **Consumers on the old seam** (`AssetPreviewController`, its two test files) → re-point to `TerrainCatalog` + `resolve()`; listed in tasks so nothing is orphaned.
- **Theater selection duplication** → every theater change goes through `TerrainCatalog.set_active_theater`; `get_active_theater()` is the only read path, so renderer/collision/`TerrainSystem` can't diverge.
- **Pink mesh in shipped maps** → treated as a data-integrity failure; the catalog test suite asserts full resolution.

## Migration Plan

1. Add `TerrainCatalog` autoload + scan; wire `project.godot`.
2. Reshape the three data classes (`TheaterData` slim, `TerrainArtData.resolve()`, `TerrainObject.art_data`).
3. Author ~16 per-family `resources/art/terrain/*.tres` pointing at the placeholder GLB; delete `placeholder_terrain_art.tres`.
4. One-time migration: add `art_data` refs to the 144 object `.tres`; slim `temperate.tres`.
5. Re-point renderer/collision/`MapLoader`/`AssetPreviewController`.
6. Remove isotem CI check.
7. Rewrite/update tests; run full suite + `gdlint`/`gdformat`.

Rollback: the old seam files are deleted; keep the pre-migration commit as the rollback point (revert to it restores `temperate.tres`/`placeholder_terrain_art.tres`).

## Open Questions

- None blocking. (Theater override shape = plain `glb_path`; escalate to `{glb_path, submesh_id}` only if a real theater needs submesh renaming.)
