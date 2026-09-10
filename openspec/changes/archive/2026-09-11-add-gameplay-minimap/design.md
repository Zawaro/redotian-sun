## Context

The gameplay HUD currently has no minimap. The MapEditor ships a 3D-subviewport minimap (`scripts/editor/Minimap.gd`) built from an `ImmediateMesh` terrain, per-frame `ImmediateMesh` entity dots, and a wireframe view rectangle. The fog-of-war data layer is merged: `ShroudSystem` owns the authoritative per-player grid with `explored`/`visible_count`/`resolved` and a `state_changed(dirty)` signal, and `FogRenderer` consumes it. The minimap color resolvers landed in #178 but have no consumer for terrain: `TerrainCatalog.get_cell_art`, `TerrainArtData.minimap_color`, `TerrainArtData.shade_map_color`, and `ArtData.minimap_color`.

Terrain cell coordinates are already diamond-extent space (`CellUtil.get_diamond_extent`), the same index space `ShroudSystem` uses (`idx = y * width + x`). The playable area is a diamond inscribed in that square.

Constraints: pure GDScript; packed scenes must stay loadable; the runtime MapEditor must not show the gameplay minimap; input in this codebase is polled from the `Input` singleton by several handlers, which does not respect `set_input_as_handled`.

## Goals / Non-Goals

**Goals:**

- A gameplay minimap rendering terrain, resource/overlay objects, entities, fog, and the camera view rectangle.
- Click-to-command (same orders as the world) with snap-pan fallback.
- Correct input ownership so world handlers ignore minimap clicks.
- Reuse the existing color and fog systems; no duplicated visibility computation.
- Headless-testable geometry and color logic.

**Non-Goals:**

- Radar gating (minimap hidden until a radar structure exists) — deferred to #40/#246.
- Selecting entities from the minimap.
- Building/unit placement from the minimap.
- Minimap-driven unit selection or drag-select.
- Multiplayer networking of fog state.
- Replacing or modifying the MapEditor minimap.

## Decisions

### 2D baked image, not a 3D SubViewport

The minimap SHALL be a `Control` (`scripts/ui/Minimap.gd`) that draws a baked `ImageTexture` directly in `_draw()` (alongside the camera view rectangle), not a `SubViewport` + second `Camera3D`.

Rationale: terrain is already an abstract per-cell color (the color resolvers output flat colors, not rendered meshes), and the diamond cell space maps 1:1 onto a rectangular texture. A 2D image needs no extra render pass, no cull masks, no viewport stretch math, and no rotation/alignment work. It also makes the view-rectangle overlay and fog composition trivial.

Alternative considered: reuse the editor's 3D subviewport and feed `minimap_color`/`shade_map_color` into per-vertex colors. Rejected: keeps an extra render pass, per-frame `ImmediateMesh` rebuilds, and the diamond↔viewport alignment problem, for no visual gain.

### One index space for terrain, fog, and entities; one orientation transform for display

Dims = `CellUtil.get_diamond_extent(TerrainSystem.grid_cells)`; texel index = `cell.y * dims.x + cell.x`. Terrain texels, fog texels, and entity cells all share this index space — no reprojection is needed for the bake itself.

Display is a separate concern: the revealable play area is the map diamond inset by `BoundsSystem`'s visible-bounds insets (a smaller diamond in index space), while the gameplay camera is yawed ~45°, so on screen it reads as an axis-aligned rectangle. A single affine transform rotates index space by 45° and maps the inset play bounds onto the control rect, cropping the permanently-shrouded rim. It is applied consistently in three places: the texture draw (via `draw_set_transform_matrix`), `_pixel_to_cell` (its inverse), and the camera view rectangle. The control is resized to the play-diamond aspect (`Minimap.size_for_play_area`) so the play area fills it without letterboxing.

Alternative considered: no transform (map cell axes straight to pixels). Rejected: this is the original bug — the minimap renders 45° out of phase with the gameplay view, showing the diamond as a diamond.

### Orientation, aspect, and cropping the shrouded rim

`ShroudSystem._revealable` is `BoundsSystem.is_in_play_area`, so the ring between the map diamond and the inset play diamond is never revealable and stays permanently shrouded. Rendering the full map diamond therefore shows a black margin around the play area. The minimap crops to the inset play diamond: `Minimap.in_play_area` (a pure mirror of `BoundsSystem._in_play_diamond`) gates the terrain bake, and `Minimap.index_to_pixel` / `pixel_to_index` map the inset play bounds to the control rect. `Minimap.size_for_play_area` sets the control aspect to the two play-diagonal spans `(2W - left - right):(2H - top - bottom)`. Insets are captured from `BoundsSystem` at bake time into `_play_insets`; the deferred bake runs after `MapLoader.apply_saved_bounds`, so they are applied. Linear texture filtering avoids aliasing under the rotation.

### Terrain is baked once; overlay+fog at low frequency

Terrain colors do not change during gameplay because resources are rendered as overlay objects rather than a terrain land type (see below). The terrain bake runs on `grid_initialized` and is regenerated only when a new grid initializes. Entities, overlay objects, and fog are re-composed over the terrain base on a fixed low-frequency timer (default 2 Hz, exported). This matches the accepted "really low update rate" and keeps the per-frame cost to the view rectangle only.

Alternative considered: dynamic terrain rebake to track land-type/tiberium changes. Rejected for this change: tiberium is an overlay, and no other in-game land-type mutation exists.

### Terrain color uses painted land type only

The bake resolves each cell as `shade_map_color(TerrainArtData.minimap_color(TerrainCatalog.get_cell_art(cell_data), land_type), height_ratio, theater.low_radar_brightness, theater.high_radar_brightness)`, where `land_type` comes from `GlobalRules.get_land_type(TerrainSystem.get_painted_land_type(cell))` — not `get_land_type()`. `get_land_type()` derives `"resource"` from the live `SpatialHash` resource registry; using it would bake tiberium into the terrain and freeze it. Resources render as overlay dots instead, consistent with the world fog overlay's treatment of `ResourceComponent` objects.

### Overlay and fog composition in one pass

On each refresh: copy the terrain bytes, multiply each texel by the local fog factor from `ShroudSystem.get_effective_state`, then stamp entity/overlay dots. Shroud cells become black, explored cells are dimmed, visible cells keep terrain brightness; dots use `ArtData.minimap_color`, falling back to the resource type's color for resource overlays that carry no art (tiberium crystals are `resource_category == "tiberium"` and receive no `ArtComponent`), and are omitted (shroud), dimmed (fog), or full (visible) per `ShroudSystem.cell_state_to_local`. Dots are sized by the entity's footprint: buildings carry a `FoundationComponent` (created only when the foundation is larger than 1x1) and occupy one texel per foundation cell anchored at the footprint origin; units and resource crystals are a single texel (1 cell). The refresh also builds a `cell -> target` index of revealed entities over every footprint cell for click resolution. Fog uses the same `shroud_enabled`/`fog_of_war` toggles as `FogRenderer`.

Alternative considered: a shader compositing separate terrain and fog textures, updated exactly on `state_changed`. Rejected as unnecessary: at 2 Hz the ~0.5 s reveal latency is imperceptible on a radar, and a single image avoids another shader and texture pair.

### View rectangle clipped to the minimap

The camera's ground footprint is drawn every frame as a wireframe quad. When the camera is zoomed out, that quad is larger than the minimap and would paint over neighbouring HUD. `Control.clip_contents` clips children only, not the control's own `_draw`, so each edge is clipped in code with `Minimap.clip_segment_to_rect` (Liang-Barsky against the four control edges) and only the visible segments are drawn with `draw_line`. Clipping per edge — rather than clipping the polygon — means a large view footprint shows only the parts of its own edges that are inside the minimap, instead of acquiring artificial edges that trace the minimap border. A fully-zoomed-out camera draws no edges at all, which reads correctly as "the whole map is on screen".

### Click routing through the existing order funnel

A left-click maps minimap-local position → texel → cell → world. If an entity is indexed for that cell, it is passed as the order target; otherwise the cell position is the ground target. The minimap then calls `OrderSystem.get_orders(target, cell, world, modifiers)` and executes the returned `OrderResult`s, exactly as `MouseHandler` does. `UnitOrderGenerator` returns an empty array when nothing is selected, and `OrderSystem` already applies the bounds and fog gates, so the minimap inherits all targeting validation for free. If no orders are produced, it calls `BoundsSystem.center_camera_on_cell(cell)` to snap-pan. Modifiers reuse `MouseHandler.build_modifiers`. While a build or placement mode is active, a minimap click only snap-pans and issues no orders. Left-click only; right-click is not consumed, preserving the deselect/cancel convention.

### Input ownership via a shared UI query

Because `MouseHandler`, `BuildingManager`, and `EntityPlacer` poll the `Input` singleton in `_process` (which ignores `set_input_as_handled`), the minimap node is named `Minimap` and `UIUtil.is_mouse_over_minimap()` (cached, mirroring `find_sidebar`) is checked by all three pollers. The minimap `Control` uses `mouse_filter = STOP` and calls `accept_event()` so GUI-phase consumers are handled; `EntityPlacer._unhandled_input` already respects handled events.

### Layout: credits detached, sidebar shifted down

The credit label is extracted from `Sidebar.tscn` and placed at the top of the right-hand HUD column (above the minimap), and the Sidebar root is shifted down. To keep the credit counter integration-testable, the label plus its `CreditCounter` script moves into a small dedicated scene (`scenes/ui/CreditsLabel.tscn`) instanced in `MapBase01.tscn`. `Sidebar.gd` does not reference the label, so removal is safe. The existing `test/integration/test_sidebar_credits.gd` is repointed (and renamed) to the new scene.

Alternative considered: keep the label inside `Sidebar.tscn` and insert the minimap below it. Rejected per the chosen layout (Option A): the sidebar itself must sit below the minimap, which requires the label to be detached.

### Extraction of pure logic for tests

Color resolution, cell↔texel mapping, fog-factor mapping, and fog gating are implemented as static functions on `Minimap` so they can be exercised headless without instancing a `Control`. The existing `test_terrain_minimap_color.gd` and `test_artdata_minimap_color.gd` already cover the color resolvers, so `test_minimap.gd` covers mapping and gating only.

## Risks / Trade-offs

- **Theater ordering** — `MapLoader` calls `TerrainSystem.import_from_json` (emits `grid_initialized`) before `TerrainCatalog.set_active_theater`. Baking synchronously could use the fallback theater's radar brightness. → Defer the terrain bake by one frame (or rebake when the active theater id changes on the first overlay refresh).
- **Input double-fire** — the three `_process` pollers will each handle a minimap click unless all three guards ship together. → Ship `UIUtil.is_mouse_over_minimap` plus all three call-site guards in the same change; cover with the "input ownership" spec scenarios.
- **Static terrain** — any future in-game painted-land-type mutation would not appear until a grid rebake. → Documented; a rebake hook can be added if such a feature lands.
- **Fog latency** — fog edges lag the `ShroudSystem` 0.25 s resolve tick by up to one bake interval. → Accepted; the interval is exported and tunable.
- **Credit label test relocation** — `test_sidebar_credits.gd` currently instantiates `Sidebar.tscn` and reads `%CreditsLabel`; removing the label breaks it. → Repoint the test to the new credits scene in the same change.
- **`get_effective_state` cost** — recomputes the whole grid each bake. → Acceptable at 2 Hz for the diamond extent; the entity/fog bake is not on the per-frame path.
