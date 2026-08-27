## Context

A player can currently command units anywhere on the infinite ground plane: `MouseHandler` raycasts terrain, then funnels the position through `OrderSystem.get_cursor`/`get_orders` → `UnitOrderGenerator` → `SelectionManager.request_move` → `MovementController.set_target_position`, with no bounds validation. Meanwhile `BoundsSystem` already provides and tests the visible (inset) playable diamond: `is_in_play_area(cell)` for cell membership and `clamp_to_visible_diamond(pos)` for world-space clamping. `OrderSystem` already has a fog gate (`_fog_filter_target`) that nulls out non-visible entity targets — a proven pattern for a target-filtering pass in the same funnel.

`set_target_position` is called by many direct paths (harvester auto-cycle via `HarvestComponent._assess_next_action`, dock/exit navigation, combat pursuit, scatter). Only the `OrderSystem`→`SelectionManager.request_move` path is user-driven. Filtering in `OrderSystem` therefore restricts human input without touching AI/auto paths.

## Goals / Non-Goals

**Goals:**
- Restrict human pre-selected+clicked orders to the visible (inset) bounds.
- Clamp ground orders to the edge (OpenRA-style); reject entity-targeted orders that are out of bounds.
- Apply to rally points for consistency.
- Keep AI, harvester auto-cycle, dock/exit, and future map-trigger movement unrestricted.

**Non-Goals:**
- Physical containment (no hard clamp in `MovementController`, no barrier colliders).
- Restricting AI or scripted movement to the bounds.
- Free-unit pathing that does not involve explicit player target selection.

## Decisions

**D1. Gate in `OrderSystem`, not in `MovementController`.**
A filter at the funnel entry is a single choke point covering move, attack, harvest, dock, force-move, and rally. Movement internals are shared by AI and auto-loops, so gating there would break `#171`'s "AI may operate out of bounds" requirement and future triggers. → Trace shows every non-player call passes `set_target_position` directly; `OrderSystem` sees only human input.

**D2. Clamp ground orders, reject entity-targeted orders.**
- Ground (`target == null`): clamp `target_pos` via `BoundsSystem.clamp_to_visible_diamond`. Keeps cursor MOVE, matches OpenRA edge-snapping.
- Entity (`target != null`): if its cell is not in the visible play area, return a blocked cursor / empty orders. Do NOT fall through to move (attack→move would silently move units to a boundary instead of rejecting).
- This satisfies "reject anything outside for entity-targeted" while giving smooth boundary movement for ground.
- **Two-cell inset margin:** the order boundary is inset `ORDER_EDGE_INSET = 2.0` cells inside the visible outline. Both the rejection check (`is_in_play_area_with_margin(cell, 2.0)`) and the ground clamp (`clamp_to_visible_diamond(pos, 2.0)`) use the inset, so a target just past the blue line is clamped to a valid slot two cells inside, never onto the boundary itself.

**D3. Implement both behaviors with minimal `OrderSystem` mutation.**
Create `_target_out_of_bounds(target, target_cell) -> bool` (cell test, reusing `_fog_filter_target`'s footprint/cell fallback logic) and clamp `target_pos` in `get_cursor`/`get_orders` before delegating to the generator. Reference `BoundsSystem` guards for the no-terrain/test case.

**D4. Keep fog-filter ordering: bounds gate first, then fog.**
Clear semantics: an enemy sitting out of bounds is a hard block (bounds gate), whereas a shrouded *in-*-bounds enemy falls back to move (fog). Existing fog tests/doc unchanged.

**Alternative considered:** clamping in `MouseHandler` — too low-level, misses OrderSystem-level ranges (repair/sell) and would need duplicated bounds logic. **Alternative considered:** rejecting everything — breaks OpenRA boundary UX requested by the user.

## Risks / Trade-offs

- [Out-of-bounds entity falls through to a plain move in some code path] → Explicit reject: never remap to move for entity targets; only ground clamps.
- [Clamp of ground order could make boundary feel sticky] → Acceptable, matches OpenRA; it only matters near edges.
- [Map editor / no-terrain test context lacks `BoundsSystem`] → Guard with `BoundsSystem` null-check (mirror fog pattern), tests run with autoloads injected.
- [Entity *at* the boundary diamond but cell considered outside] → Use `is_in_play_area` (same definition as the visual blue bounds) so feedback and gates agree.

## Migration Plan

No data/schema changes. Deploy via same PR as the fix; revert = remove the gate in `OrderSystem`.

## Open Questions

None blocking. Rally-point clamp behavior (D1/D2) treated as "clamp for consistency."