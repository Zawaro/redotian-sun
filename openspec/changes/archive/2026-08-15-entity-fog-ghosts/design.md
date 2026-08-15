## Context

The fog grid (`ShroudSystem`) is authoritative and per-player: cells resolve to shroud (0) / fog (1) / visible (2), and `state_changed(dirty)` is emitted each 0.25s resolve. Rendering is split today:

- `UnitMeshRenderer` (autoload) renders units through per-region MultiMesh buckets. `_fog_state` returns `_FOG_VISIBLE`/`_FOG_GHOST`/`_FOG_HIDDEN` and the ghost freeze is instance-based: the MultiMesh slot transform is written once on fog entry and not synced again (`_physics_process`, lines 187-263). The region-full fallback (`_set_model_visible(model_root, true)`) leaks live position through fog. A registered unit's GLB tree is hidden (`model_root.visible = false`).
- `FogRenderer` (autoload) culls enemy buildings via `node.visible` on `ShroudSystem.state_changed` + tree `node_added`/`node_removed`. Buildings already persist in explored fog (`is_entity_revealed_to_local` — any foundation cell explored) and are hidden in shroud. The building is static, so "freeze" must capture *appearance* (door anims, tiberium harvest stage, damage), not transform.
- Overlays are player-less (`player_id < 0`) TERRAIN/OVERLAY entities: Tiberium renders via `ResourceComponent` cube stages (`_update_visual` swaps 3 cubes on health ratio); trees via `TerrainRenderer` MultiMesh. Both are static but their *state* changes (harvest shrink, regrowth) and can leak through fog.
- Death flows: `HealthComponent.health_zero` → `EntityFactory._on_entity_death` (units/tiberium) and `BuildingManager._on_building_destroyed` (buildings). Both fire synchronously *before* the deferred `queue_free`, so a pre-free capture is possible. `tree.node_removed` is too late (fires after the node is freed).

Constraints: no new autoload (22 exist); signal-up/call-down; GDScript only; freeze is visual-only (simulation/combat keeps running on the same shared entity nodes — single machine, local player + AI); behavior-driven tests via `redot --headless -s test/run_tests.gd`.

## Goals / Non-Goals

**Goals:**
- Every rendered entity type freezes to a last-known visual in fog: units (incl. node-tree fallback), buildings, and killable overlays (Tiberium harvest stage, trees, rubble).
- Post-destruction ghosts: an entity destroyed while fogged keeps a static visual at its last spot until its cell is revealed or reverts to shroud.
- Freeze is visual-only; simulation and combat remain live.
- Ghost truth derived from the grid so leaks are structurally impossible.
- Same machinery serves #276 (shroud-hide for all types) later with minimal extension.

**Non-Goals:**
- The opaque-shroud x-ray workaround (lifted sheet offset `SHROUD_LIFT_*` + shader material config) — the true fix for shroud edge artifacts; tracked in #276, out of scope here.
- Per-viewer ghost rendering for replays/hot-seat/lockstep multi-view (single local viewer only; see Open Questions).
- Generalizing shroud-hide to all types (#276).
- Renaming `UnitMeshRenderer` (naming smell accepted; see Decisions).

## Decisions

### D1. Ownership: depot owns nodes, grid owns truth, death path owns the death moment
From the ADHD divergence, ownership is three complementary layers, not one system:
- **Nodes**: `GhostDepot` Node3D — a child of the current scene, created at runtime by `UnitMeshRenderer._ready`. The scene tree *is* the registry; no separate bookkeeping dict.
- **Truth**: ghost membership is derived, never stored sticky — a ghost exists iff cell state == FOG AND the entity's `StatsComponent` player is an enemy of the local player (or the entity is a killable player-less overlay in an explored cell) AND the entity is alive. Recomputed on `state_changed`; `assert_no_leaks()` push_errors on any ghost that should not exist.
- **Death moment**: pre-free capture in the two death handlers.
Alternatives rejected: EntityFactory hub-and-spoke (factory spawns but does not free — false premise), per-player memory mirrors (over-engineered for single local viewer), a new autoload (22 exist).

### D2. Freeze mechanism per type: reparent for node visuals, tombstone for MultiMesh
- **GLB-model entities** (buildings, node-tree fallback units): on fog entry, `model_root.reparent(GhostDepot, keep_global_transform=true)`. The visual detaches from the moving entity root → frozen in world space; `ArtComponent`'s sibling `AnimationPlayer` loses its NodePath targets → door/turret anims halt for free (appearance freeze). On reveal, reparent back to the remembered parent, gated on `is_instance_valid(entity_root)`.
- **Tiberium cube stages**: reparent the currently-visible `ResourceComponent` stage container (no GLB). Frozen stage + position; reveal reparents back.
- **MultiMesh units and trees**: no reparentable node exists (the visible form is a shared instance). Keep the existing `_FOG_GHOST` transform freeze for live ghosts; **tombstone slot** for post-destruction: on `unregister`, keep the frozen slot (don't release it) until the reveal/shroud-revert sweep releases it. Reject the "everything into MultiMesh buckets" consolidation: buckets freeze transform only, buildings/tiberium need appearance fidelity.

### D3. One reconciling sweep in `UnitMeshRenderer`, driven by `state_changed`
A single `_reconcile(dirty: PackedInt32Array)` subscriber (created by `UnitMeshRenderer._ready`, connected to `ShroudSystem.state_changed`) is the sole ghost arbiter: for each dirty cell index, read `get_cell_effective_state(local, idx)`; on VISIBLE/SHROUD release every ghost anchored there; on FOG ensure a ghost exists for each alive eligible entity in that cell. Per-player and allied-vision-sharing fall out for free because the sweep reads the same local-player stream the fog texture bakes from. The `_fog_state` poll remains for transform sync until the sweep is proven, then collapses (its `fogged`/`hidden` flags die).

### D4. Runtime toggles need an explicit `sweep_all()`
`state_changed` carries no dirty cells when `GlobalRules` fog/shroud toggles at runtime, yet effective state changes. Mirror `FogRenderer.refresh()`: an explicit `sweep_all()` that re-derives every ghost from live grid state, wired into the DebugMenu toggle path. Without it, ghosts desync from the plane — a real 3am failure (ghosts frozen in cells the fog plane no longer dims).

### D5. Death capture is conditional and pre-free
Connect capture in both death handlers (next to the existing `health_zero` connect in `EntityFactory.create_entity`, and in `BuildingManager._on_building_destroyed`): if `is_entity_revealed_to_local(entity) == false` (cell in fog or shroud) when death fires, reparent the visual (GLB model_root / active tiberium stage) into the depot keyed by `CellUtil.world_to_cell(entity.global_position)`, so the pending `queue_free` on the entity root cannot free it. MultiMesh classes use tombstone slots instead (see D2). `tree.node_removed` is rejected as the hook — too late.

### D6. Release contract is one method
`GhostDepot.release_all()` plus per-cell release on: cell becomes VISIBLE, cell reverts to SHROUD (shroud growth / `cover_shroud`), fog toggle-off (`sweep_all`), grid reinit, map teardown, and a living entity claiming the same anchor cell. `assert_no_leaks()` runs after reconcile at test/build of debug and in unit tests.

### D7. Async model loading
`ArtComponent._finalize_model` checks a fog flag: if the entity is already fogged when the model finishes loading, parent the instance straight into the depot (recorded original parent) instead of under ArtComponent, so it never flashes live under fog.

### D8. `FogRenderer` demotes to shader planes; naming smell accepted
Building culling moves onto the shared reconcile/ghost path (`is_entity_revealed_to_local` already exists and is used by `_sync_building`). `FogRenderer` keeps the planes, textures, and `refresh()`. `UnitMeshRenderer` keeps its name despite now handling non-unit ghosts — renaming an autoload + scene is a wider refactor with no functional gain.

## Risks / Trade-offs

- **[Deferred death/reveal race]** `queue_free` from `health_zero` is deferred to end-of-frame, so a ghost's entity root can be dead-but-still-valid the same frame a fog→visible transition fires. → Every reparent-back is gated on `is_instance_valid(entity_root)`; ghost freeing is a sweep, not an event; the death handlers capture before free.
- **[Two independent death paths]** Units/tiberium (`EntityFactory`) and buildings (`BuildingManager`) free on different flows; `tree.node_removed` cannot be the single hook. → Both handlers are wired to the same capture helper; tests cover both paths.
- **[state_changed completeness]** Reconcile correctness rests on every effective fog change producing an emit; runtime toggles break that invariant. → Explicit `sweep_all()` on the toggle path (D4), plus `assert_no_leaks()`.
- **[MultiMesh tombstone drift]** Tombstone slots use the same shared buckets; keeping them after unregister risks slot/visible_instance_count bookkeeping drift. → Tombstones are separate bookkeeping from live slots; release contract sweeps them; covered by unit tests on slot compaction.
- **[Animation resume after reveal]** Reparenting back does not restore a door animation's playback state (AnimationPlayer's target paths re-resolve, but the animation may sit paused at its fog-entry frame). → Accepted: door anims are replayed by the existing `play_animation` call sites on the next unit spawn; no new anim state machinery.
- **[Naming smell]** `UnitMeshRenderer` now reconciles buildings/overlays. → Accepted (D8); documented here so future readers aren't confused.
- **[Fidelity of fogged appearance]** The freeze shows the exact visual at fog-entry (tiberium stage, damage), which is precisely "last-known". Over time a fogged harvested field shows a stale stage until revealed. → Correct behavior; matches Tiberian Sun.

## Migration Plan

1. Add `GhostDepot` (runtime child of the scene, created by `UnitMeshRenderer._ready`) with `release_all()`, `assert_no_leaks()`, and the release contract.
2. Wire the `_reconcile(dirty)` subscriber in `UnitMeshRenderer`; keep the existing per-frame `_fog_state` poll running until the sweep is proven, then collapse it.
3. Reparent freeze for buildings (GLB), node-tree fallback units, and tiberium stage containers; reveal reparents back (is_instance_valid-gated).
4. Tombstone slots for MultiMesh units and TerrainRenderer trees.
5. Death-capture wiring in `EntityFactory._on_entity_death` and `BuildingManager._on_building_destroyed`; `sweep_all()` on runtime toggle path.
6. Behavior tests (see tasks.md) for every type + transition; regression on existing `test_fog_renderer.gd` / `test_unit_mesh_renderer.gd`.
7. Rollback: ghost behavior is additive to existing culling; reverting to the pre-change commits restores `_FOG_GHOST`-only behavior with no data migration.

## Open Questions

- **Multi-viewer ghosts**: ghosts are scoped to the single local viewer (D1). If replay/hot-seat/spectator rendering is needed (#279 stack), membership must index per viewer id. The grid-derived truth layer supports it; the shared `GhostDepot` nodes would need per-viewer resolution. Deferred, not designed here.
- **Trees via tombstone vs. dedicated bucket**: whether TerrainRenderer trees reuse UnitMeshRenderer tombstone logic or get their own ghost bucket is left to implementation; behavior is specified, the mechanism is not.
