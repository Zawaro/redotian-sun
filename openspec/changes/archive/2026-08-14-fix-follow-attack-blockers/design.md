## Context

GH #277: a follow-attacking unit walks into a building when its moving target jukes behind it. Investigation (see explore-mode notes) pinned the mechanism to `CombatComponent._move_toward_target` (scripts/components/CombatComponent.gd:213): each chase leg is computed obstacle-aware at plan time, but the `_physics_process` gate at line 220 (`if not force and mc.is_moving(): return`) freezes the leg until arrival. A moving enemy invalidates the leg geometry mid-flight, and the attacker walks the stale straight line through whatever was placed there.

The pathfinding stack is healthy and must stay untouched: `Pathfinder.find_path` / `try_greedy_step` route around the blocked set built by `MovementController._build_blocked_cells` (which includes building cells), verified by `test_pathfinder_routes_around_centered_building_cell`. The fix lives in how `CombatComponent` decides a leg is stale, plus a destination invariant and surrounding state-machine hardening.

Constraints: `#284` makes `MovementController._handle_moving_movement` (~43µs/unit/tick at 100 infantry) a measured hotspot — no per-frame pathfinding. Existing signals: `arrived`, `movement_started`, `pathfinding_failed`; `_combat_move` already distinguishes combat re-targets so `_on_movement_started` preserves the target. Fixes #195/#256 must not regress (attack order interrupts moves; in-range attackers fire instead of wandering).

## Goals / Non-Goals

**Goals:**
- Chasing attackers route around buildings and never enter a footprint.
- Re-plan cost scales with actual target motion, not frame rate (no per-frame A*).
- Stationary-target behavior and perf identical to today.
- WAIT-state deadlock and unreachable-target A* churn resolved as part of the same fix.

**Non-Goals:**
- No change to pathfinding algorithms or the hot `_handle_moving_movement` loop.
- No line-of-sight gating of weapon fire (attacks can still fire through empty space).
- No new locomotion modes; attack-move (#264) and guard AI (#261) are separate follow-ons that may reuse this pattern later.

## Decisions

**D1 — Leg invalidation via enemy cell crossing (not LOS, not distance).**
Record `_chase_leg_enemy_cell = CellUtil.world_to_cell(_target.global_position)` when a combat move is issued. In `_physics_process`, replace the unconditional `is_moving()` early-return with: a stale leg is one where the target's current cell differs from the recorded cell. On staleness (and throttle expiry), re-issue `_move_toward_target(force = true)`.
- Rationale: one hash-keyed cell compare per tick per attacker is negligible against the 43µs budget. Cell crossing is the discrete event that actually invalidates geometry — LOS re-checks and distance thresholds are noisier or more expensive. Stationary target → cell never changes → zero re-plans (preserves perf and #195/#256).
- Alternatives considered: per-step LOS tripwire (C5) — more precise but O(leg length) per step, too hot; distance threshold — jittery, no geometric meaning; building-generation snooping — wrong trigger, buildings rarely appear mid-chase.

**D2 — Throttle re-plans per attacker.**
Add `_last_chase_replan_time`; skip a re-plan if `now - last < CHASE_REPLAN_MIN_INTERVAL` (0.15s). A fleeing enemy crossing cells rapidly produces at most one re-plan per interval.
- Rationale: bounds N-attackers-chasing-one-fleeing-enemy to N re-plans per interval worst case, each a greedy-first walk (A* only on stall per #284's profile). Prevents pathological oscillation and synchronized storms.
- Alternative: per-frame caps / credit banking — over-engineering once the event is discrete.

**D3 — Passable destination invariant.**
In the ground (non-jumpjet) branch of `_move_toward_target`, after computing `stop_pos`, test its cell against the blocked set (`SpatialHash.instance.is_cell_blocked` / building cells). If blocked, relocate via `_find_nearest_free_cell` (existing spiral, radius 4) before calling `set_target_position`. The jumpjet branch already clamps overshoot onto the range circle; this gives the ground branch the same "destination is never inside a footprint" guarantee.
- Rationale: makes the acceptance criterion "never ends up inside a building footprint" true by construction even if the re-plan trigger ever fails. Also covers the enemy-hugs-a-wall case where the range-circle point lands inside the building.
- Risk: relocation can push the attacker slightly out of range or put the free cell behind the building; the per-leg re-plan (D1) re-aims each time and pathfinding routes around. Existing arrival/range logic handles the rest.

**D4 — WAIT is replan-eligible.**
Change the gate from `is_moving()` to a `can_replan()` check that is false only for real MOVING/ROTATING legs; `State.WAIT` (settled on an occupied final cell) is eligible. Re-plan only when the target is out of range — the in-range case keeps firing (existing behavior).
- Rationale: kills the WAIT deadlock where a chase settles onto an occupied cell and never re-plans even though the target left range.

**D5 — Retry backoff on pathfinding_failed.**
`_on_pathfinding_failed` sets `_chase_retry_after = now + CHASE_RETRY_BACKOFF` (e.g. 0.5s); `_physics_process` skips the approach attempt until the backoff lapses. While the target is in range, fire normally. Log once per target for observability.
- Rationale: an unreachable target (e.g. island) currently retries A* every frame — a latent mini-#279. Backoff converts it to a spaced retry; the attacker idles-and-fires instead of storming.
- Alternative: clear the target on failure — wrong, the enemy may become reachable.

**D6 — Combat re-targets stay non-internal; `_combat_move` already preserves the target.**
Combat re-plans do NOT pass `internal = true`. The existing `_combat_move` flag is set in `_move_toward_target` before each combat move and consumed synchronously by that move's `movement_started` (`_on_movement_started`), so re-plans already preserve `_target`. Making them internal would leave `_combat_move` stuck true (never consumed), which would break the player-move-clears-target path.
- Rationale: the flagged non-internal path is correct for both the initial approach and every re-plan; internal would add a stuck-flag hazard for zero benefit. Re-emitting `movement_started` on a chase re-plan is also desirable — `SelectComponent`'s move-target line tracks the fresh approach point.
- Alternative considered: internal re-targets (original D6) — rejected above.

## Risks / Trade-offs

- [Chase thrash when many attackers re-plan in lockstep] → D2 throttle bounds it; greedy-first cost per re-plan is low on open terrain (#284 profile).
- [Relocated destination pushes attacker out of firing range] → D1 re-aims each leg; range logic fires as the enemy closes.
- [Making WAIT replan-eligible fights the occupancy-settle nudge] → combat re-plan only supersedes it when the target is out of range (D4).
- [Backoff adds latency when an unreachable target becomes reachable] → keep backoff short (0.5s); acceptable for a niche case.
- [Behavioral regression of #195/#256] → stationary-target path is byte-for-byte the old gate; in-range fire logic untouched; covered by regression tests.

## Migration Plan

No schema, scene, or resource changes. The fix is additive GDScript in two components; existing packed scenes are unaffected. Rollback is reverting the two-file diff.

## Open Questions

- Exact throttle and backoff constants (0.25s / 0.5s) — tune in playtest; no spec impact.
- Whether the passable-destination clamp belongs in `CombatComponent` (querying SpatialHash directly) or as a small public helper on `MovementController` (reusing its blocked-set builder) — implementation detail for the apply phase.
