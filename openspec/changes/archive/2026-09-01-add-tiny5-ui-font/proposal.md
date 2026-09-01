# Proposal: add-tiny5-ui-font

## Why

All UI text currently renders in engine/theme default fonts (Poppins on the main menu, fallback elsewhere), which does not match the Tiberian Sun aesthetic. The Tiny5 pixel font (OFL, Google Fonts) was chosen for its 5x5 superellipse pixel look.

## What Changes

- Add the Tiny5 Regular font asset (`assets/fonts/Tiny5/`, TTF + OFL license, already added) with pixel-crisp import settings: antialiasing off, hinting off, subpixel positioning disabled
- Sidebar build-cameo labels (`scripts/ui/Sidebar.gd`) restyled: Tiny5, 16px, white, outline tracking 75% of font size, left-aligned (name label bottom-anchored, words packed toward the last line so the cameo art stays visible), uppercase rendering; autowrap stays; cost label kept with the same styling
- Selected-producer power readout on the overlay (`scripts/ui/SelectionOverlay.gd`) switches to Tiny5 at 16px with the same 75%-ratio outline; green color kept; font size scales dynamically with camera zoom (same 1/camera-size relationship the health bar gets)
- Uppercase is a render-time transform (`.to_upper()`); `EntityData.display_name` resources are NOT edited

## Capabilities

### New Capabilities

- `ui-typography`: Font styling rules for in-game UI text — the Tiny5 font asset and its import requirements, plus where/how text surfaces apply it (sidebar cameo labels, selection overlay power readout): sizes, colors, dynamic outline ratio, alignment, uppercase rendering

### Modified Capabilities

(none — `cameo-tooltip` and `sidebar-build-order` requirements are unchanged; tooltip still carries name/cost/time/power)

## Impact

- **Scripts**: `scripts/ui/Sidebar.gd` (cameo label construction, word packing), `scripts/ui/SelectionOverlay.gd` (`_draw_power_label` restyle)
- **Assets**: `assets/fonts/Tiny5/Tiny5-Regular.ttf`, `OFL.txt`, generated `.import` (new)
- **No scene file changes**: cameo labels and overlay draws are built in code; no `.tscn` edits, so backward compatibility with packed scenes is unaffected
- **No data changes**: `EntityData.display_name` resources untouched
