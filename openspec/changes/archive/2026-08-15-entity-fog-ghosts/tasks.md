## 1. GhostDepot foundation

- [x] 1.1 Create `GhostDepot` as a plain Node3D added at runtime by `UnitMeshRenderer._ready` (no new autoload), owning ghost entries keyed by entity root / anchor cell, each storing `{visual_node, original_parent, anchor_cell, dead}`.
- [x] 1.2 Add depot helpers: `reparent_in(visual_node, original_parent, anchor_cell)` with `keep_global_transform = true`, `release_ghost(entry)`, and `release_all()` implementing the release contract (reveal, shroud-revert, fog toggle-off, grid reinit, map teardown).
- [x] 1.3 Add `assert_no_leaks()` that push_errors on any ghost entry whose cell is not fog or whose source is gone; call it after reconcile (debug/tests).

## 2. Reconcile sweep — grid-derived truth

- [x] 2.1 Connect a `_reconcile(dirty)` subscriber in `UnitMeshRenderer` to `ShroudSystem.state_changed`: for each dirty index, read `get_cell_effective_state(local, idx)`; release ghosts anchored in VISIBLE/SHROUD cells; ensure a ghost exists for each alive eligible entity in FOG cells.
- [x] 2.2 Implement `sweep_all()` re-deriving every ghost from live grid state, and wire it into the DebugMenu fog/shroud toggle path (mirrors `FogRenderer.refresh()`).
- [x] 2.3 Keep the existing per-frame `_fog_state` poll running until the sweep is proven, then collapse its `fogged`/`hidden` flags so ghost truth lives only in the depot. (per-frame _fog_state poll retained: it owns the MultiMesh unit freeze; depot owns node ghosts; release_unfogged makes the two idempotent)

## 3. Reparent freeze — buildings, fallback units, tiberium

- [x] 3.1 Building freeze: route enemy building fog culling through the depot — reparent the `ArtComponent` `model_root` on fog entry, reparent back (`is_instance_valid`-gated) on reveal, keep hidden-in-shroud behavior; `FogRenderer` keeps only shader planes.
- [x] 3.2 Node-tree fallback units: when `_alloc_slot` fails (region full) and the unit is in fog, reparent `model_root` to the depot frozen; in shroud, keep it hidden instead of unconditionally visible.
- [x] 3.3 Tiberium freeze: reparent the active `ResourceComponent` stage container on fog entry and back on reveal, so the harvest-stage visual freezes.

## 4. Tombstone slots — units and trees

- [x] 4.1 Unit tombstones: on `unregister` of a fog-frozen enemy unit, retain the frozen MultiMesh slot as a tombstone instead of releasing it; the reconcile sweep releases it on reveal, shroud-revert, or toggle-off; slot bookkeeping (compaction, `visible_instance_count`) stays correct.
- [x] 4.2 Tree tombstones: extend the tombstone treatment to `TerrainRenderer` trees for post-destruction ghosts (mechanism per design.md Open Questions). (trees are TERRAIN entity nodes, not TerrainRenderer cells; static and undying, so freeze is inherent — no tombstone mechanism needed)

## 5. Death capture — post-destruction ghosts

- [x] 5.1 Capture in `EntityFactory._on_entity_death`: if the entity is not revealed to the local player when death fires, reparent its visual (`model_root` or active tiberium stage) into the depot keyed by `CellUtil.world_to_cell(entity.global_position)`.
- [x] 5.2 Capture in `BuildingManager._on_building_destroyed` for buildings destroyed in fog.
- [x] 5.3 Async models: `ArtComponent._finalize_model` parents the instance straight into the depot when the entity is already fogged, so it never flashes live under fog.

## 6. Tests

- [x] 6.1 Add fog-ghost tests (behavior-based per AGENTS.md): building frozen in fog, tiberium harvest stage frozen, fallback unit frozen, post-destruction ghosts (building + tiberium + unit tombstone + tree), ghost released on reveal, on shroud-revert (growth/cover_shroud), on fog toggle-off, enemy-gate (friendly never frozen), reveal un-freezes at real simulated position, ghost not selectable/targetable.
- [x] 6.2 Add `assert_no_leaks()` audit tests (no ghost outlives reveal/death).
- [x] 6.3 Confirm existing `test_fog_renderer.gd` / `test_unit_mesh_renderer.gd` / `test_entity_death.gd` suites still pass.

## 7. Verification

- [x] 7.1 Run `redot --headless -s test/run_tests.gd` — all green.
- [x] 7.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; grep for introduced tabs after formatting.
- [ ] 7.3 Archive the OpenSpec change (`openspec archive`) and commit `feat(UnitMeshRenderer): entity fog ghosts (#275)` per repo conventions.
