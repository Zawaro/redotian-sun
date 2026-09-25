## MODIFIED Requirements

### Requirement: Fog-gated target filtering
`OrderSystem` SHALL treat a target entity as absent when its cell is not visible to the local player. Visibility is the shroud/fog **cover state**, not the `fog_of_war` rule directly: `ShroudSystem.is_shroud_enabled()` decides whether never-explored cells stay hidden, `ShroudSystem.is_fog_enabled()` decides whether explored cells may go dark, and `ShroudSystem.is_cell_visible_to_local()` combines them. When fog of war is enabled, for cursor resolution and order generation: an entity (unit, building, or resource such as tiberium) in a cell not visible to the local player (including allied-union visibility) SHALL behave as a null target, falling through to the move path. Attack targeting against an **entity** SHALL NOT be issued at cells not visible to the local player.

A **force-fire ground** order SHALL be gated on the shroud instead of the fog: `OrderSystem` SHALL issue it only when the clicked cell has been explored by the local player (`ShroudSystem.is_explored`), and SHALL strip `OrderResult.MOD_FORCE_ATTACK` when it has not, so the input degrades to a plain move. Fog — explored but not currently visible — SHALL NOT block a force-fire ground order. This shroud gate SHALL be enabled by `ShroudSystem.is_shroud_enabled()` and SHALL NOT be conditioned on `GlobalRules.fog_of_war`.

The entity gate SHALL apply to hover preview and entity selection. With both covers off — `shroud_enabled` false and `fog_of_war` false — no entity filtering occurs and all entities resolve as before. With the shroud on, never-explored cells stay hidden whether or not `fog_of_war` is set; the shroud gate for force-fire ground orders is likewise governed by `is_shroud_enabled()` alone.

#### Scenario: Shrouded enemy falls through to move
- **WHEN** fog of war is enabled and an enemy entity sits in a cell not visible to the local player
- **THEN** hovering it produces the move cursor and clicking it issues a move order, never an attack

#### Scenario: Revealed enemy is attackable
- **WHEN** the enemy's cell becomes visible to the local player
- **THEN** normal attack cursors and orders apply

#### Scenario: Force-fire into shroud gated
- **WHEN** fog of war is enabled and force-fire targets a cell the local player has never explored
- **THEN** the force-fire attack is not issued and the input falls through to a move order

#### Scenario: Force-fire into fog is allowed
- **WHEN** fog of war is enabled and force-fire targets a cell that the local player has explored but that is not currently visible to them
- **THEN** the force-fire attack SHALL be issued at that cell

#### Scenario: Shroud gate does not depend on fog of war
- **WHEN** `fog_of_war` is false, the shroud is enabled, and force-fire targets an unexplored cell
- **THEN** the force-fire attack is not issued and the input falls through to a move order

#### Scenario: Shrouded resource not harvestable
- **WHEN** a tiberium crystal sits in a cell not visible to the local player
- **THEN** it is not targetable for harvest and is excluded from hover targeting

#### Scenario: Shrouded entity not selectable
- **WHEN** an entity is in a cell not visible to the local player
- **THEN** it cannot be selected by click or box selection and does not appear in hover preview

#### Scenario: Filter disabled with both covers off
- **WHEN** `shroud_enabled` is false and `fog_of_war` is false
- **THEN** all entities are interactable regardless of their exploration state

#### Scenario: Fog off alone does not reveal the unexplored
- **WHEN** `fog_of_war` is false, `shroud_enabled` is true, and an enemy sits in a never-explored cell
- **THEN** it behaves as a null target, falling through to the move path

## ADDED Requirements

### Requirement: Force-fire ground order
When a click resolves no entity target and `OrderResult.MOD_FORCE_ATTACK` is held, `UnitOrderGenerator` SHALL resolve component orders for the selection instead of synthesising a move, and SHALL emit the single highest-priority result per entity. For an armed combat unit the result SHALL be an ATTACK order at the requested ground position, at a priority above movement (5) and deploy (15) orders. When the modifier is not held, the ground path SHALL be byte-for-byte the existing behaviour: an undeploy-capable selection resolves component orders first, a movable selection receives a synthesized MOVE, and an unarmed selection receives a MOVE. The order cursor SHALL mirror the emitted order rather than being decided independently.

#### Scenario: Force-fire on empty ground attacks
- **WHEN** an armed local selection Ctrl+clicks empty explored ground
- **THEN** an ATTACK order SHALL be produced at that ground position and the cursor SHALL be ATTACK

#### Scenario: Plain click on the same ground still moves
- **WHEN** the same armed local selection left-clicks the same empty ground without Ctrl
- **THEN** a MOVE order SHALL be produced at that position and the cursor SHALL be MOVE

#### Scenario: Force-fire on ground an unarmed selection still moves
- **WHEN** a local selection with no weapons Ctrl+clicks empty ground
- **THEN** no ATTACK order SHALL be produced and the selection SHALL receive a MOVE order

#### Scenario: Force-fire ground respects the visible-bounds clamp
- **WHEN** an armed local selection Ctrl+clicks empty ground outside the visible bounds
- **THEN** the ATTACK order SHALL be issued at the position clamped by `BoundsSystem.clamp_to_visible_diamond`, matching the existing ground-move clamp

#### Scenario: Undeployable selection yields to force-fire
- **WHEN** a deployed, armed local selection Ctrl+clicks empty ground
- **THEN** the ATTACK order (priority 30) SHALL win over the undeploy order (priority 5)

#### Scenario: Mixed selection — armed fire, unarmed hold
- **WHEN** a local selection mixing armed and unarmed units Ctrl+clicks empty ground
- **THEN** the armed units SHALL each receive an ATTACK order and the unarmed units SHALL receive no order at all — they neither fire nor move
