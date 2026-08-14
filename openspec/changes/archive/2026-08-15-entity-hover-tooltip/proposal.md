## Why

Players get no way to identify a hovered world entity (GH #272). Tiberian Sun shows a tooltip box on hover: real display name for friendly/neutral entities, type-only labels (`ENEMY UNIT` / `ENEMY INFANTRY` / `ENEMY STRUCTURE`) for enemies so no info leaks. The hover raycast, state funnel, and fog gate already exist — the tooltip is a pure consumer.

## What Changes

- New `HoverTooltip` Control in the gameplay HUD (`MapBase01.tscn`'s `HUD` CanvasLayer): black panel, green outline, uppercase monospace text, positioned at the cursor while hovering.
- Reuses the existing `SelectionManager` hover signal and adds a generic hover target (`hovered_node`) covering units, structures, resources (tiberium trees/fields), and shrouded cells — **zero new per-frame raycasts**.
- Tooltip appears after 1 second of continuous hover and hides immediately on hover clear or sidebar/debug UI.
- Label resolution: friendly/neutral/ownerless → real `display_name`; enemy → `ENEMY <TYPE>` (airborne aircraft → `ENEMY AIRCRAFT`).
- Tooltip hides when hover clears and when the cursor is over sidebar/debug UI.
- No existing scripts or components are modified; `MapBase01.tscn` gains one scene instance (the map scene all maps derive from — gameplay runs TestMap01/TestMap02, not the MainScene menu shell).

## Capabilities

### New Capabilities
- `entity-hover-tooltip`: Hover tooltip over world entities — show/hide driven by the existing selection-manager hover signal, label selection by player relation (friendly/enemy/neutral), enemy type labeling, uppercase black-panel styling, and cursor-follow with UI-overlay suppression.

### Modified Capabilities
<!-- None — existing specs (selection-manager, player-manager, shroud) are unchanged; this is additive. -->

## Impact

- `scripts/ui/HoverTooltip.gd` (new) — tooltip Control script; static, directly testable label resolver.
- `scenes/ui/HoverTooltip.tscn` (new) — PanelContainer + Label with black/green StyleBoxFlat and monospace font theme.
- `scenes/maps/MapBase01.tscn` — one instance under its `HUD` CanvasLayer.
- `test/unit/test_hover_tooltip.gd` (new) — label selection and show/hide tests.
- Backward compatible: no changes to packed entity scenes or components. `SelectionManager` gains a generic hover node + label override and `MouseHandler` routes resource/shroud hover through them; `SelectionOverlay`'s selectable-hover behavior is unchanged (signature-only update). Shrouded cells show `UNREVEALED TERRAIN` via the existing `ShroudSystem` grid. Map editor gets no tooltip (separate system later).
