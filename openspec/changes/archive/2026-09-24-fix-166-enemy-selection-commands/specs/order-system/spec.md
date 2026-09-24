## ADDED Requirements

### Requirement: Non-local selected entities are never commandable

`UnitOrderGenerator` SHALL exclude non-local (enemy) selected entities from order generation.
Ownership SHALL be determined from the selected entity's `StatsComponent.player_id` (missing
component or `player_id < 0` counts as local); the filter SHALL key on ownership only and MUST
NOT key on entity kind or component set, so local order-capable buildings (armed structures,
undeployable structures) remain fully commandable.

When the selection resolves to no local entity, `get_orders()` SHALL return an empty array and
`get_cursor()` SHALL return `CursorState.Type.SELECT` when the hovered target is a selectable
entity that is not already selected (so the player can click to re-select another entity),
otherwise `CursorState.Type.DEFAULT`. No command cursor (`MOVE`, `ATTACK`, `HARVEST`, `ENTER`,
`DEPLOY`) SHALL ever be produced for a non-local selection. Targets rejected by an earlier gate
— the bounds gate (`OrderSystem._order_bounds`) returns `GENERIC_BLOCKED`, the fog gate falls a
shrouded target through to the move path — keep that gate's outcome.

#### Scenario: Enemy selection shows DEFAULT cursor over ground
- **WHEN** only an enemy unit is selected and the cursor hovers empty ground
- **THEN** `get_cursor()` SHALL return `DEFAULT`

#### Scenario: Enemy selection shows SELECT cursor over an unselected selectable target
- **WHEN** only an enemy unit is selected and the cursor hovers a selectable entity that is not in the selection
- **THEN** `get_cursor()` SHALL return `SELECT`

#### Scenario: Enemy selection shows DEFAULT cursor over itself
- **WHEN** only an enemy unit is selected and the cursor hovers that same enemy
- **THEN** `get_cursor()` SHALL return `DEFAULT`

#### Scenario: Enemy selection returns no move order
- **WHEN** only an enemy unit is selected and a ground position is clicked
- **THEN** `get_orders()` SHALL return an empty array

#### Scenario: Enemy harvester receives no harvest or dock order
- **WHEN** only an enemy harvester is selected and a tiberium resource or an enemy refinery is clicked
- **THEN** `get_orders()` SHALL return an empty array
- **AND** `get_cursor()` SHALL return `DEFAULT` (never `HARVEST` or `ENTER`)

#### Scenario: Enemy armed or undeployable building receives no order
- **WHEN** only an enemy building with a `CombatComponent` or an undeploy-capable `DeployComponent` is selected and the cursor hovers empty ground
- **THEN** `get_orders()` SHALL return an empty array
- **AND** `get_cursor()` SHALL return `DEFAULT`

#### Scenario: Local armed building remains commandable
- **WHEN** a local building with a `CombatComponent` is selected and an enemy entity is clicked
- **THEN** `get_orders()` SHALL return a non-empty list containing the `ATTACK` order
- **AND** `get_cursor()` SHALL return `ATTACK`

#### Scenario: Local undeployable building remains commandable
- **WHEN** a local building with an undeploy-capable `DeployComponent` is selected and ground is clicked
- **THEN** `get_orders()` SHALL return a non-empty list containing the undeploy order

### Requirement: Unselected target click falls through to selection when no order applies

`MouseHandler` SHALL route a left-click on an unselected entity through `OrderSystem` first
(unless the select modifier is held). When the current selection produces no order, the entity
SHALL be selected instead of the click being swallowed. The same rule SHALL apply to enemy and
friendly/neutral targets; an unselected entity MUST NOT be selected when an order is produced
(e.g. an armed unit clicking an enemy attacks rather than selecting it).

#### Scenario: Armed unit clicking an enemy attacks, not selects
- **WHEN** an armed unit is selected and an unselected enemy is clicked
- **THEN** the `ATTACK` order SHALL execute
- **AND** the enemy SHALL NOT be selected

#### Scenario: Non-attacking selection clicking an enemy selects it
- **WHEN** a non-combat unit is selected and an unselected enemy is clicked (no order produced)
- **THEN** the enemy SHALL be selected (replacing the previous selection)

#### Scenario: Enemy selection clicking another enemy replaces it
- **WHEN** one enemy is selected and a different unselected enemy is clicked
- **THEN** the clicked enemy SHALL become the sole selection

#### Scenario: Enemy selection clicking a friendly entity replaces it
- **WHEN** an enemy is selected and an unselected friendly entity is clicked
- **THEN** the friendly entity SHALL be selected (the enemy is cleared)
