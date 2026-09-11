## ADDED Requirements

### Requirement: Map JSON persists terrain overlays and entity houses
The map JSON SHALL carry the optional keys `"cell_pins"` (cliff pins),
`"land_types"` (painted land-type overrides), and per-entity `"house_id"`.
All three SHALL be optional: a map lacking any of them SHALL load without
error, and `"player_id"` SHALL remain a valid alias for entity house
resolution.

#### Scenario: Cell pins restored
- **WHEN** `TerrainSystem.import_from_json` reads a `"cell_pins"` object
- **THEN** each in-diamond pinned cell is restored to its pinned object id

#### Scenario: Land types restored
- **WHEN** `TerrainSystem.import_from_json` reads a `"land_types"` object
- **THEN** each listed cell records its painted override

#### Scenario: Entity house loaded
- **WHEN** MapLoader reads an entity entry with `"house_id": "Nod"`
- **THEN** the created entity records `Nod` as its house

#### Scenario: Legacy map without overlay keys
- **WHEN** MapLoader reads a map with none of `"cell_pins"`, `"land_types"`, or `"house_id"`
- **THEN** it loads terrain and entities with no pins, no painted overrides, and house resolution falling back to the `player_id` alias
