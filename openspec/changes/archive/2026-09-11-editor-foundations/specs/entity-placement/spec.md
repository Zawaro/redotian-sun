## ADDED Requirements

### Requirement: Entity house assignment
The entity placer SHALL accept a selected house id and SHALL record it as
`house_id` in a placed entity's metadata when one is selected. When no house is
selected, placement SHALL keep the legacy `player_id`-only metadata unchanged.

#### Scenario: Place with a house
- **WHEN** a house is selected and an entity is placed
- **THEN** the entity's metadata includes `house_id` for that house

#### Scenario: Place without a house
- **WHEN** no house is selected and an entity is placed
- **THEN** the entity's metadata has no `house_id` and retains its `player_id`

## MODIFIED Requirements

### Requirement: Data persistence
Placed entities SHALL be stored in `_painted_entities` dictionary with key format `"x,y"` (cell coordinates). Value is `{"node": Node3D, "data": Dictionary}` containing `id`, `player_id`, an optional `house_id`, and optional overrides.

#### Scenario: Entity stored on placement
- **WHEN** entity is placed at cell (15, 20)
- **THEN** `_painted_entities["15,20"]` contains the entity node and metadata

#### Scenario: Entity metadata includes player_id
- **WHEN** entity is placed for Player 1
- **THEN** metadata `data.player_id` is 1

#### Scenario: Entity metadata includes house_id
- **WHEN** entity is placed with house `Nod` selected
- **THEN** metadata `data.house_id` is `"Nod"`

### Requirement: Save includes player_id
Map save JSON SHALL include `player_id` field in each entity entry. When an entity carries a `house_id`, the saved entry SHALL include it and SHALL keep the legacy `player_id` in sync by writing the house's index when no explicit `player_id` is present. Load SHALL restore entity with correct player assignment. Existing maps without `player_id` default to Player 0.

#### Scenario: Save with player_id
- **WHEN** map is saved with entities for Player 1
- **THEN** JSON contains `"player_id": 1` in entity entries

#### Scenario: Save writes house_id and alias
- **WHEN** an entity carrying `house_id = "Nod"` and no explicit `player_id` is saved
- **THEN** the JSON entry contains `"house_id": "Nod"` and `"player_id": 1`

#### Scenario: Explicit player_id is preserved
- **WHEN** an entity carries both `house_id` and an explicit `player_id`
- **THEN** the saved `player_id` is the explicit value, not the house index

#### Scenario: Load with player_id
- **WHEN** map JSON has `"player_id": 1` on an entity
- **THEN** entity is created with `player_id == 1`

#### Scenario: Backward compatibility
- **WHEN** map JSON has no `player_id` field on an entity
- **THEN** entity defaults to `player_id == 0`
