## MODIFIED Requirements

### Requirement: Idle armed entity auto-acquires nearest enemy already in weapon range
While an entity has a `GuardComponent`, no active `CombatComponent` target, no in-progress movement, and power online (or no PowerComponent), the guard SHALL periodically scan for hostile entities within the longest weapon's range and, on finding at least one, call `CombatComponent.set_target()` with `hold_ground = true` on the nearest hostile. Acquisition range SHALL be `max(weapon.attack_range) * CellUtil.CELL_SIZE` world units over all of the entity's weapons, measured on the horizontal (XZ) plane. Candidate distance SHALL be measured to the candidate's effective target point: for a candidate with a `FoundationComponent`, the nearest point on its foundation footprint (the same measurement `CombatComponent` uses for range); otherwise the candidate's `global_position`. Hostility SHALL be `PlayerManager.is_enemy(self_player_id, candidate_player_id)` with both ids >= 0. The scan SHALL query `SpatialHash` cells within a square hood of Chebyshev radius `max(1, ceil(range_world / CellUtil.CELL_SIZE)) + BUILDING_HOOD_MARGIN_CELLS` cells centered on the entity (full ±r index square, not a cell-index circle — diagonal in-range entities must not be skipped), not a full `all_entries()` walk. `BUILDING_HOOD_MARGIN_CELLS` is a bounded constant of 4 covering the widest foundation in content (6x6, half-extent 3 cells) plus one cell of rounding slack, because `SpatialHash` indexes each entity at its centre cell: without the margin a building whose centre is outside weapon range but whose nearest footprint edge is inside it would never be scanned. Candidates SHALL be filtered to entities that have a HealthComponent.

#### Scenario: Enemy already inside weapon range is acquired
- **WHEN** an armed idle unit with GuardComponent has an enemy whose horizontal distance is <= longest weapon range and no active attack target
- **THEN** GuardComponent SHALL call `CombatComponent.set_target()` with `hold_ground = true` and the unit SHALL fire without issuing a chase move

#### Scenario: Building edge in range is acquired while center is out of range
- **WHEN** an armed idle unit has a hostile building whose foundation-footprint center is beyond the longest weapon range but whose nearest footprint point is within it
- **THEN** GuardComponent SHALL acquire that building, consistent with `CombatComponent` range checking

#### Scenario: Building acquired diagonally by its nearest corner
- **WHEN** a hostile building sits diagonally from the unit such that its footprint center is out of range but its nearest corner is within range
- **THEN** GuardComponent SHALL acquire the building (the widened hood covers the centre cell and the distance filter uses the corner)

#### Scenario: Enemy in sight but outside weapon range is ignored
- **WHEN** an enemy is farther than the longest weapon range (even if within `StatsComponent.sight`)
- **THEN** GuardComponent SHALL NOT acquire that enemy for this mode

#### Scenario: Nearest of multiple in-range enemies is chosen
- **WHEN** two or more hostile entities are within weapon range of an idle guarded unit
- **THEN** the candidate with the smallest horizontal distance to the unit SHALL be selected (ties: first found in deterministic cell scan order), where a building candidate's distance is to its nearest footprint point

#### Scenario: No enemy in weapon range stays idle
- **WHEN** a guarded unit scans and finds no hostile entity within weapon range
- **THEN** GuardComponent SHALL NOT call `set_target` and the unit SHALL remain idle

#### Scenario: Friendly or neutral entities are ignored
- **WHEN** entities within weapon range belong to the same team as the guard (or player_id < 0)
- **THEN** they SHALL NOT be selected as acquisition targets

#### Scenario: Diagonal corner cell within weapon range is acquired
- **WHEN** an enemy sits in a cell whose index offset from the unit fails a cell-index circle of radius `r_cells` (e.g. offset (4,4) with r_cells=5) but its horizontal world distance is still <= weapon range
- **THEN** GuardComponent SHALL still acquire that enemy (square hood, exact world distance)

#### Scenario: Candidate without HealthComponent is ignored
- **WHEN** a hostile entity within weapon range has no HealthComponent sibling
- **THEN** GuardComponent SHALL NOT select it as an acquisition target
