## ADDED Requirements

### Requirement: Level-scoped sub-slot claims
`CellReservation` SHALL key in-flight sub-slot claims by `(cell, level)`, with `level` defaulting to 0. `reserve_sub_slot(cell, owner, level)`, `release_sub_slot(cell, owner, level)`, `get_available_sub_slot(cell, level)`, and `get_slot_owner(cell, slot, level)` SHALL be level-scoped. A claim on a deck SHALL NOT count toward the ground level's capacity beneath it, and vice versa. An owner's claims SHALL be tracked per `(cell, level)` so moving between levels follows the same release-then-claim discipline as moving between cells.

#### Scenario: Deck claim does not fill ground
- **WHEN** a cell's deck level is fully claimed and the ground level is empty
- **THEN** the ground level still reports available slots

#### Scenario: Ground claim does not fill deck
- **WHEN** a cell's ground level is fully claimed and the deck level is empty
- **THEN** the deck level still reports available slots

#### Scenario: Default level preserves behavior
- **WHEN** `reserve_sub_slot(cell, owner)` is called without a level
- **THEN** the claim is made at level 0, matching pre-change behavior

#### Scenario: Level change releases the old claim
- **WHEN** an owner holding a claim on `(cell, level_a)` reserves `(cell, level_b)`
- **THEN** the claim on `level_a` is released before the claim on `level_b` is made

#### Scenario: Combined capacity per level
- **WHEN** a level has physical idle sharers plus in-flight claims at that level totaling `CellSubPositions.get_slot_count()`
- **THEN** that level is full for sharing-unit targeting
