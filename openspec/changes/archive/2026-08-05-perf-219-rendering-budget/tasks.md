## 1. Environment & Overlay Budget (R1 + R4)

- [x] 1.1 Disable SSAO: set `ssao_enabled = false` in `scenes/environment/DefaultWorldEnvironment01.tscn` (keep shadow 4096, glow, fog)
- [x] 1.2 Add a cached shared `ORMMaterial3D` for building select boxes in `scripts/components/SelectComponent.gd` and use it instead of the per-building material; keep per-building line geometry
- [x] 1.3 Visual check: run MainScene, MapEditor, and AssetPreview; confirm no SSAO artifact regression and select boxes still render per-foundation

## 2. Debug Gating (R2)

- [x] 2.1 `scripts/core/DebugVisualizer.gd`: early-return in `_process` when not `OS.is_debug_build()`; derive `enabled` from `OS.is_debug_build()` in `reset_overlays()`
- [x] 2.2 `scripts/components/MovementController.gd`: in `_ready`, set `debug_show_path = OS.is_debug_build() and debug_show_path`
- [x] 2.3 `scripts/ui/DebugMenu.gd`: in `_ready`, `queue_free()` and return when not `OS.is_debug_build()`
- [x] 2.4 Verify all existing tests still pass (headless runs in a debug build)

## 3. ModelBaker

- [x] 3.1 Create `scripts/core/ModelBaker.gd` (static `bake_merged_mesh(model_root: Node3D, is_remappable: bool) -> Dictionary`) that walks `MeshInstance3D` children, bakes child transforms into vertex/normal/tangent arrays, appends surfaces with materials preserved, and returns `{mesh, remappable_surfaces}`; cache per model path via caller or internal dictionary
- [x] 3.2 Add `test/unit/test_model_baker.gd`: bake `res://assets/models/nod_buggy01.glb` and assert surface count preserved, per-surface materials preserved, vertex arrays non-empty, AABB non-zero, and cache reuse (second call returns same mesh)

## 4. UnitMeshRenderer

- [x] 4.1 Create `scripts/core/UnitMeshRenderer.gd` (autoload): per-model baked mesh cache, per-region `MultiMeshInstance3D` buckets (`REGION_SIZE` ≈ 32 world units, `MAX_INSTANCES` 512, `custom_aabb` = region box, `physics_interpolation_mode = OFF`), slot allocation and swap-remove with `visible_instance_count`
- [x] 4.2 Add `register(entity_root: Node3D, model_path: String, model_root: Node3D, model_offset: Transform3D, is_remappable: bool)` and `unregister(entity_root)`; hide the caller's GLB node tree on register
- [x] 4.3 Implement per-frame sync in `_physics_process`: compute region key from entity position, migrate slots across region boundaries, write `set_instance_transform(slot, entity.global_transform * model_offset)`; guard `Engine.is_editor_hint()`; process only while registrations exist
- [x] 4.4 Register `UnitMeshRenderer` autoload in `project.godot`
- [x] 4.5 Add `test/unit/test_unit_mesh_renderer.gd`: register N units via `EntityFactory.create_entity("NOD_ATTACK_BUGGY")` and assert GLB hidden, slots/visible count grow, transform sync matches entity×offset, swap-remove compacts, cross-region move migrates buckets

## 5. ArtComponent Hook

- [x] 5.1 In `scripts/components/ArtComponent.gd`, record eligibility in `configure()` (entity_type ∈ INFANTRY/VEHICLE/AIRCRAFT) and remappable flag from `art_data`
- [x] 5.2 In `_finalize_model`, when eligible and not editor, call `UnitMeshRenderer.register(...)` with the model-root offset and hide the GLB node tree; in `_exit_tree`, unregister when registered
- [x] 5.3 Verify: spawn units (production and MapLoader maps), move them across region boundaries, select/hover them; confirm rendering, shadows, and selection visuals; confirm structures still render via node trees

## 6. Verification

- [x] 6.1 Run `redot --headless -s test/run_tests.gd` — all existing + new tests pass
- [x] 6.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check`; fix issues; grep for tab introduction
- [x] 6.3 Stress check: spawn ~100+ units in a test map and confirm FPS/render behavior and slot compaction under mass movement and death
