## Context

The build menu sidebar (`BuildMenu.tscn`/`BuildMenu.gd`) had a `PanelContainer` root which expands all children to fill its content area via `NOTIFICATION_SORT_CHILDREN`. This caused the `CreditsLabel` and `MarginContainer` (containing `GridContainer`) to overlap — both filled the same area. Attempted fixes using `VBoxContainer` root also failed because `Container`-derived types override child positioning.

The scene and script names were narrow ("BuildMenu") while the panel serves as a general sidebar (credit display + building grid + future items).

## Goals / Non-Goals

**Goals:**
- Restructure sidebar so credit label and building grid are both visible without overlap
- Rename scene/script to reflect general-purpose sidebar role
- Add cost tooltip to building cameo buttons
- Set default credits to 10000 for testing

**Non-Goals:**
- No changes to building placement logic
- No changes to EconomyManager API
- No changes to the BuildingManager build flow

## Decisions

1. **Control root instead of Container** — `Control` is not a `Container`, so it doesn't call `fit_child_in_rect()` on children. Children with `layout_mode = 0` use explicit anchor/offset positioning, avoiding overlap. Alternative was a custom Container override, but plain Control is simpler and sufficient.

2. **Anchor-based child positioning** — CreditsLabel uses `layout_mode = 0` with `anchor_right = 1.0`, `offset_top = 8`, `offset_bottom = 28` (20px height). PanelContainer uses `layout_mode = 0` with `offset_top = 36` (positioned below label). No container nesting needed.

3. **Tooltip via `tooltip_text`** — Godot's built-in `tooltip_text` property on `Control` nodes shows a popup on hover. No custom tooltip UI needed. The default tooltip theme is acceptable.

4. **File rename via git mv** — Preserves file history. Update `ext_resource` paths and node names in all referencing scenes.

## Risks / Trade-offs

- [Renamed scene/script files] → Any external references (not in repo) will break. Mitigation: in-repo references fully updated.
- [Control root uses manual layout] → Adding more sidebar elements requires manual offset adjustment. Mitigation: straightforward with anchor-based positioning; no container complexity.
