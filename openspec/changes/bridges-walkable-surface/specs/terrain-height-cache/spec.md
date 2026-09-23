## ADDED Requirements

### Requirement: Level surfaces beyond the terrain snapshot
The world-lifetime height snapshot SHALL be extended to answer per-cell surface heights for deck levels beyond the terrain surface, keyed by `(cell, level)`. Level 0 SHALL continue to resolve from the existing terrain corner-vertex snapshot. A deck level SHALL resolve from the level-aware bridge registry / surface stack, and SHALL NOT overwrite the level-0 corner data. Querying a level with no surface SHALL report no height rather than the ground value.

#### Scenario: Level 0 unchanged
- **WHEN** a level-0 height is queried and the cell has no deck
- **THEN** it resolves from the terrain corner-vertex snapshot exactly as before

#### Scenario: Deck level resolves independently
- **WHEN** a cell carries a deck at level `L` and the height is queried at `L`
- **THEN** it returns the deck surface height without altering the level-0 entry

#### Scenario: Absent level reports no height
- **WHEN** a cell has only a ground surface and a height is queried at level > 0
- **THEN** no surface height is returned

### Requirement: Level snapshot invalidated on deck change
The `(cell, level)` surface-height entries SHALL be invalidated when a bridge deck registers or unregisters (a surface is added or removed at a level), in addition to the existing terrain-mutation invalidation. After invalidation, the next query for an affected `(cell, level)` SHALL re-read the live surface. No stale deck height SHALL be served after a bridge change. Level-0 terrain entries SHALL be unaffected by bridge changes.

#### Scenario: Deck add invalidates the level entry
- **WHEN** a bridge deck is added at `(cell, level)` after a height query cached no surface there
- **THEN** the next query returns the new deck height

#### Scenario: Deck remove invalidates the level entry
- **WHEN** a bridge deck is removed at `(cell, level)`
- **THEN** the next query for that `(cell, level)` reports no surface

#### Scenario: Ground entries unaffected by a deck change
- **WHEN** a deck is added at a cell and its level-0 entry was cached
- **THEN** the level-0 cached value remains valid and unchanged
