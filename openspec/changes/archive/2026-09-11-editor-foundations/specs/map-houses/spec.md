## ADDED Requirements

### Requirement: House id vocabulary
The system SHALL provide a canonical house id vocabulary module (`Houses.gd`)
whose ids are `GDI`, `Nod`, `Neutral`, and `Special`, matching the ownership
strings already used by `EntityData.owner` and the editor/sidebar faction
colors. Houses are factions (the TS rules-side `[Houses]` list); player slots
are a separate axis (start locations / waypoints 0–7) and SHALL NOT be modeled
as houses. The module SHALL expose `id_for(index)`, `index_for(house_id)`, and
`display_name_for(house_id)` helpers.

#### Scenario: Index to id
- **WHEN** `id_for(0)`, `id_for(1)`, `id_for(2)`, and `id_for(3)` are called
- **THEN** they return `"GDI"`, `"Nod"`, `"Neutral"`, and `"Special"`

#### Scenario: Id to index
- **WHEN** `index_for("Nod")` is called
- **THEN** it returns `1`

#### Scenario: Unknown house
- **WHEN** `index_for("not_a_house")` is called
- **THEN** it returns `-1` and `display_name_for` returns the input unchanged

#### Scenario: Vocabulary matches owner strings
- **WHEN** the house ids are compared against the values shipped in `EntityData.owner`
- **THEN** every shipped owner value (`GDI`, `Nod`, `Neutral`) is a house id, and no house id uses a different casing

### Requirement: Entity house ownership resolution
Map entity entries SHALL carry an optional `house_id` identifying the owning
house. When loading, the system SHALL prefer an explicit `house_id`; otherwise
it SHALL map a legacy `player_id` that is a valid house index onto that house,
and SHALL return no house for a `player_id` outside the house list. Resolving a
house SHALL NOT change the entity's gameplay player slot by itself.

#### Scenario: Explicit house wins
- **WHEN** entry `{"house_id": "Nod", "player_id": 0}` is resolved
- **THEN** the resolved house is `"Nod"`

#### Scenario: Legacy player slot alias
- **WHEN** an entry has only `{"player_id": 1}`
- **THEN** the resolved house is `"Nod"`

#### Scenario: No house information
- **WHEN** an entry has no `house_id` and a `player_id` at or beyond the house list size
- **THEN** no house is resolved
