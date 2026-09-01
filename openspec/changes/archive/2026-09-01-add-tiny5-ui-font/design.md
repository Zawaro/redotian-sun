# Design: add-tiny5-ui-font

## Context

Two text surfaces get the Tiny5 font, both built entirely in code (no `.tscn` edits):

1. **Sidebar cameos** — `Sidebar._create_cameo()` (`scripts/ui/Sidebar.gd:233-370`) builds each cameo as a `Button` with two programmatic `Label` children (name, cost) styled with theme overrides. Labels currently use the engine default font, centered alignment, sizes 12/11; name label autowraps (`AUTOWRAP_WORD_SMART`); a tooltip already carries name/cost/time/power (`Sidebar.gd:403-406`).
2. **Selection overlay** — `SelectionOverlay` (`scripts/ui/SelectionOverlay.gd`) is a `CanvasLayer` drawing via CanvasItem primitives with zero per-selection node allocations. `_collect_entities()` (line 202) builds a per-frame `_entities` dict; `_do_draw()` renders brackets/health bars/pips; `_draw_power_label()` (line 120) is the only text draw today, using `ThemeDB.fallback_font`.

Font asset `assets/fonts/Tiny5/Tiny5-Regular.ttf` + `OFL.txt` are already added (untracked). Existing font precedent: `assets/fonts/Poppins/` (TTF + OFL.txt). `EntityData.display_name` values are title case ("Alkaline's Battery Superstore"); TS style wants uppercase.

## Goals / Non-Goals

**Goals:**
- Pixel-crisp Tiny5 on cameo labels and the overlay power readout
- Consistent text style: white, outline tracking 50% of font size, left-aligned on cameos, uppercase
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

### D4: Overlay power label is the only selection text
The overlay's only Tiny5 text is the selected-producer power readout. Entity name labels were removed from scope after review — that display already exists behind the debug menu's entity-id toggle (`DebugVisualizer._draw_entity_ids`). The power readout gets no per-entity state beyond the existing dict (`_power_label_for`).

### D5: Outline ratio, not fixed pixels
Outline weight = `50%` of the live font size (`TINY5_OUTLINE_RATIO := 0.5`), matching the tuned outline on 14px text. Both surfaces derive outline from size, so resizing never desyncs. Cameo labels keep the user's 80%-alpha black outline color.

### D6: Font size 16 (user-tuned), smoke-test knob
Cameo text is 14px. The name label anchors bottom-left with `VERTICAL_ALIGNMENT_BOTTOM`; `_pack_words_to_end()` pre-packs the uppercase name so the LAST line takes as many words as fit the cameo inner width (121px) — "NOD POWER PLANT" (136px at 16px; 119px at 14px) — at 14px it fits one line, longer names wrap to the fullest last line, keeping the top cameo art clear. Autowrap stays on purely as a safety net for single words wider than the cameo. Measured Tiny5 widths at 14px: "TIBERIUM SILO" 92px, "E.M.P. CANNON" 95px — single-line names stay whole.

### D7: Zoom-following power label via camera size
The camera zooms by shrinking ortho `size` (Camera01: 10–50, default 20 — no `zoom` property), so the power label scale = `REFERENCE_CAMERA_SIZE (20) / camera.size`, floored at 0.5. That is the same 1/size relationship the projected health bar inherits for free. 16px at default zoom; 32px fully zoomed in; outline tracks at 50%.

## Risks / Trade-offs

- [16px Tiny5 may crowd the cameo or read small when zoomed out] → Smoke test decides; sizes are named constants and the outline self-adjusts
- [Outline at 50% of size is heavy on small text] → That weight is the tuned TS look; drop `TINY5_OUTLINE_RATIO` if it smears
- [`.import` param names differ across Redot versions] → Verify keys against a freshly generated file before editing; keep the editor's auto-generated block otherwise
- [Long uppercase names wrap to 3+ lines in small cameos] → Autowrap is word-smart and the label zone spans the full cameo; acceptable, ellipsis not implemented

## Migration Plan

Additive change; no data or scene migration. Rollback = revert the commit (font files stay, harmless). Commit order: font asset + `.import` first, then script changes, so any intermediate state imports cleanly.

## Open Questions

- None blocking — font size and outline weight are smoke-test knobs with named constants.
