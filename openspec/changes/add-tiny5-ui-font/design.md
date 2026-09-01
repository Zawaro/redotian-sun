# Design: add-tiny5-ui-font

## Context

Two text surfaces get the Tiny5 font, both built entirely in code (no `.tscn` edits):

1. **Sidebar cameos** — `Sidebar._create_cameo()` (`scripts/ui/Sidebar.gd:233-370`) builds each cameo as a `Button` with two programmatic `Label` children (name, cost) styled with theme overrides. Labels currently use the engine default font, centered alignment, sizes 12/11; name label autowraps (`AUTOWRAP_WORD_SMART`); a tooltip already carries name/cost/time/power (`Sidebar.gd:403-406`).
2. **Selection overlay** — `SelectionOverlay` (`scripts/ui/SelectionOverlay.gd`) is a `CanvasLayer` drawing via CanvasItem primitives with zero per-selection node allocations. `_collect_entities()` (line 202) builds a per-frame `_entities` dict; `_do_draw()` renders brackets/health bars/pips; `_draw_power_label()` (line 120) is the only text draw today, using `ThemeDB.fallback_font`.

Font asset `assets/fonts/Tiny5/Tiny5-Regular.ttf` + `OFL.txt` are already added (untracked). Existing font precedent: `assets/fonts/Poppins/` (TTF + OFL.txt). `EntityData.display_name` values are title case ("Alkaline's Battery Superstore"); TS style wants uppercase.

## Goals / Non-Goals

**Goals:**
- Pixel-crisp Tiny5 on cameo labels, new overlay name labels, and the power readout
- Consistent text style: white, 1px black outline, left-aligned on cameos, uppercase
- Keep the zero-allocation overlay draw pattern intact

**Non-Goals:**
- No main-menu, tab-button, credit-counter, tooltip, or debug-visualizer restyling (they keep current fonts)
- No editing of `EntityData.display_name` resources — uppercase is a render transform
- No removal of the cost label (kept; tooltip unchanged per `cameo-tooltip` spec)
- No project-wide theme/font default change

## Decisions

### D1: Import settings on the `.import` file, not editor round-trip
Edit `Tiny5-Regular.ttf.import` params directly: `antialiasing=0`, `hinting=0`, `subpixel_positioning=0` (disabled). Redot re-imports on next editor focus. Alternative (import-dock clicks) is manual and untestable from a clean checkout; committing the `.import` file makes the settings reproducible for all developers.

### D2: Uppercase as render-time transform
Cameo labels: set the text via `data.display_name.to_upper()` — avoids the Label `uppercase` theme property's differing behavior across Redot versions and keeps alignment math honest. Overlay: `display_name.to_upper()` before `draw_string`. Alternative (uppercase in `.tres` files) churns ~100 data resources and changes tooltip text too — rejected.

### D3: One `preload` per file, no shared font helper
`const TINY5_FONT := preload("res://assets/fonts/Tiny5/Tiny5-Regular.ttf")` in both `Sidebar.gd` and `SelectionOverlay.gd`. Two call sites do not justify a `UIFonts` autoload/const registry; revisit only when a third surface adopts Tiny5.

### D4: Overlay name label follows the power-label draw pattern
`_collect_entities()` adds `"display_name"` to the entity dict (via `parent.get_node_or_null("StatsComponent")` — the same lookup pattern as `DebugVisualizer.gd:397-401` and the overlay's own `_power_label_for`). A new `_draw_name_label()` draws `draw_string_outline()` then `draw_string()` centered below `bracket_rect` (the strip under the bracket is free — health bars sit above it). Hovered entities already flow through `_collect_entities` (`is_selected or is_hovering`, line 213), so hover labels come free. Alternatives rejected: per-entity `Label` nodes (breaks zero-allocation pattern), drawing inside the bracket (collides with power label / health bar).

### D5: Outline via two APIs, both "1px"
- Labels: `add_theme_color_override("font_outline_color", Color.BLACK)` + `add_theme_constant_override("outline_size", 1)`
- Overlay: `draw_string_outline(..., 1, BLACK)` under `draw_string(..., WHITE)`
Spec pins 1px in both places so a later "fix" to one surface doesn't drift.

### D6: Font size 10 (smoke-test knob)
Tiny5's design grid is 5px; 10px is a clean 2x integer scale and stays crisp with AA off. Cameo name and cost both 10px. Power readout keeps its 14px size (softness acceptable; visible text is small). Named constants (`TINY5_CAMEO_SIZE := 10`) so the smoke test can retune in one place per file.

## Risks / Trade-offs

- [10px Tiny5 may read small on high-DPI displays] → Smoke test decides; bump the named constant (10→15 stays on-grid)
- [Power label at 14px is off-grid, renders slightly soft] → Accepted for now; 15px is the on-grid fallback if the smoke test objects
- [Outline rendering with AA off can look chunky at small sizes] → That chunk is the TS look; if it smears, drop `outline_size` to 0 on labels only
- [`.import` param names differ across Redot versions] → Verify keys against a freshly generated file before editing; keep the editor's auto-generated block otherwise
- [Long uppercase names wrap to 3+ lines in small cameos] → Autowrap is word-smart and the label zone spans the full cameo; acceptable, ellipsis not implemented

## Migration Plan

Additive change; no data or scene migration. Rollback = revert the commit (font files stay, harmless). Commit order: font asset + `.import` first, then script changes, so any intermediate state imports cleanly.

## Open Questions

- None blocking — font size and outline weight are smoke-test knobs with named constants.
