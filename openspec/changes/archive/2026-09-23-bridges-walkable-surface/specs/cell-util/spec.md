## ADDED Requirements

### Requirement: Cell identity carries a level for movement and occupancy
Cell identity used for movement and occupancy SHALL be the pair `(cell, level)`. `CellUtil` SHALL provide a level-aware key `cell_level_key(cell: Vector2i, level: int) -> int` that combines the existing `cell_key(cell)` with the level into a unique, deterministic, collision-free dictionary key. The level SHALL default to 0 wherever cell identity is consumed for movement or occupancy, so existing level-0 callers keep the existing `cell_key` behavior. `CellUtil.world_to_cell` and `cell_to_world` SHALL remain level-independent (XZ projection); only the identity key gains a level.

#### Scenario: Level key is deterministic
- **WHEN** `cell_level_key(cell, level)` is called twice for the same cell and level
- **THEN** both calls return the same value

#### Scenario: Levels produce distinct keys
- **WHEN** `cell_level_key(cell, 0)` and `cell_level_key(cell, 1)` are called for the same cell
- **THEN** the results are different

#### Scenario: Different cells at the same level differ
- **WHEN** `cell_level_key(cell_a, 2)` and `cell_level_key(cell_b, 2)` are called for different cells
- **THEN** the results are different

#### Scenario: Level 0 preserves the plain cell key
- **WHEN** `cell_level_key(cell, 0)` is used
- **THEN** it is consistent with `cell_key(cell)` for the same cell

#### Scenario: World conversion ignores level
- **WHEN** `world_to_cell` / `cell_to_world` are called
- **THEN** the returned XZ coordinates do not depend on a level
