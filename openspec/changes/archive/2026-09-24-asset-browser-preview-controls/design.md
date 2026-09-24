## Context

`AssetBrowserController.gd` already builds the browser's HUD and overlays in code; `scenes/AssetBrowser.tscn` only carries the camera, lighting, environment, and empty `ObjectRoot`/`WorldOverlays` nodes. The select/health preview, theater selector, and rotation reset are implemented and tested but undocumented in the `asset-browser` spec, so the contract can silently diverge from gameplay. The gameplay reference for the select box and structure health bar is `SelectComponent`.

The preview already grounds assets by centering children on the bounds center and offsetting `ObjectRoot`. For buildings, the min-corner must land at the world origin so the on-screen foundation grid (`foundation` cells) aligns with gameplay `cell_origin_to_world`.

## Goals / Non-Goals

**Goals:**
- Define the select/health preview, theater selector, and rotation reset as testable `asset-browser` requirements.
- Keep the preview geometry a faithful mirror of gameplay without importing gameplay nodes.
- Preserve the existing overlay-toggle model: Select is one more stackable, 3D-only state.

**Non-Goals:**
- No gameplay changes; `SelectComponent` and `TerrainCatalog` are read-only references.
- No new scene nodes or InputMap actions beyond the HUD button/dropdown.
- Non-visual data categories remain #410.

## Decisions

- **Select preview is a stackable overlay (`OVERLAY_SELECT`), default on.** Reuses the existing `get_overlay_node`/`set_overlay`/visibility plumbing instead of a separate toggle path. Default-on because the select box is the primary framing cue; gameplay also shows it on selection.
- **Draw the select box and health bar with `ImmediateMesh`/`BoxMesh` under `ObjectRoot`, authored in centered local space.** The box uses `foundation × CELL_SIZE` for buildings and mesh bounds otherwise; the health bar is a full-depth `BoxMesh` scaled and rotated `-90°` about Y, positioned at the box top's left edge along Z — the same construction as `SelectComponent._build_segmented_bar(span_is_x=false)`. Authoring in centered space keeps it rotating with the asset and avoids re-applying `_object_center`.
- **Theater selector writes through `TerrainCatalog.set_active_theater(id)` and refreshes the preview.** `_rebuild_theaters()` runs at boot and on `game_changed`; the option is disabled when only one theater exists. This reuses the autoload rather than duplicating theater state in the browser.
- **Reset rotation restores `_base_yaw_deg` and zeroes pitch** via the existing `_apply_object_transform`, rather than caching a transform snapshot. The authored base yaw is already folded in at finalize time.
- **Zoom is computed once (`_zoom_initialized`) and on projection toggle, not per selection.** Removes per-asset re-framing so the user's zoom survives asset changes; `set_camera_mode` recomputes the default because the two projections use different zoom quantities.
- **`_collect_bounds` includes the node it is given.** A helper that silently drops the passed mesh is a footgun for tests and future callers; `_object_bounds` passes the non-mesh `ObjectRoot`, so its behavior is unchanged.

## Risks / Trade-offs

- [Select box size for buildings uses `EntityData.height`, which may differ from the model's mesh height] → The select box intentionally mirrors the gameplay logical box; the collision overlay already exposes mesh bounds, so the two are shown side by side.
- [Health bar geometry could drift from `SelectComponent`] → The integration test asserts the bar's Y top aligns with the select box top and that the bar is yawed `-90°`; any gameplay change to the bar construction should update both.
- [`_collect_bounds` self-inclusion changes a shared helper] → `_object_bounds` passes `ObjectRoot` (not a mesh) and the existing grounding/camera tests still pass; the change only affects callers that pass a mesh node directly.
- [Theater switch mutates a global autoload from a dev tool] → Same ephemeral pattern as game selection; the browser does not persist the theater choice.

## Migration Plan

Not applicable — dev-tool only, no persisted state, not referenced by `MainScene`.

## Open Questions

None.
