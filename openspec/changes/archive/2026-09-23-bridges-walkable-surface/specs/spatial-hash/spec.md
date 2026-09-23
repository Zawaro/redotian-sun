## ADDED Requirements

### Requirement: Level-aware occupancy and blocking
`SpatialHash` occupancy and blocking queries SHALL be scoped by surface level. Each entity entry SHALL carry the level it occupies; `get_blocked_cells(level)`, `get_entries(cell, level)`, and `is_cell_blocked(cell, level)` SHALL return results for that level only, with `level` defaulting to `0`. `is_any_entity_on_cell(cell, level = -1)` SHALL accept `-1` to mean any level (legacy probes) and an exact level otherwise. A unit on a deck SHALL NOT block or count toward the ground level beneath it, and a unit on the ground SHALL NOT block the deck. The per-level results SHALL match what a full rebuild would have produced.

#### Scenario: Deck unit does not block ground
- **WHEN** an idle unit sits on a high deck over a cell and the ground level is queried
- **THEN** the ground cell is not blocked by that unit

#### Scenario: Ground unit does not block deck
- **WHEN** an idle unit sits on the ground under a high deck and the deck level is queried
- **THEN** the deck cell is not blocked by that unit

#### Scenario: Default level is ground
- **WHEN** `get_blocked_cells()` / `get_entries(cell)` are called without a level
- **THEN** they return level-0 results, matching pre-change behavior

#### Scenario: Same-level blocking preserved
- **WHEN** an idle non-sharing vehicle sits at a cell on level 0
- **THEN** level 0 reports that cell blocked, as before

### Requirement: Live bridge cell registry is level-aware
`SpatialHash` SHALL maintain a live registry of bridge cells, rebuilt with the existing membership scan alongside the ice registry. Bridge entities SHALL be discovered by their `"bridge"` group membership and keyed by `(cell, level)`, and the registry SHALL expose whether a cell has a bridge at a level (`has_bridge_on_cell(cell, level)`) and that surface's metadata (bridge kind, end flag, piece identifier, walkable surface height). Multiple deck levels over the same cell SHALL coexist as separate entries. Removing or destroying a bridge entity SHALL remove its `(cell, level)` entry on the next rebuild.

#### Scenario: Bridge cell registered at its level
- **WHEN** a bridge entity occupies a cell at level `L` and the registry rebuilds
- **THEN** `has_bridge_on_cell(cell, L)` returns true

#### Scenario: Stacked decks are separate entries
- **WHEN** two decks occupy the same cell at different levels
- **THEN** the registry reports a surface for each level independently

#### Scenario: Removed bridge leaves the registry
- **WHEN** a bridge entity is removed and the registry rebuilds
- **THEN** `has_bridge_on_cell` for its former `(cell, level)` returns false

#### Scenario: Metadata exposed
- **WHEN** a bridge cell is registered
- **THEN** its kind, end flag, piece identifier, and surface height are queryable from the registry

#### Scenario: Rebuild empty
- **WHEN** no bridge entities exist
- **THEN** the registry reports no bridge cells at any level

### Requirement: Level-aware cell reservation
`SpatialHash` cell reservation SHALL be scoped by level: `reserve_cell(cell, level)`, `release_cell(cell, level)`, and `force_reserve(cell, level)` SHALL operate on the `(cell, level)` reservation, with `level` defaulting to 0. A reservation on a deck SHALL NOT block a reservation on the ground beneath it, and existing callers that pass no level SHALL reserve level 0 exactly as today.

#### Scenario: Deck reservation independent of ground
- **WHEN** the ground level of a cell is reserved
- **THEN** the deck level of the same cell can still be reserved

#### Scenario: Default level reservation
- **WHEN** `reserve_cell(cell)` is called without a level
- **THEN** it reserves the level-0 cell, matching pre-change behavior

#### Scenario: Same-level reservation still fails when taken
- **WHEN** a `(cell, level)` is already reserved and reserved again
- **THEN** the second reservation fails
