## ADDED Requirements

### Requirement: Selection is exclusive across ownership

`SelectionManager` SHALL never hold a selection that mixes local and non-local entities.
Enemy (non-local) entities SHALL remain selectable for viewing, governed by the normal
selectability gates (visible bounds and shroud/reveal) and by the select modifier; ownership
SHALL NOT by itself make an entity unselectable. When an entity is added to the selection and
either the current selection's head is non-local or the incoming entity is non-local, the
existing selection SHALL be cleared first. Only local entities may coexist in one selection.
Consequently a non-local selection SHALL always contain a single entity.

Ownership SHALL be determined from `StatsComponent.player_id` (missing component or
`player_id < 0` counts as local), matching `SelectionManager._is_local_entity_node`.

#### Scenario: Shift-click an enemy while own units are selected clears them
- **WHEN** local units are selected and the player shift-clicks an enemy entity
- **THEN** the local units SHALL be deselected
- **AND** the enemy SHALL be the sole selected entity

#### Scenario: Shift-click a local unit while an enemy is selected clears it
- **WHEN** an enemy is selected and the player shift-clicks a local unit
- **THEN** the enemy SHALL be deselected
- **AND** the local unit SHALL be the sole selected entity

#### Scenario: A second enemy replaces the first
- **WHEN** an enemy is selected and the player shift-clicks a different enemy
- **THEN** the previously selected enemy SHALL be deselected
- **AND** only the newly clicked enemy SHALL remain selected

#### Scenario: Shift-click a local unit still adds
- **WHEN** a local unit is selected and the player shift-clicks another local unit
- **THEN** both local units SHALL be selected (no clearing)

#### Scenario: Plain click selects a lone enemy
- **WHEN** nothing is selected and the player clicks a selectable enemy
- **THEN** the enemy SHALL be selected

#### Scenario: Box-select while an enemy is selected clears it
- **WHEN** an enemy is selected and the player shift-drags a box over local units
- **THEN** the enemy SHALL be deselected
- **AND** only the local units SHALL be selected
