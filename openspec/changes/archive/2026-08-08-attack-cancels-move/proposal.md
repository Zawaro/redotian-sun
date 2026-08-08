## Why

A ground unit that receives an attack order while moving finishes its old move
path first, then engages — it fires on the move when the target is already in
range, or keeps walking to the stale destination when it is out of range.
Classic C&C behavior is that an attack order instantly supersedes the current
move. Reported in #195 (firing on the move / never stopping) and #256 (finishes
the move path before reacting).

## What Changes

- `CombatComponent.set_target()` halts a ground unit's in-progress move when an
  attack order is issued, while keeping the existing airborne jumpjet
  `cancel_move_retain_vertical()` path unchanged.
- When the attack target is already in range, the unit stops (settles to its
  sub-slot) and fires stationary instead of firing while walking.
- When the target is out of range, the old move path is dropped immediately and
  a new approach path is issued in the same frame, so the unit turns and moves
  toward the target right away (identical to receiving a fresh move order).
- The player-move-cancels-attack behavior is preserved; combat-initiated
  approaches still do not clear the attack target.

## Capabilities

### New Capabilities

- none

### Modified Capabilities

- `combat-firing`: add the requirement that an attack order cancels/supersedes
  a ground unit's in-progress player move, and relax the "Unit moves toward
  target" scenario's idle-only precondition to cover a superseded move.

## Impact

- `scripts/components/CombatComponent.gd` — `set_target()` stops ground movers;
  `_move_toward_target()` gains a `force` parameter for immediate re-approach.
- `scripts/components/MovementController.gd` — unchanged (uses existing
  `stop()` public API).
- New unit tests mirroring `test_jumpjet_attack_interrupts_airborne_move` for
  ground units: in-range stop-and-fire, and out-of-range path supersede.
- No scene/`.tscn` changes; `stop()` already no-ops for idle units so
  stationary attackers and defense structures are unaffected.
