## Why

The GPU rendering budget scales poorly with entity count: every unit is a full GLB node tree (~7 `MeshInstance3D` subnodes = ~7 draw calls per unit), debug geometry and the DebugMenu ship enabled in release builds, each building allocates a unique select-box material, and SSAO adds cost with no visible benefit in the top-down view. Issue #219 tracks this. SDFGI stays enabled (its tuning is issue #221).

## What Changes

- Disable SSAO in the default world environment. Directional shadow size stays 4096 (a future Options menu item will expose it), glow and fog are kept.
- Gate all debug facilities behind `OS.is_debug_build()` so they are inert in non-debug (release) exports: `DebugVisualizer`, `MovementController.debug_show_path`, and the `DebugMenu` panel.
- Introduce a `UnitMeshRenderer` autoload that renders data-driven units through per-region `MultiMeshInstance3D` buckets instead of per-unit GLB node trees, cutting ~7 draw calls per unit to a handful per region.
- Introduce `ModelBaker` to bake each model's GLB subnodes into a single multi-surface `ArrayMesh` (one MultiMesh instance per unit).
- Share one cached select-box material across building select boxes instead of allocating a fresh material per building.

## Capabilities

### New Capabilities
- `rendering-budget`: Environment and overlay geometry cost reductions — SSAO disabled, shared building select-box material, release builds ship no debug geometry.
- `unit-multimesh-rendering`: Rendering of data-driven units through baked, per-region MultiMesh instances with per-frame transform sync and slot lifecycle (register/unregister/swap-remove/migration).

### Modified Capabilities
- `debug-menu`: The debug panel and its overlays must be absent/inert in non-debug builds; behavior in debug builds is unchanged.

## Impact

- `scenes/environment/DefaultWorldEnvironment01.tscn` — `ssao_enabled = false`.
- `scripts/core/DebugVisualizer.gd`, `scripts/components/MovementController.gd`, `scripts/ui/DebugMenu.gd` — debug-build gating.
- New `scripts/core/ModelBaker.gd` (static bake) and `scripts/core/UnitMeshRenderer.gd` (autoload).
- `scripts/components/ArtComponent.gd` — registers unit models with the renderer, hides the GLB node tree.
- `scripts/components/SelectComponent.gd` — shared select-box material.
- `project.godot` — register `UnitMeshRenderer` autoload.
- `test/unit/test_model_baker.gd`, `test/unit/test_unit_mesh_renderer.gd` — new unit tests.
- Backward compatible: the direct-scene path (TestMap01's hand-built `NodBuggy.tscn`) is untouched and continues rendering via node trees.
