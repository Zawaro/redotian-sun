# Tasks: add-tiny5-ui-font

## 1. Font asset import

- [x] 1.1 Tune `assets/fonts/Tiny5/Tiny5-Regular.ttf.import`: `antialiasing=0`, `hinting=0`, `subpixel_positioning=0` — verify param names against the auto-generated file first (design D1)
- [x] 1.2 Confirm import loads: font resource usable in a headless run; `OFL.txt` present alongside

## 2. Sidebar cameo labels

- [x] 2.1 Add `TINY5_FONT` preload const and `TINY5_CAMEO_SIZE := 10` to `scripts/ui/Sidebar.gd`
- [x] 2.2 Restyle name label in `_create_cameo()` (line ~255): Tiny5 font override, size 10, white, `outline_size 1` + black `font_outline_color`, `HORIZONTAL_ALIGNMENT_LEFT`, anchors widened to full cameo, text via `data.display_name.to_upper()`, autowrap kept
- [x] 2.3 Restyle cost label (line ~276): same font/outline/alignment/uppercase treatment, size 10, stays in top zone
- [ ] 2.4 Smoke test in editor: cameo text crisp at 100% zoom, left-aligned, wraps long names, cost visible

## 3. Selection overlay labels

- [x] 3.1 Add `TINY5_FONT` preload const and name-label size constant to `scripts/ui/SelectionOverlay.gd`
- [x] 3.2 Add `"display_name"` to the `_entities` dict in `_collect_entities()` via `StatsComponent.get("display_name")`, empty-string safe
- [x] 3.3 Implement `_draw_name_label()`: `draw_string_outline()` + `draw_string()` in Tiny5, white on 1px black outline, uppercase, centered below `bracket_rect`; skip empty names
- [x] 3.4 Restyle `_draw_power_label()`: swap `ThemeDB.fallback_font` for Tiny5, add 1px black outline pass, keep green + size 14
- [ ] 3.5 Smoke test in editor: select unit/building → name below bracket; hover alone → name shows; producer → power label still correct

## 4. Tests and lint

- [ ] 4.1 Extend `test/unit/test_selection_overlay.gd`: collected entity dict carries `display_name` from `StatsComponent` (positive, empty-name, and missing-StatsComponent cases)
- [ ] 4.2 Run `redot --headless -s test/run_tests.gd` — full suite green
- [ ] 4.3 Run `gdlint` + `gdformat --check` on touched scripts; check for tabs after formatting
- [ ] 4.4 Commit font asset (`.ttf`, `OFL.txt`, `.import`) separately from script changes (design migration order)
