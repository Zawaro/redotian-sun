## ADDED Requirements

### Requirement: Picking resolves the surface level
Terrain picking SHALL resolve which surface level a cursor ray hits, returning the `(cell, level)` pair. A ray that intersects a high bridge deck SHALL resolve to the deck level, so selecting the deck selects its surface and occupants. The ground level beneath the deck SHALL remain selectable: the picker SHALL report the ground candidate as well, and SHALL NOT treat the deck as hiding the ground. When no deck is intersected, picking SHALL resolve to level 0 as today.

#### Scenario: Click on a high deck selects the deck
- **WHEN** a cursor ray hits a high bridge deck
- **THEN** the pick resolves to the deck's level at that cell

#### Scenario: Ground beneath the deck stays selectable
- **WHEN** a cursor ray would hit the ground under a high deck and no deck is hit at that screen point
- **THEN** the pick resolves to level 0

#### Scenario: Deck reports both candidates
- **WHEN** a cursor ray crosses both a deck surface and the ground beneath it
- **THEN** the picker returns both the deck-level and ground-level candidates for disambiguation

#### Scenario: No deck resolves ground
- **WHEN** a cursor ray hits terrain with no bridge deck
- **THEN** the pick resolves to level 0, matching pre-change behavior
