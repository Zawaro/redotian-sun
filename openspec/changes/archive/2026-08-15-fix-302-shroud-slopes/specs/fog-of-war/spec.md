# fog-of-war Specification (delta)

## MODIFIED Requirements

### Requirement: Height-aware shadowcasting

Revealed cells SHALL be computed by per-cell Bresenham line-of-sight from the revealer center to each candidate cell within radius. A candidate cell is revealed only if no intermediate cell blocks it. A cell with an edge rising at most one height level (`TerrainSystem.get_cell_grade_steps` == 1 — a walkable graded slope or stair) SHALL NOT block line of sight, regardless of viewer height. A cell with a steeper edge or a flat raised surface SHALL block vision when its terrain height (`TerrainSystem.get_cell_max_height`) exceeds the viewer height by more than `max_height_delta`. Buildings do not block line of sight. The revealer's own cell and the candidate cell itself are not blockers. Viewer height SHALL be supplied at registration and SHALL be updated when a revealer moves (`move_revealer`), so a unit's climbing eye height is reflected in its shadowcast. Air revealers (`blocks_terrain = false`) SHALL ignore all blockers and reveal a full circle within radius.

#### Scenario: Hill blocks vision

- **WHEN** a low revealer is below a hill whose height exceeds the viewer height plus delta
- **THEN** cells on the far side of the hill are not revealed, and the hill's own cells are revealed

#### Scenario: High ground sees over

- **WHEN** a revealer sits atop a ridge with viewer height above the valley floor
- **THEN** cells in the valley below within radius are revealed

#### Scenario: Building does not block vision

- **WHEN** a building cell lies on the line between a revealer and a candidate cell
- **THEN** the candidate cell is still revealed by that revealer, and the building's own cells are revealed

#### Scenario: Air revealer ignores blockers

- **WHEN** an air revealer (`blocks_terrain = false`) registers over a hill
- **THEN** all cells within radius are revealed regardless of intervening terrain

#### Scenario: Graded slope does not block vision

- **WHEN** a cell with one level of edge rise (e.g. raw corners `[0, 0, 1, 1]`) lies on the line between a revealer and a candidate cell
- **THEN** the candidate cell is still revealed, even when the slope's tall corner exceeds the viewer height plus delta

#### Scenario: Walkable stair spanning two levels does not block vision

- **WHEN** a cell whose corners span two height levels but every edge rises one step (e.g. raw corners `[0, 1, 1, 2]`) lies on the line between a revealer and a candidate cell
- **THEN** the candidate cell is still revealed, because the stair is walkable (edge rise == 1)

#### Scenario: Flat plateau blocks from below

- **WHEN** a flat raised cell (grade 0, all corners equal) whose height exceeds the viewer height plus delta lies on the line between a low revealer and a candidate cell
- **THEN** the candidate cell is not revealed from low ground

#### Scenario: Climbing raises viewer height and reveals behind

- **WHEN** a revealer moves onto a plateau and its `viewer_height` is updated to the higher vantage
- **THEN** cells behind the plateau that were hidden from the low vantage become revealed, and the revealer's disc is re-evaluated from the new height

#### Scenario: Move with unchanged height keeps crescent fast path

- **WHEN** a revealer moves across flat terrain and its `viewer_height` is unchanged
- **THEN** only the entering/exiting crescent between the old and new discs is re-stamped; overlap cells are not re-evaluated
