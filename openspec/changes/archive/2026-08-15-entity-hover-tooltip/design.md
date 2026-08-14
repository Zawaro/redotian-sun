## Context

GH #272: no hover identification for world entities. The hover pipeline is already complete and recently hardened by the follow-attack work:

`MouseHandler._handle_hover_preview` (scripts/hud/MouseHandler.gd:404) raycasts layer 15 → `SelectComponent`, gates on fog visibility (`_is_fog_visible`) with a 3-frame miss debounce, then calls `SelectionManager.set_hover_preview` (scripts/core/SelectionManager.gd:166). SelectionManager tracks `hovered_entity` and emits `hover_changed(entity: SelectComponent | null)` — fired on hover change and on clear (SelectionManager.gd:181-185). `SelectionOverlay` already consumes this signal as a pattern.

Per hovered `SelectComponent`, `get_parent()` is the entity Node3D carrying a `StatsComponent` with `display_name`, `entity_type`, `player_id` (scripts/components/StatsComponent.gd:5-23). Player relations come from `PlayerManager.is_enemy` (team comparison, scripts/core/PlayerManager.gd:21) and `get_local_player_id`. Airborne detection exists via `MovementController.is_airborne_jumpjet` (scripts/components/MovementController.gd:336).

Key wrinkle: MouseHandler skips the hover raycast when the cursor is over the sidebar/debug UI (scripts/hud/MouseHandler.gd:129), so the last hovered entity stays "stale-hovered" — the tooltip must self-guard.

## Goals / Non-Goals

**Goals:**
- Tooltip over selectable world entities, styled black-panel/green-outline/uppercase mono, following the cursor.
- Label resolution per player relation: friendly/neutral → real name; enemy → type-only label; airborne enemy aircraft → `ENEMY AIRCRAFT`.
- Zero new per-frame raycasts — pure consumer of existing hover state.
- Hide on hover clear and over sidebar/debug UI.
- Label resolution and show/hide directly unit-testable.

**Non-Goals:**
- No map-editor tooltip (the map editor gets its own system later).
- No `UNREVEALED TERRAIN` shroud label yet (raycast already excludes fog-hidden entities; wire when #197/#198 shroud grid data lands).
- No changes to MouseHandler, SelectionManager, SelectionOverlay, or any entity component.
- No bundled monospace font asset (SystemFont fallback chain instead).

## Decisions

**D1 — Tooltip is a pure consumer of `SelectionManager.hover_changed`.**
Connect to the existing signal (same pattern as `SelectionOverlay._connect_to_selection_manager`, scripts/ui/SelectionOverlay.gd:55). `hover_changed(entity)` → show + resolve label; `hover_changed(null)` → hide. Cursor-following is per-frame in `_process` via `get_viewport().get_mouse_position()`, not signal-driven (the signal only fires on change).
- Rationale: reuses the exact state the follow-attack work hardened, including fog gating. No raycast duplication.
- Alternative: a separate per-frame raycast in the tooltip — rejected, the issue explicitly forbids it.

**D2 — Label resolution is a static pure function on the tooltip script.**
`static func resolve_label(entity: Node3D) -> String` reads `StatsComponent` + `PlayerManager` and returns the label:
friendly (`player_id == local`) → `display_name`; ownerless (`player_id == -1`) → `display_name`; enemy (`PlayerManager.is_enemy`) → `ENEMY <TYPE>` mapping; else (same team, other player) → `display_name`. `ENEMY` mapping: `INFANTRY→ENEMY INFANTRY`, `VEHICLE→ENEMY UNIT`, `BUILDING→ENEMY STRUCTURE`, `AIRCRAFT` airborne (`MovementController.is_airborne_jumpjet`) → `ENEMY AIRCRAFT`, grounded `AIRCRAFT` → `ENEMY UNIT`. The tooltip uppercases the result (`to_upper()`).
- Rationale: direct unit testing without a viewport, mirroring the `MouseHandler.new()` pattern in test/unit/test_mouse_handler_hover.gd:71. Test runner injects `_pm`; `PlayerManager._init_defaults` seeds local=0 (team 1) and enemy=1 (team 2), so friendly/enemy/neutral are reachable; neutral = `get_player_data(2)` with `team_id = 1`.

**D3 — Placement: a Control instance under the gameplay HUD in `MapBase01.tscn`.**
New `scenes/ui/HoverTooltip.tscn` (PanelContainer + Label) instanced under `MapBase01`'s `HUD` CanvasLayer (scenes/maps/MapBase01.tscn), alongside Sidebar/DebugMenu/PauseMenu, `mouse_filter = MOUSE_FILTER_IGNORE` so it never intercepts clicks. `MainScene.tscn` is only the menu shell (placeholder MainMenu01 + LoadingScreen); gameplay runs TestMap01/TestMap02, which both instance `MapBase01` — so the tooltip lives where hover actually happens. Matches the repo convention that scene files mirror script names.
- Rationale: discovered in implementation that instancing under MainScene's HUD placed the tooltip in a scene that never enters gameplay — hover fired but the tooltip wasn't in the tree. All map scenes derive from MapBase01, so it covers every current map.
- Alternative: a 23rd autoload built in code like SelectionOverlay — bulletproof against future gameplay scenes that skip MapBase01, but overkill for one Control today.
- Alternative: code-built child added in `_ready` with no scene edit — leaner but breaks the scene-mirrors-script convention.

**D4 — Styling: `StyleBoxFlat` black bg + green 1px border; `SystemFont` mono fallback chain.**
The repo bundles no monospace font (only `assets/fonts/Poppins/SemiBold.ttf`). A `SystemFont` node with `font_names` requesting a monospace face resolves natively at runtime and falls back to the default font if none is available — zero new asset work. Bundling a TS-style mono TTF is a follow-up asset task.
- Rationale: native engine feature over a new bundled dependency (ladder rung 4).

**D5 — Sidebar/debug self-guard in `_process`.**
Hide when `UIUtil.is_mouse_over_sidebar()` or the cursor is over the DebugMenu. This mirrors the gameplay-gating logic in MouseHandler (scripts/hud/MouseHandler.gd:123-129) and fixes the stale-hover case the raycast skip leaves behind. Also cancels a pending (pre-delay) tooltip.
- Rationale: without it the tooltip would float over the sidebar on a stale hover.

**D6 — Grounded enemy aircraft → `ENEMY UNIT`.**
The issue specifies `ENEMY AIRCRAFT` only "when airborne"; grounded (helipad) aircraft fall through to the generic unit label.
- Rationale: follows the issue literally; grounded aircraft are an edge case today.

**D7 — 0.5-second hover delay, immediate hide, no flicker between targets.**
A one-shot `Timer` (0.5s) gates appearance: `_on_hover_changed` resolves the label; while hidden it starts the timer and shows on timeout. Moving the cursor resets the timer (`_process` tracks the viewport mouse position via `_restart_delay_if_cursor_moved`) — a pending tooltip restarts its countdown, and a visible tooltip hides and only reappears once the refilled delay lapses. So the tooltip appears only when the cursor rests on a target. Once the tooltip is visible and the cursor moves onto a *different* target without moving the cursor, a target change swaps the label immediately (`_set_text` + `_move_to_cursor`) instead of hiding and re-delaying. Hover clear (empty revealed ground) or sidebar/debug UI hides it and cancels a pending reveal. The unit tests pump the timeout directly (`_on_delay_timeout()`) and simulate cursor movement by rewriting `_last_mouse_pos` before calling `_process`, instead of waiting on real time.
- Rationale: the original hide-on-change caused a 1s blink whenever the cursor crossed onto a new target. Keeping the tooltip alive once shown matches TS and removes the flicker while preserving the "appear after 1s" request for the initial reveal.

**D8 — Generic hover target + label override in SelectionManager.**
`hover_changed` now emits `Node3D` (the hovered entity) instead of `SelectComponent`, and SelectionManager tracks `hovered_node` (any entity, selectable or not) plus `hover_label_override` for entity-less states. New API: `set_hover_node(node)` (resources/dock hosts, from the interact-hitbox hover path) and `set_hover_shroud()` (unrevealed ground). `SelectionOverlay._on_hover_changed` ignores the argument, so its signature is updated to `Node3D` and its selectable-hover behavior is unchanged.
- Rationale: tiberium trees/fields have no `SelectComponent` (they use interaction hitboxes) and shrouded cells have no entity at all — the tooltip needs a target abstraction that isn't selection-shaped. The tooltip reads `hovered_node`/`hover_label_override`, not the signal argument, so label resolution stays a pure function of manager state.

**D9 — Shroud detection in the hover miss path.**
`MouseHandler._handle_hover_preview`'s miss path (3-frame debounce) checks `ShroudSystem.is_shroud_enabled()` and the ground cell under the cursor via `_get_ground_position_at_mouse()` + `ShroudSystem.is_cell_visible_to_local()`; unrevealed → `set_hover_shroud()` instead of clearing. Revealed empty ground still clears hover (no tooltip).
- Rationale: the shroud grid data (#197/#198) is already in `ShroudSystem`; the tooltip just consumes it. Resource/tree hovers already route through the pass-2 interact hitbox, which now calls `set_hover_node(entity)` instead of `clear_hover_preview()`.

## Risks / Trade-offs

- [SystemFont fails to resolve a monospace face on some platforms] → falls back to the default font; uppercase + panel styling still renders the tooltip. Bundling a mono font is the follow-up if it looks wrong.
- [`player_id == -1` entities with a SelectComponent] → guarded to show `display_name` before the enemy check, so ownerless decorative entities never render as `ENEMY`.
- [Stale hover over sidebar] → mitigated by D5's self-guard; the tooltip never shows over UI even if hover state lingers.
- [Enemy label leaks real names if `display_name` is empty] → resolve_label returns an empty string on empty display name and the tooltip hides, so nothing partial is rendered.

## Migration Plan

Additive only: one scene instance in `MapBase01.tscn`, new script/scene/test, and small additions to `SelectionManager`, `MouseHandler`, `SelectionOverlay`. No rollback risk — removing the scene instance fully disables the feature.

## Open Questions

None blocking. Bundling a dedicated monospace font is a tracked follow-up. Shroud-cell labels are now wired via `ShroudSystem` grid state (previously deferred).
