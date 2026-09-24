## Context

`CombatComponent` implements the engagement loop once a target is set: chase via `_move_toward_target`, per-channel fire, clear-on-death, clear-on-player-move. `_move_toward_target` already returns early when the target is within weapon range (CombatComponent.gd ~545), so `set_target` on an in-range enemy does not issue a move. The chase still starts on the **next** `_physics_process` tick if the target leaves range.

Guard is a two-mode design:

- **Mode A (this change)** — default idle: stand and shoot only what is already in weapon range; never chase.
- **Mode B (#444 + #445)** — explicit Guard (G key / stance): acquire at sight, chase under a leash, return to post.

`plans/3-2_combat_ai.md` still describes the full state machine; this change is only the Mode A handoff.

Existing anchors:

- `SpatialHash.get_entries(cell)` — entries with `player_id`, `stats`, `node`
- `PlayerManager.is_enemy(a, b)`
- `StatsComponent.player_id` / `StatsComponent.sight`
- `MovementController.State.IDLE` / `is_moving()`
- `PowerComponent.is_online`
- Hood-scan patterns in CombatComponent / TransportComponent / DeployComponent

## Goals / Non-Goals

**Goals:**

- Idle armed entities auto-acquire the nearest enemy **already within longest weapon range** and fire in place.
- Guard-initiated engagements **never chase**: if the target leaves weapon range, the engagement clears and the unit stays put.
- Player-ordered attacks keep existing chase behavior (unchanged).
- After clear (kill, out-of-range hold-ground, player move), re-scan on the next throttle tick.
- No acquisition during player moves, while a target is active, or while power is offline.
- Throttled, phase-staggered SpatialHash hood scans.

**Non-Goals:**

- Sight-based acquisition, G key, stance column, leash, return-to-post, patrol → #444 / #445 (Mode B).
- Retreat/flee (#441), threat scoring (#442), squads (#443), fog-gated AI vision (#446).
- New EntityData / GlobalRules fields.
- Changing chase, facing, cooldown, or damage behavior for player orders.

## Decisions

### D1 — Separate `GuardComponent`, not a branch inside CombatComponent

**Choice**: New `scripts/components/GuardComponent.gd` attached by EntityFactory alongside CombatComponent.

**Alternatives**: fold into CombatComponent (already ~720 lines; mixes policy with mechanism); central CombatAI autoload (overkill for MVP).

**Rationale**: Policy (when/whom) vs mechanism (how to chase/fire). Mode B (#444/#445) and fog (#446) hang off Guard.

### D2 — Mode A only: acquisition range = longest weapon range, hold ground

**Choice**:

1. Scan radius = `max(channel.weapon.attack_range) * CellUtil.CELL_SIZE` (same definition as `CombatComponent._target_in_range` / `_longest_range_weapon`).
2. Only candidates with horizontal distance ≤ that radius are acquirable.
3. Engage with `set_target(enemy, hold_ground = true)`.
4. When hold-ground and target leaves weapon range → `clear_target()` (no chase).

**Alternatives**:

| Option | Why not |
|--------|---------|
| Sight radius + free chase | That is Mode B; belongs in #444/#445. |
| Sight radius, fire only if in weapon range, ignore otherwise | Would scan a large hood only to discard most candidates; weapon-range hood is smaller and matches "only attacks enemies in range". |
| Guard clears target every frame when out of range (no Combat change) | `CombatComponent._physics_process` is registered before Guard (factory order) and would issue a chase move on the same frame before Guard can clear — race. |

**Hold-ground lives on Combat** so the out-of-range decision runs inside the existing `_physics_process` before `_move_toward_target`:

```
if not _target_in_range():
    if _hold_ground:
        clear_target()
        return
    _aim_turrets(delta)
    _move_toward_target()
    return
```

`set_target(entity, hold_ground := false)` — default false preserves every existing call site (player OrderResult, tests).

### D3 — Two modes, one component

```
Mode A (default, this change)          Mode B (future: #444 + #445)
─────────────────────────────          ─────────────────────────────
idle → weapon-range scan               G / stance=Guard → sight scan
set_target(..., hold_ground=true)      set_target(..., hold_ground=false)
fire in place                          chase under leash
leave range → clear_target             leave leash → return to post
```

Mode B reuses the same GuardComponent: different radius source, hold_ground false, post memory + leash from #444, activation from #445. No second component.

### D4 — Scan only when idle *and* not already engaging

Guard skips a tick when any of:

1. `CombatComponent.get_target() != null` — engagement owned by Combat (hold-ground will clear if out of range).
2. `MovementController` exists and `is_moving()` — player order or (Mode B) chase in progress.
3. Power offline (`PowerComponent` present and not `is_online`).
4. Invalid, preview, or map editor.

After `clear_target()`, the next throttled tick re-enters the scan — return-to-idle → re-acquire.

**Edge**: Player stop clears attack → Guard may re-acquire if enemy still in weapon range. Correct for default stand-and-shoot; Hold Fire is #445.

### D5 — Nearest-enemy selection

No threat scoring (#442). Deterministic cell walk (dx, dz ascending); keep closest horizontal distance²; ties → first found.

Hostility: `PlayerManager.is_enemy(self, other)` and both ids ≥ 0. Skip self and invalid nodes.

### D6 — Throttle + phase stagger

- Interval: fixed constant on the component (~0.3 s), not GlobalRules for MVP.
- Phase offset: derived from `get_instance_id()` so same-frame spawns do not scan together.
- Hood: square, `r_cells = ceil(range_world / CellUtil.CELL_SIZE)`, full `±r_cells` index square (no `dx²+dz²` cutoff — that skips diagonal in-range cells). Exact world `dist_sq` filters candidates. Weapon ranges 1–10.5 cells → small hoods.

### D7 — No fog/shroud check

Raw SpatialHash proximity. Per-player shroud gating is #446.

### D8 — Attach rule mirrors CombatComponent

```gdscript
if not data.weapons.is_empty():
    _add_guard_component(entity, data)
```

Script-only attach (`Node.new()` + `set_script`), same pattern as PowerComponent / HarvestComponent.

## Risks / Trade-offs

- [**Same-frame chase race if hold-ground only in Guard**] → Mitigation: D2 puts the branch in CombatComponent before `_move_toward_target`.
- [**Default `hold_ground=false` regresses player chase**] → Mitigation: default parameter; existing combat tests must stay green without edits.
- [**Buildings with short weapons**] Mode A still works (fire in place). Sight-based tower aggro is Mode B / #245.
- [**Scan stampede**] → instance-id phase offset (D6).
- [**Harvesters with weapons**] May fire at in-range enemies while idle; will not chase. Acceptable; Hold Fire is #445.
- [**Target skirts range boundary**] clear → re-acquire loop every throttle tick. Bounded by D6 interval; no pathfinding churn.

## Migration Plan

Additive API (`set_target` optional param). No schema/save changes. Rollback = remove Guard attach + hold-ground branch.

## Open Questions

- Interval 0.3 s vs logic-frame multiples — tune after playtest.
- Whether Mode A should also drop target on player "Stop" differently from today — out of scope; stop-command already clears.
