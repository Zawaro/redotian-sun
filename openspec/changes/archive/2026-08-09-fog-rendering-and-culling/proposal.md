# fog-rendering-and-culling

## Why

The ShroudSystem fog grid (#197) is simulation-only — there is no visual shroud/fog overlay and no entity reacts to it. Without rendering, the authoritative grid is invisible and players get no feedback, so the fog system is effectively dormant. Issue #198 wires the grid to the screen and to entity visibility.

## What Changes

- New `VisionComponent` attached by `EntityFactory` to player-owned entities with `sight > 0`; registers a revealer with ShroudSystem, re-stamps on cell-boundary crossing (units), registers permanently (buildings), unregisters on tree exit.
- New `FogRenderer` autoload owning a world-aligned fog plane (MeshInstance3D + spatial shader) spanning the map just above max terrain height, sampling a grid-resolution `ImageTexture` built from `ShroudSystem.get_effective_state(local_player)` (visible → discard, fog → dim, shroud → opaque black). Texture rebuilt only when cells changed.
- New spatial shader `shaders/maps/FogOfWarPlane.gdshader` (pattern: `CloudShadowPlane.gdshader`).
- Soft-edged borders — **REVERTED.** The initial signed-distance-field (`fog_soft`) implementation and a later boundary-ribbon mesh were both removed (look/perf regressions); hard cell edges are the current shipped behavior. Soft edges are an open gap (#274).
- Fog-driven visual culling: enemy units hidden in shroud, frozen as last-known ghosts in fog (via `UnitMeshRenderer` instance parking/freezing); enemy buildings hidden in shroud and persisting in fog (`entity.visible`); friendly units never hidden. Visual-only — simulation untouched.
- Fog-driven culling for ALL entity types — open gaps: freeze the last-known visual for every entity type under fog (#275) and hide every entity type under shroud (#276). Decorations (Tiberium/trees/rubble — `TERRAIN`/`OVERLAY`), node-tree-fallback units, and anything outside `UnitMeshRenderer`/`FogRenderer` currently leak through shroud. The raised opaque shroud sheet (`PLANE_OFFSET = (40, 40 × HEIGHT_STEP, 40)`) depth-occludes ground entities; per-instance gates must cover entities that rise above it.
- `ShroudSystem` gains a `state_changed` signal emitted from `resolve_dirty()` when cells resolved, so renderers rebuild only on change.
- **Out of scope:** follow-attack pathing through blockers (#277) is a combat/movement gap surfaced during this work; tracked separately, not implemented here.
- **BREAKING (docs only):** Issue #198's "Context" claimed a live 960×540 pixel-art SubViewport. It is orphaned dead code (`PixelArtManager`, `EntityMaskManager`, `PixelArtOutline01.gdshader` — never registered/instantiated). This change targets the shared `World3D` (renders in the root viewport); the pixel pipeline stays dead and gets its own issue. Acceptance criteria reworded accordingly.

## Capabilities

### New Capabilities
- `fog-rendering`: visual shroud/fog overlay (world plane + shader + incremental texture; hard cell edges currently, soft edges gated by #274) and fog-driven entity culling (units via renderer instance hide/freeze, buildings via `entity.visible`; decorations/fallback-unit hiding for all entity types gated by #275/#276). Includes the `VisionComponent` revealer wiring that drives it.

### Modified Capabilities
- `fog-of-war`: ShroudSystem SHALL emit a `state_changed` signal when its resolve tick processes cells, enabling change-driven texture rebuilds.
- `unit-multimesh-rendering`: registered unit instances SHALL support per-instance fog hiding (instance parked off-world, GLB tree stays hidden), so fog culling does not require `entity.visible`.

## Impact

- **New files:** `scripts/components/VisionComponent.gd`, `scripts/core/FogRenderer.gd`, `shaders/maps/FogOfWarPlane.gdshader`, `test/unit/test_fog_renderer.gd`.
- **Modified:** `scripts/entities/EntityFactory.gd` (attach VisionComponent), `scripts/core/ShroudSystem.gd` (`state_changed`), `scripts/core/UnitMeshRenderer.gd` (fog-cull branch), `project.godot` (register FogRenderer autoload after ShroudSystem), `test/unit/test_unit_mesh_renderer.gd` (cull tests).
- **No new dependencies.** Image/ImageTexture/shader APIs are engine-native. Fog is gated on `GlobalRules.fog_of_war` (default false) so existing maps/skirmish are unaffected.
- **GH issue:** #198 context/acceptance text rewritten to match the real architecture (root viewport, not a dead SubViewport).
- **Backward compatibility:** all behavior inert when `fog_of_war == false`; no packed-scene or `.tres` changes required.
