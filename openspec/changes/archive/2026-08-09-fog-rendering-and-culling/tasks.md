## 1. ShroudSystem change hook

- [x] 1.1 Add `signal state_changed` to `scripts/core/ShroudSystem.gd` and emit it from `resolve_dirty()` when `processed > 0`
- [x] 1.2 Unit test: signal emitted when dirty cells resolve; not emitted when nothing changed (extend `test/unit/test_shroud_system.gd`)

## 2. VisionComponent

- [x] 2.1 Create `scripts/components/VisionComponent.gd` (Node3D, `configure(data)` captures sight/entity_type/height/foundation; `_ready` caches parent + StatsComponent; lazy register from `_physics_process` when `player_id >= 0`; cell-crossing re-stamp; `_exit_tree` null-safe unregister tracking `_registered_player_id`)
- [x] 2.2 Attach in `scripts/entities/EntityFactory.gd` `_add_components`: preload script, `_add_vision_component` gated on `sight > 0` and type ∈ {INFANTRY, VEHICLE, AIRCRAFT, BUILDING}
- [x] 2.3 Buildings register once then `set_physics_process(false)`; multi-cell buildings register from footprint center
- [x] 2.4 Unit tests: registers on spawn, unregisters on tree exit, re-stamps on cell change, no re-stamp while stationary, deferred until player assigned, terrain entity never registers

## 3. UnitMeshRenderer fog culling

- [x] 3.1 Cache StatsComponent ref in the registry entry at `register()` in `scripts/core/UnitMeshRenderer.gd`
- [x] 3.2 Add fog branch in `_physics_process` (after preview branch, ~line 204): three-way state (`is_explored` vs `is_visible`) → visible syncs, fog freezes instance at last-known transform as ghost (no sync, no migration), shroud parks at `HIDDEN_POSITION` (GLB tree stays hidden)
- [x] 3.3 Extend `test/unit/test_unit_mesh_renderer.gd`: enemy unit hidden in shroud, shown when visible, friendly never hidden, unhide resumes sync, region migration while hidden
- [x] 3.4 Tests: enemy unit frozen as ghost in explored fog (not parked), ghost persists without region migration while fogged, ghost resumes sync on reveal

## 4. Fog overlay plane

- [x] 4.1 Create `shaders/maps/FogOfWarPlane.gdshader` (spatial; CloudShadowPlane pattern; uniforms `fog_grid` filter_nearest/repeat_disable, `grid_origin`, `grid_units`, `fog_darkness`, `shroud_color`; visible discard, fog dim, shroud opaque)
- [x] 4.2 Create `scripts/core/FogRenderer.gd` autoload: builds plane `MeshInstance3D` (PlaneMesh W*CS × H*CS, transform at center, y = `MAX_HEIGHT*HEIGHT_STEP + 0.05`, cast_shadow 0), rebuilds `ImageTexture` (FORMAT_L8) from `get_effective_state` on `state_changed` with buffer compare, rebuilds on `TerrainSystem.grid_initialized`, hides plane when `not is_fog_enabled()`
- [x] 4.3 Register `FogRenderer` in `project.godot` [autoload] after ShroudSystem
- [x] 4.4 Verify grid↔diamond alignment against a real map file; fix plane geometry if the grid/diamond assumptions differ
- [x] 4.5 Tests: texture rebuilt only on changed effective buffer (allied-noise filtered), plane geometry covers the grid, inert when `fog_of_war == false`

## 6. Off-map shroud + plane offset

- [x] 6.1 Extend `_build_draped_mesh` to cover the whole map square plus a `RIM_MARGIN` (32 cells) flat rim per side so the viewport stays shrouded when panned to a map edge (off-diamond keys drape flat via `get_vertex` → 0)
- [x] 6.2 Shader: treat UVs outside `[0,1]` (beyond the map square, where `repeat_disable` would clamp to playable edge texels) as shroud
- [x] 6.3 Position the plane node at `PLANE_OFFSET = (20, 40 × HEIGHT_STEP, 20)`; update geometry tests (map-square corners present, AABB spans map + rim, offset position) and design.md Decision 1

## 5. Building culling

- [x] 5.1 In `scripts/core/FogRenderer.gd`: event-driven building registry (`tree.node_added/node_removed` + "entities" group + BUILDING type), pass applying `entity.visible = is_explored(local, cell)` on the resolve tick
- [x] 5.2 Tests: enemy building persists in explored-fog, hidden before explored, friendly always visible

## 7. Independent shroud / fog toggles

- [x] 7.1 Add `GlobalRules.shroud_enabled` (default `true`); `fog_of_war` stays default `false`; split `ShroudSystem` gates (`is_shroud_enabled`, `is_fog_enabled`) and collapse `is_cell_visible_to_local`
- [x] 7.2 Shader: scale L8 sample back (`* 255.0`) so 0.5/1.5 thresholds classify; add `shroud_enabled`/`fog_enabled` uniforms that discard the inactive layer
- [x] 7.3 FogRenderer: gate on `shroud or fog`, set uniforms in `_layout_plane`, add `refresh()`, building pass respects shroud toggle
- [x] 7.4 UnitMeshRenderer `_fog_state`: visible → sync; unexplored → `_FOG_HIDDEN` only when shroud on; explored-not-visible → `_FOG_GHOST` only when fog on
- [x] 7.5 ShroudSystem `cover_shroud(player_id)` + `_stamp_explored` (reverts to unexplored except active allied/own revealer radii)
- [x] 7.6 DebugMenu: new "Fog / Shroud" section (shroud checkbox, fog checkbox, reveal button, cover button) wired to rules + `FogRenderer.refresh()` / `explore_all` / `cover_shroud`; synced on `_ready` and reset in `reset_state()`
- [x] 7.7 Tests: shroud-on/fog-off, fog-on/shroud-off, both-off visibility; cover keeps revealer sight + respects play area; fog-off no-ghost; existing inert tests updated for the shroud default

## 8. Integration & verification

- [x] 8.1 Run `redot --headless -s test/run_tests.gd` — all tests pass
- [x] 8.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; run `grep -P '\t' scripts/**/*.gd` to confirm no tabs introduced
- [ ] 8.3 Manual check in-game: fog overlay renders (black/dim/transparent) and updates as units move; enemy units culled; friendly unaffected; combat/movement unaffected
- [x] 8.4 Update GH issue #198: correct Context (root viewport, pixel pipeline is orphaned dead code), reword acceptance criteria to the shared world, link this change

## 9. Soft-edge shroud and fog borders

> **STATUS — REVERTED.** The SDF soft-edge stack (9.1–9.6) was removed for look/perf after the initial checkpoint; a boundary-ribbon follow-up was also reverted. Hard cell edges are the current shipped behavior. Tasks below document the reverted approach; 9.7 tracks the re-implementation (gap #274).

- [x] 9.1 Add `SHROUD_FALLOFF`/`FOG_FALLOFF` consts and a two-pass Felzenszwalb Euclidean distance transform (`_edt_1d`, `_edt_distances`, `_signed_distance_bytes`) to `scripts/core/FogRenderer.gd`
- [x] 9.2 Build an RGBA8 signed-distance texture in `_rebuild_texture` (`fog_soft`: R = distance to shroud boundary, G = distance to fog boundary, `sdist = dist − 0.5` clamped to ±0.5 and byte-packed); set as a shader param and null it alongside `fog_grid` when disabled; set falloff uniforms in `_layout_plane`
- [x] 9.3 Shader `shaders/maps/FogOfWarPlane.gdshader`: add `fog_soft` (`filter_linear`), `shroud_falloff`, `fog_falloff` uniforms; visible branch decodes the SDF and applies `1 − smoothstep(0, falloff, d)` per channel (0-crossing on the cell boundary = crisp covered cells, halo from the edge); force a deep-covered SDF outside the map square so the rim stays opaque shroud
- [x] 9.4 Unit tests in `test/unit/test_fog_renderer.gd`: EDT distances on a known grid + source ranges, signed-distance bytes (covered cell interior 0, adjacent visible cell 255 = halo end at 0.5 cells out), `fog_soft` present and rebuilt on change
- [x] 9.5 Run `redot --headless -s test/run_tests.gd` (4640 pass); `gdlint`/`gdformat --check`; `grep -P '\t'` for tabs
- [x] 9.6 Manual in-game: covered cells are crisp 1-cell squares, the halo fades from the cell edge to 0.5 cells out, rim stays black at map edges
- [ ] 9.7 **RE-OPENED (#274):** re-implement soft shroud/fog edges with a cheap single-draw approach (no per-frame CPU bake); update `specs/fog-rendering/spec.md` "Soft-edged shroud and fog borders" and re-check 9.1–9.6 semantics when done

## 10. Freeze every entity under fog (#275)

- [ ] 10.1 Confirm/formalize the freeze-in-fog treatment for all entity types: units ghost-freeze at last-known position (shipped); static buildings persist (shipped); decorations/overlay must persist at last-known (they currently render normally — verify that equals "frozen" and that no move-capable decoration is missed)
- [ ] 10.2 Tests: enemy decoration persists in fog; enemy unit still freezes as ghost; enemy building persists in fog
- [ ] 10.3 Manual in-game check (folded into 8.3)

## 11. Hide every entity under shroud (#276)

- [ ] 11.1 Apply the `is_entity_revealed_to_local` visual gate to TERRAIN/OVERLAY entities (Tiberium, trees, rubble) — currently never culled
- [ ] 11.2 Hide node-tree-fallback units (`UnitMeshRenderer` region-full path sets `model_root.visible = true` unconditionally) when their cell is shrouded
- [ ] 11.3 Verify the raised opaque sheet (`PLANE_OFFSET`) depth-occludes ground entities in shrouded cells; per-instance gates cover entities that rise above it (high-altitude aircraft)
- [ ] 11.4 Tests: decoration hidden in shroud and shown when revealed; fallback-rendered unit hidden in shroud
- [ ] 11.5 Manual in-game check: no entity renders inside a shrouded cell

## 12. Follow-attack blocker pathing (#277) — out of scope

Combat/movement gap surfaced during fog work: a follow-attacking unit chases a moving enemy straight through buildings instead of routing around blockers. Tracked in #277; NOT part of this change's implementation.

