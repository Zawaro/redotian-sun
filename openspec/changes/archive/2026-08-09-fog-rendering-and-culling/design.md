# fog-rendering-and-culling — Design

## Context

ShroudSystem (#197, `scripts/core/ShroudSystem.gd`) is the authoritative per-player fog grid: ref-counted revealers, height-aware Bresenham shadowcasting, allied query-time union, incremental dirty resolution on a 0.25s tick, and a ready-made `get_effective_state(local_player)` returning a row-major `PackedByteArray` (0=shroud, 1=fog, 2=visible) sized `grid.x * grid.y`. It is simulation-only; nothing consumes it visually.

The game renders 3D directly to the root 1920×1080 viewport through `scenes/hud/Camera01.tscn` (orthographic, `current=true`, shared `World3D`). The 960×540 pixel-art SubViewport pipeline (`PixelArtManager`/`EntityMaskManager`/`PixelArtOutline01.gdshader`) is orphaned dead code (commit `4cc5e3f`, never registered, never instantiated; `plans/00-0_project_status.md:90`). Units render through `UnitMeshRenderer` MultiMesh buckets (GLB tree hidden, one instance per unit synced every physics frame); buildings render via their own node trees.

## Goals / Non-Goals

**Goals:**
- Visual shroud/fog/visible overlay as a world-aligned plane in the shared world, sampling a grid texture rebuilt only when cells change.
- `VisionComponent` wiring player-owned `sight > 0` entities as ShroudSystem revealers (units re-stamp on cell crossing, buildings permanent).
- Fog-driven visual culling: enemy units hidden in shroud, frozen as last-known ghosts in fog, drawn when visible; enemy buildings hidden in shroud and persisting in fog; friendly entities never hidden. Visual-only (`node.visible` / renderer instance parking/freezing) — never touches simulation. Coverage of ALL entity types is an open gap: decorations/terrain/overlay (Tiberium, trees, rubble) and node-tree-fallback units currently leak through shroud (#276), and the freeze-in-fog treatment has not been generalized beyond units and static buildings (#275).
- Fully headless-testable; inert when `fog_of_war == false`.

**Non-Goals:**
- No pixel-art SubViewport wiring — `PixelArtManager` stays dead, gets its own issue.
- No gameplay minimap fog (#177), no radar reveal (#40). The unit ghost-freeze ships here; generalizing the freeze/hide treatment to all entity types is tracked as follow-ups (#275 freeze-in-fog, #276 hide-in-shroud) and intentionally not part of the initial culling scope.
- No shadowcasting changes (already shipped in #197).
- No per-player desync-hash / netcode.
- Follow-attack blocker pathing (#277) is a combat/movement gap, not a fog concern — tracked separately.

## Decisions

### 1. World-aligned fog plane, not full-screen-quad post-process
Copy the in-repo precedent `shaders/environment/CloudShadowPlane.gdshader` (`blend_mix, depth_draw_never, cull_disabled, unshaded`, world-XZ UV computed in `vertex()` from `MODEL_MATRIX`). The alternative — a full-screen quad reconstructing world position from the depth texture — is the dominant Godot 4 RTS pattern (lampe-games/godot-open-rts, My0Cents/Fog_Of_War) but depends on orthographic depth reconstruction, which is fragile in this engine: godot#66007 (ortho depth differs vs Godot 3.5), godot#85107 (SubViewport depth precision loss); working examples need perspective or an in-shader `inverse(PROJECTION_MATRIX)` workaround. This game's camera is orthographic. The plane approach needs no depth texture, works identically in any viewport of the shared world, and fits the cellular grid with `filter_nearest` + `discard`.

Plane geometry (centered square + rim, `CELL_SIZE = 2.0`): the fog grid is sized to the diamond extent (`CellUtil.get_diamond_extent(grid_cells)` = W+H cells per axis — for the default 50×50 grid that's 100×100 cells, world `[-100, 100]²`). Plane covers extent × CELL_SIZE, centered at world origin. The plane is a **draped grid mesh** (`ArrayMesh`, one vertex per terrain vertex) with each vertex at `TerrainSystem.get_vertex(vx, vz) * HEIGHT_STEP + PLANE_EPSILON` (0.15). Draping makes the shroud follow slope shapes and — because the reveal edge now sits at the terrain surface instead of a flat sheet at max height — removes the camera-parallax offset that a constant-height plane causes under the tilted ortho camera (screen offset ≈ `0.866 × Δy`, i.e. ~3.5 cells for Δy = 8.2). The mesh covers **the whole map square plus a `RIM_MARGIN` (32 cells) of flat shroud on every side**, not just the map diamond: `TerrainSystem.get_vertex` returns 0 for out-of-diamond keys, so corner/rim cells drape flat at `PLANE_EPSILON`, and the shader forces UVs outside `[0,1]` (beyond the map square, where the texture holds no state and `repeat_disable` would otherwise clamp to playable edge texels) to the shroud state. The rim exists so the viewport stays shrouded when the ortho camera (size 20, clamped to the visible diamond) pans to a map edge — the viewport reaches up to ~40 world units past the diamond. The plane node is positioned at `PLANE_OFFSET = (40, 40 × HEIGHT_STEP, 40)` (a fixed world offset; the sheet and its texture mapping shift together, so the shroud pattern lands offset from the map — a deliberate render-position choice). For this to be visible the shader must sample the fog texture from the plane's **model space** (`VERTEX.xz`) — sampling from world space (`MODEL_MATRIX`) cancels an XZ translation exactly, because the geometry and the sampling basis move together (a bug caught in-game: the XZ offset appeared "totally ignored"). The Y offset still lifts the sheet and shifts reveal edges on screen via camera parallax. UV mapping in the shader: `uv = (plane_xz - grid_origin) / grid_size` where `grid_origin = (-100,-100)`, `grid_size = (200,200)`. The mesh is rebuilt on `grid_initialized` (which fires twice during `import_from_json` — the second emit, after JSON vertex heights load, produces the correct draped surface).

> Orientation gotcha (found during implementation): Redot's `PlaneMesh` defaults to `orientation = FACE_Y` — the plane is already horizontal (XZ), unlike Godot 4's `FACE_Z` default. The plane node therefore must NOT apply a `-90°` X pitch; doing so stands the fog overlay vertical. The codebase's other horizontal planes (CloudShadowPlane, TestMap01 ground) also rely on the FACE_Y default with no X rotation.

> Note: #197 originally sized the ShroudSystem grid to `TerrainSystem.grid_cells` (50×50), tracking only the SW quadrant (cells 0..49) of the actual 100×100 diamond — 74% of the play area would have stayed permanently shrouded. This change fixes the sizing to the diamond extent, which the plane, `is_in_play_area`, and `CellUtil` cell↔world mapping all assume.

**Alternative considered:** full-screen depth quad — rejected (ortho depth fragility, more moving parts, dims visible-unit pixels via alpha instead of exact `discard`).

### 2. `FogRenderer` autoload owns plane + texture + building pass
New singleton registered in `project.godot` after `ShroudSystem` (last), matching the "autoload Node adds visual children to the shared world" pattern (`UnitMeshRenderer`, `TerrainRenderer`). It owns: the fog plane `MeshInstance3D` + material, the `ImageTexture` rebuild, and the building-culling pass. **Alternative considered:** plane as a scene node like `CloudShadowOverlay` — viable, but autoload gives one owner for plane + texture + building culling and works in any scene, not just map scenes.

### 3. Unit culling inside `UnitMeshRenderer`, not a per-entity component
A `FogCullingComponent` on every entity would be strictly more code for the same result: `UnitMeshRenderer._physics_process` already iterates every unit each physics frame and already parks instances at `HIDDEN_POSITION` (lines 11, 169, 203). Per-entity polling is also against the codebase's cross-cutting-loop convention (systems with registries — `SpatialHash._entry_map`, `UnitMeshRenderer._registry` — and `test_perf_guard.gd` forbids per-frame group scans), and a component caching `player_id` in `_ready` would hit the deploy-path bug where `stats.player_id` is set after `add_child` (`DeployComponent.gd:507`; `MovementController.gd:88` is the live example).

So: a fog branch inside `UnitMeshRenderer._physics_process` (after the preview branch, ~line 204): read the cached `StatsComponent` per frame; if enemy (`PlayerManager.is_enemy`) and `not is_cell_visible_to_local(cell)` → park the instance at `HIDDEN_POSITION`, GLB tree stays hidden. The `state_changed`-driven rebuild also keeps a shared effective-state buffer available for these checks.

Fog-vs-shroud is a three-way split keyed on `is_explored` vs `is_visible`: visible → sync; explored-but-not-visible (fog) → **freeze** the instance at the current transform once (ghost of last-known position, no per-frame sync, no region migration); unexplored (shroud) → park off-world. The ghost dimming comes free from the fog plane: it is a transparent `blend_mix` quad above terrain and ground-level models, so in fog cells it blends dark over the frozen unit, producing the C&C translucent-ghost look without per-instance materials. Frozen ghosts re-migrate only on reveal (snap to current position).

### 4. Building culling via `entity.visible` + explored gate
Buildings render via their own node trees, so `entity.visible = is_explored(local, cell)` works directly (shown once explored, persists in fog — matches C&C shroud/fog semantics: structures and unit ghosts visible as last seen, shroud hides everything). Buildings are static; the pass runs on the 0.25s resolve tick (or per-frame over a small registry), keyed from a light event-driven registry (`tree.node_added/node_removed` + "entities" group + BUILDING type — `SpatialHash` pattern), avoiding any per-frame group scan.

### 5. `state_changed` signal on ShroudSystem
`resolve_dirty()` currently returns a count and emits nothing. Add `signal state_changed`, emitted when `processed > 0`. Matches the codebase's "signal up, call down" convention (`TerrainSystem.cell_changed`, `EconomyManager.credits_changed`). The renderer does a cheap `PackedByteArray` compare against its cached buffer to filter allied-only noise before rebuilding. **Alternative considered:** a revision counter (polled) — less idiomatic; renderer polling `get_effective_state` on its own timer duplicates the 0.25s cadence and is fragile.

### 6. `VisionComponent` lazy registration
`configure(data)` captures sight/entity_type/height/foundation. Registration happens from `_physics_process` (first tick with `player_id >= 0`), not `_ready()` — the deploy/undeploy path sets `player_id` after `add_child`. Cell-crossing poll (MovementController pattern) re-registers only on cell change. Buildings register once then `set_physics_process(false)`. `viewer_height = global_position.y + eye_offset` (terrain basis; `data.height` absolute would self-block on plateaus). `blocks_terrain = entity_type != AIRCRAFT`. Multi-cell buildings reveal from footprint center. `_exit_tree()` unregisters (null-safe, tracks `_registered_player_id` separately). Attach condition in `EntityFactory._add_components`: `sight > 0` **and** type ∈ {INFANTRY, VEHICLE, AIRCRAFT, BUILDING} — the type whitelist is mandatory because 168 terrain/overlay resources inherit the `sight = 1` default and would otherwise all become revealers.

### 7. Texture encoding
`get_effective_state` bytes (0/1/2) go directly into a `FORMAT_L8` `Image` (`Image.create_from_data`) → `ImageTexture`. Raw state stays in the texture; the shader remaps (`state >= 1.5` → discard; `>= 0.5` → fog dim; else opaque black shroud). Keeps presentation tweakable (fog_darkness uniform) and the same buffer reusable by the minimap (#177). Texture is `extent.x × extent.y` to match the fixed grid sizing.

> L8 sampling gotcha (fixed during implementation): `FORMAT_L8` bytes sample normalized to [0,1] in GLSL, so the state values arrive as 0/255, 1/255, 2/255 (≈0, 0.004, 0.008) — all below the 0.5/1.5 thresholds, which would classify every cell as opaque-black shroud. The shader therefore scales the sample back: `textureLod(fog_grid, uv, 0.0).r * 255.0` restores 0/1/2 and the thresholds classify correctly.

### 8. Independent shroud / fog toggles
The single `fog_of_war` gate was split into two `GlobalRules` flags: `shroud_enabled` (default true) and `fog_of_war` (default false). Shroud = the opaque-black unexplored layer + hiding entities in unexplored cells; fog of war = the translucent dim over explored-but-not-visible cells + unit ghosting. `ShroudSystem.is_cell_visible_to_local` collapses the two: visible → visible; unexplored → visible only when shroud off; explored-not-visible → visible only when fog off; both off ⇒ everything visible (the old inert behavior). The plane shader receives `shroud_enabled`/`fog_enabled` uniforms and discards the fog branch when fog is off and the shroud branch when shroud is off; `FogRenderer.refresh()` re-applies uniforms + rebuilds the texture after a debug-menu toggle. `cover_shroud(player_id)` zeroes `explored` for the player and its allies then re-stamps only active revealer radii (via air-style shadowcasting, untouched visible counts), so covering reverts everything except allied/own sight.

### 9. Soft-edged shroud and fog via a signed-distance field

> **STATUS — REVERTED.** This SDF stack shipped in the initial checkpoint (#198) but was removed for look/perf: the SDF halo read badly and the per-rebuild EDT cost was a concern; a follow-up boundary-ribbon mesh was also reverted ("didn't work properly"). The current shipped behavior is **hard cell edges** (nearest-filtered L8 state texture, flat per-cell opacity). Soft edges are an open gap tracked by #274, with the mechanism re-opened — any re-implementation must stay single-draw and avoid a per-frame CPU bake. The text below documents the original (reverted) approach for reference.

The hard 0/1/2 texel step at reveal frontiers aliases under pan/zoom and leaves a crawling ring on the vision trail. Keep the L8 state texture (`filter_nearest`, `fog_grid`) for crisp classification and add a second tiny texture `fog_soft` (RGBA8, `filter_linear`; R = signed distance to the shroud boundary, G = signed distance to the fog boundary). Distances come from a two-pass Felzenszwalb–Huttenlocher Euclidean distance transform (O(n); sub-millisecond on the ~10k-cell grid; runs only inside the existing `_rebuild_texture`, already gated by the buffer compare): `sdist = dist_to_nearest_source_cell − SDF_BAND (0.5)`, so the region boundary sits at 0 and the covered-cell interior is negative. Clamped to ±SDF_BAND and byte-packed (`byte = (sdist + 0.5) · 255`); only the ±0.5 band is ever visible, so deep cells clamp losslessly.

The key property: **bilinear filtering of a distance field interpolates linearly between texel centers, so its 0-crossing lands exactly on the cell boundary**. A covered cell therefore renders fully opaque across its entire footprint (no blur inside the cell, and no margin ⇒ no 2×2 phantom footprint), and the halo starts at the cell edge at full opacity, reaching 0.0 exactly `*_falloff` cells out (default 0.5, i.e. the adjacent visible cell's center). The shader's visible branch decodes `d = byte/255 − 0.5` and applies `alpha = 1 − smoothstep(0, falloff, d)` per channel, dimming halo-carrying visible cells toward the adjacent region's intensity (`ALPHA = min(1, shroud_color.a·α_r + fog_darkness·α_g)`, fog gated on `fog_enabled`); deep visible cells (both α ≈ 0) discard. Shroud and fog branches stay uniform opaque/dim; the rim forces a deep-covered SDF so the off-map viewport stays black. `SHROUD_FALLOFF`/`FOG_FALLOFF` are presentation-only uniforms (halo width), tunable without a rebake.

Research basis: storing *distance* (not coverage) and letting the filter's 0-crossing define the crisp edge is the standard grid-fog technique (OpenRA-style per-cell transition tiles are the alternative; compute-shader jump flooding is overkill while updates are discrete events). Trade-offs: convex corners get a subtle bevel (~0.13 alpha dip at the exact corner point after the ±0.5 clamp) — the familiar bilinear look; 8-bit quantization is ~0.004 cells, invisible. If pixel-sharp corners ever matter, re-bake the same SDF at 4× texels per cell (identical shader).

## Risks / Trade-offs

- [Draped plane coplanar with the terrain surface (z-fighting)] → `PLANE_EPSILON` 0.02 keeps it uniformly above the tile surfaces (tiles interpolate the same vertex heights the mesh uses); linear ortho depth keeps the 0.02 separation cleanly distinguishable.
- [Entities above the shroud sheet poke through un-dimmed] → the sheet now sits at `PLANE_OFFSET.y = 40 × HEIGHT_STEP` (≈32.6), above every ground entity and jumpjet (altitude up to ~13); only entities above 32.6 (high-altitude aircraft) still poke through. Accepted; the raised sheet also depth-occludes all ground entities in shrouded cells, which is the primary mechanism for hiding them (#276).
- [Grid/diamond alignment: 50×50 grid covers only the SW quadrant of the map diamond] → verify against real map data during implementation before fixing plane geometry; `get_effective_state` already stamps out-of-play cells shroud so corners render black consistently.
- [Allied-only resolve noise fires `state_changed` for the local player] → renderer buffer compare; 4KB scan is trivial at ≤4 signals/s.
- [UnitMeshRenderer fog coupling (StatsComponent lookup per unit per frame)] → cache the stats ref in the registry entry at `register()`; SpatialHash does the same pattern.
- [Selected-but-fogged enemy unit keeps selection brackets] → cosmetic; SelectionManager already gates new selection on fog; fog plane covers it.
- [Deploy-path `player_id` after `_ready`] → VisionComponent and culling both read player_id per frame (never cache at `_ready`).
- [Per-entity polling overhead avoided] → central loops reuse existing iteration; N is ~100–500 entities, each check is a floor-div + packed-array read.
- [Coverage rebuild cost] → **moot** since Decision 9 (SDF `fog_soft`) was reverted; the current texture rebuild is a single L8 `Image.create_from_data` gated by the buffer compare. Any soft-edge re-implementation (#274) must respect this.

## Migration Plan

All changes additive: new autoload (`FogRenderer`), new components, one new signal, renderer branches that are no-ops when `fog_of_war == false`. No scene or `.tres` changes. Rollback = revert the branch; leaving the autoload registered but the plane absent is also safe.

## Open Questions

- Exact `fog_darkness` dim value (default 0.65) — tune in-game.
- Jumpjet poke-through: accept vs clamp vs second plane (deferred, see Risks).
- ~~Grid/diamond alignment~~ — **Resolved:** ShroudSystem grid sizing fixed to the diamond extent (see Decision 1 note); the fog plane, texture, and `is_in_play_area` all agree.

## Follow-ups (gaps surfaced by this change)

- **#274 — Soft edges for shroud and fog cells.** Decision 9 (SDF) and the ribbon mesh were reverted; hard edges are current. Re-implement cheaply (single-draw, no per-frame CPU bake) with a tunable width.
- **#275 — Visually freeze every entity under fog.** Units ghost-freeze at last-known position (shipped); buildings persist statically (shipped); the freeze treatment must be confirmed/generalized for all remaining entity types.
- **#276 — Visually hide every entity under shroud.** Buildings (`FogRenderer`) and MultiMesh units (`UnitMeshRenderer`) are hidden; decorations (TERRAIN/OVERLAY: Tiberium, trees, rubble), node-tree-fallback units, and unregistered entities leak. The raised opaque sheet covers ground entities via depth; per-instance gates must cover the rest.
- **#277 — Follow-attack pathing through blockers.** Out of scope for this change (combat/movement, not fog); a chasing attacker walks into buildings instead of routing around. Tracked separately.
