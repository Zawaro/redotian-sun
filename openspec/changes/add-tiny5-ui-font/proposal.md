# Proposal: add-tiny5-ui-font

## Why

All UI text currently renders in engine/theme default fonts (Poppins on the main menu, fallback elsewhere), which does not match the Tiberian Sun aesthetic. The selection overlay draws no entity name labels at all, so players cannot identify a selected unit without hovering for the tooltip. The Tiny5 pixel font (OFL, Google Fonts) was chosen for its 5x5 superellipse pixel look.

## What Changes

- Add the Tiny5 Regular font asset (`assets/fonts/Tiny5/`, TTF + OFL license, already added) with pixel-crisp import settings: antialiasing off, hinting off, subpixel positioning disabled
- Sidebar build-cameo labels (`scripts/ui/Sidebar.gd`) restyled: Tiny5, 10px, white, 1px black outline, left-aligned, uppercase rendering; autowrap stays; cost label kept with the same styling
- Selection overlay (`scripts/ui/SelectionOverlay.gd`) gains entity name labels: `display_name` from `StatsComponent` collected per entity, drawn below the bracket via `draw_string_outline` + `draw_string` in Tiny5, white with 1px black outline, uppercase; shown for selected and hovered entities
- Existing power readout label on the overlay switches to Tiny5 with the same 1px black outline; green color and size unchanged
- Uppercase is a render-time transform (`.to_upper()` / Label uppercase property); `EntityData.display_name` resources are NOT edited

## Capabilities

### New Capabilities

- `ui-typography`: Font styling rules for in-game UI text — the Tiny5 font asset and its import requirements, plus where/how text surfaces apply it (sidebar cameo labels, selection overlay entity name labels and power readout): sizes, colors, outline, alignment, uppercase rendering

### Modified Capabilities

(none — `cameo-tooltip` and `sidebar-build-order` requirements are unchanged; tooltip still carries name/cost/time/power)

## Impact

- **Scripts**: `scripts/ui/Sidebar.gd` (cameo label construction), `scripts/ui/SelectionOverlay.gd` (`_collect_entities` dict, new `_draw_name_label`, `_draw_power_label` font swap)
- **Assets**: `assets/fonts/Tiny5/Tiny5-Regular.ttf`, `OFL.txt`, generated `.import` (new)
- **No scene file changes**: cameo labels and overlay draws are built in code; no `.tscn` edits, so backward compatibility with packed scenes is unaffected
- **No data changes**: `EntityData.display_name` resources untouched
- **Tests**: `test/unit/test_selection_overlay.gd` extended for `display_name` in the collected entity dict
