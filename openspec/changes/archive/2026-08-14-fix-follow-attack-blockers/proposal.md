## Why

When a unit is follow-attacking a moving enemy and a building blocks the straight-line approach, the attacker walks **into** the building instead of routing around it (GH #277). Root cause: `CombatComponent._move_toward_target` issues one obstacle-aware leg toward the enemy's live position, then early-returns on `mc.is_moving()` for the rest of the leg. If the enemy jukes behind a building mid-leg, the attacker executes the now-stale straight leg straight through the footprint and only re-plans on arrival.

## What Changes

- Replace the unconditional `is_moving()` gate in `CombatComponent._move_toward_target` with a **leg-invalidation check**: the chase leg is stale when the enemy's grid cell differs from the cell the leg was planned against, triggering a throttled obstacle-aware re-plan.
- Guarantee the chase destination is **passable**: clamp the ground-branch stop position to a non-blocked cell so a chase leg can never aim into a building footprint.
- Harden the surrounding state machine: WAIT becomes replan-eligible for an out-of-range target, `pathfinding_failed` gets a retry backoff (idle-fire in place instead of a per-frame A* storm), and combat follow moves use internal re-targets so the attack target is never consumed by `movement_started`.
- No behavior change for stationary targets: a target that never changes cell produces zero re-plans (preserves current performance and the #195/#256 fixes).

## Capabilities

### New Capabilities
- `combat-follow-attack`: Obstacle-aware follow-attack chase behavior — leg invalidation and throttled re-planning against a moving target, passable chase destinations, and fail-safe handling of blocked/unreachable approach paths.

### Modified Capabilities
<!-- None — combat-firing's range-check requirement is unchanged; the new chase behavior is additive and lives in its own capability. -->

## Impact

- `scripts/components/CombatComponent.gd` — chase leg tracking (`_chase_leg_enemy_cell`), replan throttle, passable-destination clamp, retry backoff.
- `scripts/components/MovementController.gd` — replan eligibility for WAIT state (via a shared `can_replan()`-style predicate or combat-side gate), `internal` re-target reuse; no change to the hot `_handle_moving_movement` path.
- No packed scene (.tscn) or resource changes; backward compatible.
- Perf: replan cost scales with enemy cell crossings, bounded by a throttle; the event-driven design avoids per-frame pathfinding for mass infantry (#284 constraint).
- Follow-on features #264 (attack-move) and #261 (guard AI) can reuse the same chase/engagement pattern.
