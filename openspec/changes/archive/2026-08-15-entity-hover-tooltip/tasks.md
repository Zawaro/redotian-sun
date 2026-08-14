## 1. Label resolver

- [x] 1.1 Create `scripts/ui/HoverTooltip.gd` with `static func resolve_label(entity: Node3D) -> String` (D2): friendly (`player_id == local`) → `display_name`; ownerless (`player_id == -1`) → `display_name`; enemy (`PlayerManager.is_enemy`) → `ENEMY <TYPE>`; else (same team, other player) → `display_name`; empty `display_name` → `""`
- [x] 1.2 Map `EntityData.EntityType` → enemy label: `INFANTRY→ENEMY INFANTRY`, `VEHICLE→ENEMY UNIT`, `BUILDING→ENEMY STRUCTURE`, airborne `AIRCRAFT` (`MovementController.is_airborne_jumpjet`) → `ENEMY AIRCRAFT`, grounded `AIRCRAFT` → `ENEMY UNIT`

## 2. Tooltip Control

- [x] 2.1 Create `scenes/ui/HoverTooltip.tscn`: Panel with `StyleBoxFlat` black background + green 1px border (D4) and a child Label
- [x] 2.2 Style the Label: `SystemFont` monospace fallback chain, green font color, `text.to_upper()` applied on set
- [x] 2.3 Implement `_process`: hide when cursor over sidebar/debug UI (D5 via `UIUtil.is_mouse_over_sidebar` + DebugMenu check); when visible, follow the cursor (`get_viewport().get_mouse_position()` with small offset); keep `mouse_filter = MOUSE_FILTER_IGNORE`
- [x] 2.4 Connect to `SelectionManager.hover_changed` (retry-once deferred pattern like `SelectionOverlay._connect_to_selection_manager`, scripts/ui/SelectionOverlay.gd:55): on entity → resolve label and show; on `null` → hide
- [x] 2.5 Instance `HoverTooltip.tscn` under `HUD/UI` in `scenes/MainScene.tscn` (D3)
- [x] 2.6 Relocate the instance to the gameplay HUD: `scenes/maps/MapBase01.tscn`'s `HUD` CanvasLayer (all maps derive from MapBase01); remove the dead instance from `MainScene.tscn` (menu shell only, never in gameplay)
- [x] 2.7 Add the 0.5-second hover delay (D7): one-shot `Timer`, show only on timeout; reset the delay when the cursor moves (pending restarts, visible tooltip hides until the delay refills); a visible tooltip swaps to a new target immediately (no hide/re-show flicker); cancel on hover clear/sidebar
- [x] 2.8 Generalize the hover target (D8): `hover_changed` emits `Node3D`; add `hovered_node`, `hover_label_override`, `set_hover_node()`, `set_hover_shroud()` to SelectionManager; update `SelectionOverlay._on_hover_changed` signature
- [x] 2.9 MouseHandler: pass-2 interact hitboxes (tiberium, trees, dock) call `set_hover_node()` instead of `clear_hover_preview()`; miss path checks `ShroudSystem.is_cell_visible_to_local()` and calls `set_hover_shroud()` for unrevealed ground (D9)

## 3. Tests

- [x] 3.1 `test/unit/test_hover_tooltip.gd`: friendly → real `display_name`; ownerless (`player_id = -1`) → real name; neutral (new player data with same `team_id`) → real name
- [x] 3.2 Enemy labels: infantry → `ENEMY INFANTRY`, vehicle → `ENEMY UNIT`, structure → `ENEMY STRUCTURE`; airborne aircraft (MovementController reporting airborne) → `ENEMY AIRCRAFT`, grounded aircraft → `ENEMY UNIT`
- [x] 3.3 Uppercase: label with lowercase `display_name` resolves to the uppercase-rendered text
- [x] 3.4 Show/hide via SelectionManager hover state: `set_hover_preview(true, sc)` + delay timeout → visible; clear → hidden
- [x] 3.5 Rejection guard: empty `display_name` → empty label (tooltip hides, nothing partial rendered)
- [x] 3.6 Run `redot --headless -s test/run_tests.gd` until green; run `gdlint` + `gdformat --check` on changed files; no tabs introduced
- [x] 3.7 Regression: load `MapBase01.tscn` and assert a `HoverTooltip` node exists under its `HUD` (guards the scene-placement bug)
- [x] 3.8 Delay: tooltip hidden during the delay and visible after `_on_delay_timeout()`; hover clear before the delay cancels it; cursor movement resets the pending delay and hides a visible tooltip until the delay refills; visible tooltip swaps to a new target immediately without hiding
- [x] 3.9 Resource hover: `set_hover_node(resource_entity)` → tooltip shows the resource's `display_name`; MouseHandler resource takeover asserts `hovered_node` is the resource
- [x] 3.10 Shroud: `set_hover_shroud()` → tooltip shows `UNREVEALED TERRAIN`; MouseHandler `_is_hovering_shrouded()` flips with `rules.shroud_enabled`

## 4. Documentation

- [ ] 4.1 Archive the openspec change after merge (CI requires no open changes)
