## ADDED Requirements

### Requirement: Fog-gated target filtering
`OrderSystem` SHALL treat a target entity as absent when its cell is not visible to the local player, gated on `GlobalRules.fog_of_war`. When fog of war is enabled, for cursor resolution and order generation: an entity (unit, building, or resource such as tiberium) in a cell not visible to the local player (including allied-union visibility) SHALL behave as a null target, falling through to the move path. Attack targeting — both entity-targeted and force-fire ground orders — SHALL NOT be issued at cells not visible to the local player. The same gate SHALL apply to hover preview and entity selection. When `fog_of_war` is false, no filtering occurs and all targets resolve as before.

#### Scenario: Shrouded enemy falls through to move
- **WHEN** fog of war is enabled and an enemy entity sits in a cell not visible to the local player
- **THEN** hovering it produces the move cursor and clicking it issues a move order, never an attack

#### Scenario: Revealed enemy is attackable
- **WHEN** the enemy's cell becomes visible to the local player
- **THEN** normal attack cursors and orders apply

#### Scenario: Force-fire into shroud gated
- **WHEN** fog of war is enabled and force-fire targets a cell not visible to the local player
- **THEN** the force-fire attack is not issued and the input falls through to a move order

#### Scenario: Shrouded resource not harvestable
- **WHEN** a tiberium crystal sits in a cell not visible to the local player
- **THEN** it is not targetable for harvest and is excluded from hover targeting

#### Scenario: Shrouded entity not selectable
- **WHEN** an entity is in a cell not visible to the local player
- **THEN** it cannot be selected by click or box selection and does not appear in hover preview

#### Scenario: Filter disabled without fog
- **WHEN** `fog_of_war` is false
- **THEN** all entities are interactable regardless of shroud state
