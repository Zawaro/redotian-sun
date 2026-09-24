## Why

Enemy (non-local) entities are selectable for viewing, but two problems follow from the
current order funnel and selection rules. The cursor stays at `DEFAULT` when an enemy is
selected (no context feedback), and enemy-owned order-capable entities accept real player
commands — select an enemy harvester, click tiberium, and it receives a harvest order.
Confirmation against the reconstructed Tiberian Sun source (OpenTS `TibSun`, `object.cpp`
`ObjectClass::Select`, `techno.cpp` `What_Action`/`Can_Player_Move`/`Can_Player_Fire`,
`display.cpp` `Mouse_Left_Release`) shows the reference rules: an enemy may be selected, but
selection is **exclusive by ownership** — selecting an enemy clears the player's selection,
and a non-player-controlled selection can never grow past one entity. The reference never
produces a mixed own+enemy selection, and its `Can_Player_Move`/`Can_Player_Fire` gates keep
orders off non-player-controlled objects.

## What Changes

- Match the reference: **no mixed own+enemy selection**. Adding a non-local entity clears the
  current selection; adding a local entity while a non-local is selected clears the non-local.
  Only local entities may coexist. Enemy selection is therefore always a single entity.
- Unify click routing: clicking an unselected entity that the current selection can order
  (attack/dock/harvest) executes the order; otherwise the entity is selected (clearing by the
  ownership rule). This applies to enemy and friendly targets alike.
- Non-local (enemy) selected entities generate neither orders nor command cursors, regardless
  of which order-capable components they carry (weapon, deploy, harvest, dock, transport). An
  all-enemy selection resolves to `SELECT` over an unselected selectable target and `DEFAULT`
  otherwise, with an empty order list.
- Local order-capable buildings (armed structures, undeployable structures) are unaffected —
  the order filter keys on ownership (`StatsComponent.player_id`), never on entity kind.
- Box select continues to exclude enemies; drag-select of own units is unchanged.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `order-system`: unselected-target click falls through to selection when no order applies
  (enemy included); non-local selected entities never generate commands, and their cursor is
  limited to `SELECT`/`DEFAULT`.
- `selection-manager`: selection rejects cross-ownership mixing (adding a non-local entity, or
  adding any entity while a non-local is selected, clears the selection first).

## Impact

- `scripts/orders/UnitOrderGenerator.gd` — local-selection filter feeding `resolve_single` /
  `resolve_all`.
- `scripts/core/SelectionManager.gd` — ownership-exclusivity on selection add.
- `scripts/hud/MouseHandler.gd` — unify enemy click routing into the selection fallthrough.
- `test/unit/test_unit_order_generator.gd`, `test/unit/test_selection_manager.gd` —
  regression coverage.
- `openspec/specs/order-system/spec.md`, `openspec/specs/selection-manager/spec.md` — deltas.
- No `.tscn` changes, no data-model changes, no `OrderResolver` changes.
