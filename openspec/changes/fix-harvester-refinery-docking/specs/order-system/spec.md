## ADDED Requirements

### Requirement: Left-click routes friendly unselected targets through orders first
When a left-click hits a selectable entity that is friendly/neutral and not currently selected, and the player has a selection, `MouseHandler` SHALL consult `OrderSystem.get_orders(target, target_cell, target_pos, modifiers)` before selecting. If the order list is non-empty, the orders SHALL execute and selection SHALL be skipped. Only when no orders are produced SHALL the entity be selected.

#### Scenario: Click refinery with harvester selected issues dock order
- **WHEN** a harvester is selected and the player left-clicks a friendly unselected refinery (DockHostComponent target)
- **THEN** the ENTER dock order SHALL execute (`set_target_refinery`)
- **AND** the refinery SHALL NOT be selected

#### Scenario: Click tiberium with harvester selected issues harvest order
- **WHEN** a harvester is selected and the player left-clicks a friendly unselected tiberium pod (ResourceComponent target)
- **THEN** the HARVEST order SHALL execute (`set_target_node`)
- **AND** the tiberium SHALL NOT be selected

#### Scenario: Click friendly unit with no order selects it
- **WHEN** units are selected and the player left-clicks a friendly unselected unit that produces no orders
- **THEN** the unit SHALL be selected (orders empty → fallback to selection)

#### Scenario: Empty selection still selects
- **WHEN** nothing is selected and the player left-clicks a friendly unselected entity
- **THEN** the entity SHALL be selected

#### Scenario: Shift+click forced selection unaffected
- **WHEN** the player shift+clicks a friendly unselected entity
- **THEN** selection behavior SHALL be unchanged (queued selection, no order execution)

#### Scenario: Enemy routing unchanged
- **WHEN** the target is an enemy and the selection can produce an order
- **THEN** the order SHALL execute as before (no behavior change to the enemy branch)
