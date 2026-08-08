## Context

`CombatComponent.set_target()` (`scripts/components/CombatComponent.gd:85`) is
the entry point for every attack order. It sets `_target`, flips `_attack_active`,
connects MovementController + HealthComponent signals, and calls
`mc.cancel_move_retain_vertical()`. That method (`MovementController.gd:260`)
early-returns unless the unit is an airborne jumpjet, so **ground units never
halt**. Every physics tick `CombatComponent._physics_process` then either fires
unconditionally when in range (firing while walking — #195) or calls
`_move_toward_target()`, which is guarded by `not mc.is_moving()` and therefore
skips a moving unit — so the stale move is never superseded (#256).

The reverse direction already works: a player move emits `movement_started`,
and `_on_movement_started` clears the attack target unless `_combat_move` is
set. The fix mirrors that mechanism.

## Goals / Non-Goals

**Goals:**
- An attack order instantly cancels a ground unit's in-progress player move.
- In-range attack: unit stops and fires stationary (no firing on the move).
- Out-of-range attack: old path dropped and a fresh approach path issued in the
  same frame, so the unit turns toward the target immediately.
- Preserve: player move cancels attack; airborne jumpjet attack keeps its air
  zone; idle units unaffected.

**Non-Goals:**
- No order-queueing or multi-command buffering — orders remain immediate.
- No change to `MovementController.stop()` semantics or the stop command (Ctrl+S).
- No behavior change for units without a MovementController (defense structures).

## Decisions

### D1: Branch on airborne in `set_target()`, use existing public `stop()`
Replace the unconditional `mc.cancel_move_retain_vertical()` call with:
`mc.cancel_move_retain_vertical()` when `mc.is_airborne_jumpjet()`, else
`mc.stop()`. `stop()` no-ops on `State.IDLE`, so stationary attackers and
non-combat entities are untouched.
- Alternative rejected: calling `_finish_stop()` directly for a dead halt —
  it is private, skips the tidy sub-slot settle, and would leave units standing
  off-slot.

### D2: Force immediate re-approach when out of range
`_move_toward_target()` gains a `force: bool = false` parameter; the guard
becomes `if mc and (force or not mc.is_moving())`. After the stop in
`set_target()`, when the horizontal distance to the target exceeds weapon range,
call `_move_toward_target(true)`. `set_target_position()` overwrites `_waypoints`
and `_state` regardless of prior state, so the residual stop-glide (≤1 cell) is
replaced by the approach path before it executes.
- The forced approach sets `_combat_move = true` before
  `set_target_position()`, so the emitted `movement_started` is swallowed by
  `_on_movement_started` and the attack target is preserved — the same
  mechanism existing combat approaches rely on.
- Alternative rejected: waiting for the stop-glide to finish then re-approaching
  — leaves a ~0.25s detour in the old direction before the unit turns, which
  reads as the original bug.
- Alternative rejected: re-issuing the approach every frame — pathfinding and
  cell-reservation spam; the per-order one-shot in `set_target()` avoids it.

### D3: Reuse the existing range check pattern
The in-range/out-of-range decision in `set_target()` mirrors
`_physics_process`'s own horizontal-distance check
(`Vector3(to.x, 0, to.z).length() <= weapon.attack_range * CELL_SIZE`), so the
two stay consistent as weapon data evolves.

## Risks / Trade-offs

- **Fire during the ≤1-cell stop settle (in-range)** → The settle matches the
  existing Ctrl+S stop behavior; the unit stops the order immediately and the
  fire-on-the-move window shrinks from "entire old path" to a sub-second glide.
  Acceptable per #195's expected behavior. If a dead halt is ever required,
  revisit with a dedicated stop API.
- **Transient sub-slot reservation from `stop()` before the forced approach** →
  `set_target_position()` re-books the destination sub-slot and overwrites
  `_sub_slot_position`/`_has_sub_slot`; reservations release on arrival. No
  correctness impact.
- **Double `movement_started` semantics** → Only the forced approach emits it;
  `stop()` emits no signals, so nothing clears the attack target during the
  stop. Verified against `test_player_move_clears_attack_target` and
  `test_combat_move_preserves_attack_target`.
