## Why

Players can right-click, attack, harvest, or dock to any point on an unbounded ground plane, sending units outside the visible (blue) bounds that define the playable area. This breaks map integrity: units march through the void region around the playable diamond. The visible bounds should restrict all human player-issued activity, while AI and automatic entity loops must keep full freedom (and future map triggers must allow entity movement outside bounds for scripted behavior).

## What Changes

- **Gate human-input and entity-targeted orders** in the `OrderSystem` autoload — the single funnel that only human input enters — by rejecting or clamping order targets that fall outside the visible bounds.
- **Clamp** pure ground orders (move / force-move / attack-ground / rally point) to the nearest in-bounds point, OpenRA-style, so the cursor stays MOVE and the unit races to the boundary.
- **Reject** entity-targeted orders (attack / force-fire / harvest / dock / enter) whose target sits outside the visible bounds: no order is produced and a blocked cursor is shown.
- **Leave AI and automatic behavior untouched**: units commanded programmatically (AI control, harvester auto-cycle, dock/exit/combat pursuit, and future map triggers that call movement directly) SHALL continue to operate outside bounds.
- Restriction applies to the visible (inset) diamond, not the raw map diamond.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `order-system`: add a mandatory bounds gate on player-issued order resolution/cursor feedback so human orders cannot originate at or target outside the visible play bounds, without affecting AI or automatic movement.

## Impact

- `scripts/core/OrderSystem.gd` — add a bounds filter mirrored on the existing `_fog_filter_target`, applied in `get_cursor`/`get_orders`.
- `BoundsSystem` — reuse existing, already-tested `is_in_play_area(cell)` (cell test) and `clamp_to_visible_diamond(pos)` (world clamp).
- No change to `MovementController.set_target_position` or `HarvestComponent` — AI/auto/trigger paths call these directly and bypass `OrderSystem`.
- New order/cursor behavior tests under `test/unit/`.
- Future-proof: map-trigger-driven movement will call `set_target_position`/`request_move` directly, never `OrderSystem`.