## Why

The asset browser previews assets in isolation, but three gameplay-facing facts an artist or designer needs are missing or unreachable: how the asset reads with its in-game selection box and health bar, what its art looks like under each theater, and a one-click way back to the authored facing after free rotation. The select/health geometry, theater switching, and rotation reset already work in the browser but are not part of the `asset-browser` contract, so they can drift from gameplay unnoticed.

## What Changes

- **Select + health preview** — a seventh stackable overlay that mirrors `SelectComponent`: corner-bracket selection box sized from the entity foundation (buildings) or mesh bounds, with the segmented structure health bar along the box top at the left edge (buildings only). Geometry uses the same axes, lengths, and `-90°` Y fill as gameplay.
- **Theater selector** — a HUD dropdown listing every theater from `TerrainCatalog.get_all_theaters()`, preselecting the active one and switching via `TerrainCatalog.set_active_theater(id)`, then refreshing the preview so terrain art, the theater label, and the ground read under the chosen theater. Disabled when only one theater exists.
- **Reset rotation** — a HUD button (and existing rotation entry points stay) that snaps the asset back to its authored base yaw and clears pitch.
- Fold the previously-spec'd zoom persistence into the camera requirement so the contract matches the shipped "compute default zoom once, preserve across asset changes" behavior.

## Capabilities

### New Capabilities
<!-- None: all behavior lands inside the existing asset-browser capability. -->

### Modified Capabilities
- `asset-browser`: the "Stackable render overlays" requirement gains the Select state and defaults; the "Asset rotation" requirement gains the reset-to-authored-facing action; a new "Selection and health preview" requirement defines the select box and structure health bar; a new "Theater selection" requirement defines the theater dropdown; the "Static framing camera with projection modes" requirement already carries the zoom-persistence clause added alongside this change.

## Impact

- **Scripts**: `scripts/editor/AssetBrowserController.gd` — `OVERLAY_SELECT`, `_build_select_preview`, `_build_select_box_mesh`, `_build_structure_health_bar`, `_select_box_size`, `reset_rotation`, `_rebuild_theaters`/`_on_theater_selected`, `_compute_default_zoom`/`_zoom_initialized`, `_collect_bounds`, `_finalize_object` grounding. No gameplay code touched.
- **Scenes**: `scenes/AssetBrowser.tscn` unchanged; HUD nodes are built in code.
- **Tests**: `test/integration/test_asset_browser_scene.gd` — zoom-persistence, reset-rotation, theater-listing, select/health-preview, and grounding assertions.
- **Spec**: `openspec/specs/asset-browser/spec.md` — the modified/added requirements above.
- **Autoloads consumed (unchanged)**: `TerrainCatalog` (theater list/active theater).

## Related

- GH #409 (asset browser), PR #411.
