# Tasks: add-tiny5-ui-font

## 1. Font asset import

- [x] 1.1 Tune `assets/fonts/Tiny5/Tiny5-Regular.ttf.import`: `antialiasing=0`, `hinting=0`, `subpixel_positioning=0` — verify param names against the auto-generated file first (design D1)
- [x] 1.2 Confirm import loads: font resource usable in a headless run; `OFL.txt` present alongside

## 2. Sidebar cameo labels

- [x] 2.1 Add `TINY5_FONT` preload const and `TINY5_CAMEO_SIZE` to `scripts/ui/Sidebar.gd`
- [x] 2.2 Restyle name label in `_create_cameo()`: Tiny5 font override, white, dynamic outline, `HORIZONTAL_ALIGNMENT_LEFT`, uppercase via `to_upper()`, autowrap kept
- [x] 2.3 Restyle cost label: same font/outline/alignment/uppercase treatment, stays in top zone
- [ ] 2.4 Smoke test in editor: cameo text crisp at 100% zoom, left-aligned, wraps long names, cost visible

## 3. Selection overlay power readout

- [x] 3.1 Add `TINY5_FONT` preload const to `scripts/ui/SelectionOverlay.gd`
- [x] 3.2 Restyle `_draw_power_label()`: swap `ThemeDB.fallback_font` for Tiny5, outline pass, keep green
- [ ] 3.3 Smoke test in editor: selected producer → power label correct

## 4. Tests and lint

- [x] 4.1 Run `redot --headless -s test/run_tests.gd` — full suite green (5878 passed, 0 failed)
- [x] 4.2 Run `gdlint` + `gdformat --check` on touched scripts; check for tabs after formatting
- [x] 4.3 Commit font asset (`.ttf`, `OFL.txt`, `.import`) separately from script changes (design migration order)

## 5. Revision (user feedback)

- [x] 5.1 Remove overlay entity name labels (`_draw_name_label`, `_display_name_for`, dict entry, consts) — debug menu toggle already covers entity names
- [x] 5.2 Remove the 3 name-label tests from `test_selection_overlay.gd`
- [x] 5.3 Make outline dynamic: `TINY5_OUTLINE_RATIO := 0.75` — cameo outline = `int(size * ratio)`; overlay outline = `int(live_font_size * ratio)`
- [x] 5.4 Cameo name label: bottom-left anchor (`VERTICAL_ALIGNMENT_BOTTOM`), font size 16
- [x] 5.5 `_pack_words_to_end()`: pack words toward the last line ("NOD" / "POWER PLANT"); verified with measured Tiny5 widths (136px → wraps, 102px fits)
- [x] 5.6 Power readout: base 16px, zoom-following via `REFERENCE_CAMERA_SIZE / camera.size` (min scale 0.5), outline tracks 75%
- [x] 5.7 Re-run suite + lint after revision
- [ ] 5.8 Smoke test (user): cameo name bottom-left with end-packed wrap, 12px outline on 16px text, power label scales with zoom
