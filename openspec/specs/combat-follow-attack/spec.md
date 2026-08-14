## Purpose

CombatComponent follow-attack chase behavior: obstacle-aware re-planning against a moving target via leg invalidation, passable chase destinations, and fail-safe handling of blocked or unreachable approach paths.

## Requirements

### Requirement: CombatComponent invalidates stale chase legs
When follow-attacking a moving target, `CombatComponent` SHALL treat an in-flight combat move as stale the moment the target's grid cell differs from the cell the leg was planned against. A stale leg SHALL trigger a new obstacle-aware approach move, throttled to a minimum interval between re-plans. A target that does not change cell SHALL NOT trigger re-plans.

#### Scenario: Target crosses a cell boundary mid-chase
- **WHEN** the attacker is mid-move on a chase leg and the target's cell changes from the cell recorded when the leg was planned
- **THEN** CombatComponent SHALL issue a new approach move toward the target's current position

#### Scenario: Stationary target causes no re-plan
- **WHEN** the attacker is mid-move on a chase leg and the target's cell does not change
- **THEN** CombatComponent SHALL NOT issue a new move until the current leg completes

#### Scenario: Re-plan throttling
- **WHEN** the target changes cells repeatedly within the re-plan throttle interval
- **THEN** CombatComponent SHALL issue at most one re-plan per throttle interval

### Requirement: Chase re-plans route around blockers
Each re-planned chase move SHALL respect the current blocker set (including building footprints) and SHALL route around blocked cells instead of walking through them. The attacker SHALL never end up inside a building's footprint while follow-attacking.

#### Scenario: Building blocks the direct approach
- **WHEN** a building cell lies between the attacker and its chased target's live position
- **THEN** the re-planned chase path SHALL detour around the building cell

#### Scenario: Attacker never enters a building footprint
- **WHEN** the attacker chases a target that moves behind a building
- **THEN** the attacker's path SHALL NOT contain any cell inside the building's footprint

### Requirement: Chase destination is passable
The computed chase stop position SHALL be a passable cell. If the geometrically computed stop position (on the weapon range circle toward the target) lands on a blocked cell, the destination SHALL be relocated to a nearby passable cell before the move is issued.

#### Scenario: Stop position lands inside a building footprint
- **WHEN** the range-circle stop position toward the target falls on a blocked cell
- **THEN** CombatComponent SHALL relocate the destination to a nearby passable cell and move there

#### Scenario: Clear stop position is unchanged
- **WHEN** the range-circle stop position toward the target falls on a passable cell
- **THEN** CombatComponent SHALL issue the move to that position unchanged

### Requirement: WAIT state is replan-eligible for out-of-range targets
A follow-attacking unit in `State.WAIT` (settled because its final cell was occupied) SHALL still re-plan an approach move when its target is out of weapon range.

#### Scenario: Attacker waits while target leaves range
- **WHEN** the attacker is in `State.WAIT` and its target's horizontal distance exceeds weapon range
- **THEN** CombatComponent SHALL issue a new approach move toward the target

#### Scenario: Attacker waits while target stays in range
- **WHEN** the attacker is in `State.WAIT` and its target is within weapon range
- **THEN** CombatComponent SHALL fire normally and SHALL NOT re-plan a move

### Requirement: Unreachable targets are retried with backoff
When the pathfinder reports a failed chase move, `CombatComponent` SHALL NOT retry pathfinding every physics tick. It SHALL retry after a backoff interval, fire in place while the target is within range, and keep the attack target active.

#### Scenario: Pathfinding fails for an unreachable target
- **WHEN** a chase move to an unreachable target fails pathfinding
- **THEN** CombatComponent SHALL wait at least the backoff interval before attempting the chase move again

#### Scenario: In-range target after failed path
- **WHEN** a chase move failed pathfinding but the target is within weapon range
- **THEN** CombatComponent SHALL fire at the target while it remains in range

### Requirement: Combat re-targets preserve the attack target
Re-planned chase moves SHALL NOT clear the attack target through the `movement_started` signal. Only a completed player move order, target death, or explicit order SHALL clear the attack target.

#### Scenario: Re-plan keeps the attack target
- **WHEN** CombatComponent re-plans a chase move while `movement_started` fires
- **THEN** `_target` SHALL remain set and the attacker SHALL continue engaging

#### Scenario: Player move order clears the attack target
- **WHEN** the player issues a move order to a follow-attacking unit
- **THEN** the attack target SHALL be cleared and the unit SHALL follow the move order
