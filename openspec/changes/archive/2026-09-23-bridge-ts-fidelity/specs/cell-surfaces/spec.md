## MODIFIED Requirements

### Requirement: Height-parameterized surface queries
Surface identity and height SHALL be queryable for a given level. `TerrainSystem.get_land_type(cell, level)` SHALL return the land type of the surface at `level` — for a deck, the land that lane resolves (`road`, `railroad`, or `clear`), never a synthetic `bridge` type — and `TerrainSystem.get_cell_surface_height(cell, level)` SHALL return the walkable world Y of the surface at `level`. Both queries SHALL accept an optional `level` argument defaulting to `0`. Queried at level 0, they SHALL return the ground land type and ground surface height exactly as today. A query for a level with no surface SHALL report no land type (empty string at levels above 0); the height query MAY fall back to the terrain height so movement/rendering callers never receive an invalid Y.

#### Scenario: Default level is ground
- **WHEN** `get_land_type(cell)` and `get_cell_surface_height(cell)` are called without a level
- **THEN** they return the ground land type and ground height (level 0)

#### Scenario: Deck level resolves deck surface
- **WHEN** a deck surface exists at level `L` for a cell and it is queried at `L`
- **THEN** the query returns the deck's resolved land type and the deck world Y

#### Scenario: Rail deck reports railroad
- **WHEN** a rail-bridge middle lane exists at level `L` and is queried at `L`
- **THEN** the query returns `"railroad"`

#### Scenario: Ground beneath a deck is still ground
- **WHEN** a cell carries a deck at level > 0 and is queried at level 0
- **THEN** the query returns the underlying land type and ground height, not the deck's

#### Scenario: Absent level reports no surface
- **WHEN** a cell with only a ground surface is queried at level > 0
- **THEN** the query reports no surface at that level
