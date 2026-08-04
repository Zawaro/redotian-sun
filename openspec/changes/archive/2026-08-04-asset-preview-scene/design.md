## Context

Issue #213 (queued) wants a developer-facing scene to preview authored terrain assets. #201 is merged and provides the data the preview consumes: `TerrainObject` (140 directional variants in `resources/terrain_objects/`), `TheaterData` (`resources/theaters/temperate.tres` registering all 140), and `TerrainArtData` (suffix-aware GLB submesh resolution + fallback table). The placeholder GLB `assets/models/terrain/placeholder_terrain01.glb` carries the actual submeshes.

Today's terrain rendering (`TerrainRenderer`/`TerrainCollision`) is cell-grid based: one mesh instance per grid cell, mesh name derived from `terrain_type + variant`. The catalog is multi-cell-footprint based: a tile like `cliff01_n` is one authored shape whose art is a single GLB submesh (`cliff01` etc., stripped of direction). The two models are incompatible, so the preview must not reuse the grid renderer.

## Goals / Non-Goals

**Goals:**
- A standalone `scenes/AssetPreview.tscn` runnable via F6 / `--scene`, headless-loadable and covered by tests.
- Browse all theater-registered terrain objects by base family with N/E/S/W direction cycling.
- Inspect an object through independent, stackable representations: vector footprint, collision AABB, GLB mesh, theater context.
- Camera parity with gameplay/editor by default, plus a free-orbit mode and an auto-turntable.
- Info box with per-cell data and click-to-highlight linkage into the 3D view.

**Non-Goals:**
- Entity previews, MainMenu entry point, theater switching (desert/winter — #211), editing/painting/placement, physics bodies, search/filter beyond family grouping.
- Any change to `TerrainRenderer`, `TerrainCollision`, or `TerrainSystem`.

## Decisions

**D1. Direct GLB submesh instantiation, not the cell-grid renderer.**
The mesh state loads `placeholder_terrain01.glb` once, finds the `MeshInstance3D` node whose name equals `TerrainArtData.mesh_name(variant_id)`, and instantiates a duplicated mesh at the object origin, rotated by `mesh_rotation(variant_id)`. Rationale: the catalog art is one submesh per family, so a single instance (not a MultiMesh grid) is correct and trivially cheap. Alternative (reuse `TerrainRenderer` per-cell) rejected: it cannot represent multi-cell footprints and would couple the preview to cell-state bookkeeping.

**D2. Footprint grounding via baked corners, not cell coords.**
Placement computes the footprint AABB from every occupied cell's `corners` (4 absolute heights each): translate so `min_y` lands on 0 and `min_x/min_z` cell on the world origin. The variant's baked origin is already normalized in the catalog. Rationale: corners are the geometry source of truth; cell indices alone don't carry height. Alternative (place by cell index) rejected: it ignores the vertical component and mis-grounds ramps/cliffs.

**D3. Reuse existing camera + env scenes; add one orbit controller.**
The scene instances `DefaultSunLight01`, `DefaultWorldEnvironment01`, and `Camera01.tscn` unchanged for default isometric behavior. A new lightweight `OrbitCameraController` (Node3D sibling, toggled on/off) orbits a fixed pivot, wheels to zoom, and pans with MMB/right; it reuses `Camera01`'s orthographic setup. The turntable is implemented as object Y-rotation in the preview controller's `_process`, not camera motion — decoupled from camera mode so it works in both. Alternative (reuse `CameraController` and hack orbit into it) rejected: `CameraController` is gameplay-coupled (`BoundsSystem` clamping, border panning, `move_map` pan).

**D4. Vector + collision states as debug mesh overlays.**
Both are wireframe primitives built with the same low-level primitives `DebugVisualizer` uses (immediate/array mesh lines + small marker boxes for corner heights). Vector = per-cell outline quads on the ground plane + a height pillar/marker per corner; collision = one `AABB` box from D2's min/max. They are plain `MeshInstance3D` children of the object node, toggled via `visible`. Rationale: zero physics, zero collision-tree coupling, cheap to build, and they never fight the mesh state. Alternative (StaticBody + trimesh from `TerrainCollision`) rejected: physics layers are slated for rework (#208/#209) and a preview needs no simulation.

**D5. Info box as a Control in the scene's own CanvasLayer.**
`AssetPreview.tscn` gets a `CanvasLayer` + `PanelContainer` HUD (buttons for prev/next, family dropdown, direction cycle, camera toggle, spin, state checkboxes; and the info table). The per-cell table is an `ItemList`/`Tree`-style list; row selection emits a signal the preview controller handles by spawning a short-lived highlight mesh on that cell. The table reflects `TerrainObject` data and the art/theater context resolved for the current variant. Rationale: matches existing `Sidebar`-style HUD patterns (CanvasLayer + Control) and keeps 3D and UI concerns separate.

**D6. Input via new InputMap actions.**
`project.godot` gains `asset_preview_next/prev/dir_cycle/cam_toggle/spin/state_cycle`. HUD buttons call the same handlers as `_unhandled_input` key checks. Rationale: consistent with existing action conventions (`camera_up`, `move_map`) and InputSettings remapping; avoids magic keycodes.

**D7. Mesh name resolution duplicated as a small helper for tests.**
The GLB node-name cross-check (spec: "every variant's mesh_name resolves to an existing submesh") needs a list of GLB submesh names. A tiny shared helper (e.g. `TerrainArtData.mesh_name()` stays the resolver; a test-side loader lists GLB node names) keeps the test independent of the engine renderer. Rationale: the fallback table is the bridge between catalog family ids and placeholder GLB names (e.g. `cliff27 -> cliff14`) and is exactly the thing that can rot silently.

## Risks / Trade-offs

- **Placeholder art approximates real tiles** → fallback-resolved meshes (`cliff27→cliff14`) won't match baked footprint geometry exactly. Mitigation: the info box shows the resolved mesh + fallback source so drift is visible, and tests pin resolution to existing submeshes. Real art (#210) plugs in via `TerrainArtData` without touching the preview.
- **Footprint origin interpretation** → D2 assumes the catalog's origin-normalized min cell maps to world origin; if a future generator changes normalization, grounding shifts. Mitigation: placement derives from baked corners only, and the AABB test covers known tiles.
- **Scene-load smoke test may be flaky headless** → the integration test asserts load + mesh-state node presence + error-free cycling rather than visual output; it avoids physics and rendering assertions that vary headless.
- **Orbit camera duplicate of gameplay camera** → small standalone controller is simpler than decoupling `CameraController`; if gameplay later needs orbit, it can be promoted and shared.

## Migration Plan

No migration: additive scene + data tests + input actions only. Rollback = remove the scene, its scripts, the InputMap actions, and the new tests.

## Open Questions

- None blocking. Future iterations decide the MainMenu entry point and entity previews (both recorded as non-goals in the proposal).
