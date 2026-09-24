## Why

Units only fight when a player left-clicks an attack order (`CombatComponent.set_target` from `OrderResult`). Idle units — including the entire Nod garrison in GDI Mission 01 — stand still while being shot. There is no acquisition scan and no return-to-idle after a kill. This blocks the mission's "Nod base defends itself" requirement and is the prerequisite for attack-move (#264) and later skirmish GameAI.

Guard is intentionally split into two modes:

| Mode | Behavior | Where |
|------|----------|--------|
| **A — stand-and-shoot** (default idle) | Acquire only enemies already in weapon range; fire; **do not chase** | **This change** |
| **B — Guard command** | Acquire in sight, chase within leash, return to post | #444 + #445 (G key / stance) |

## What Changes

- Add `GuardComponent`: a sibling of `CombatComponent` that periodically scans for hostiles already within **weapon range** while the unit is idle, picks the nearest, and calls `CombatComponent.set_target(..., hold_ground = true)`.
- Add a **hold-ground** engagement flag on `CombatComponent.set_target`: when the target later leaves weapon range, clear the target instead of issuing a chase move. Player-ordered attacks keep the existing chase behavior (`hold_ground = false`).
- Attach `GuardComponent` from `EntityFactory` under the same condition as `CombatComponent` (`weapons` non-empty).
- Acquisition range = longest `WeaponData.attack_range × CellUtil.CELL_SIZE` (horizontal); no new schema field.
- Scan is throttled and phase-staggered per unit; SpatialHash circular cell hood, not `all_entries()`.
- Power-offline entities do not acquire (mirrors CombatComponent's offline freeze).
- Fog/shroud is **not** consulted (deferred: #446). Sight-based acquire, leash, and return-to-post are **not** in this change (#444, #445).

## Capabilities

### New Capabilities

- `guard-auto-engage`: GuardComponent idle stand-and-shoot — weapon-range-only acquisition, hold-ground fire, no chase; scan throttling; power and player-order interaction; post-kill re-scan.

### Modified Capabilities

- `entity-factory`: component addition rules gain `GuardComponent` when `weapons.size() > 0`.
- `combat-firing`: `set_target` gains a hold-ground flag; out-of-range with hold-ground clears the target instead of chasing. Player orders unchanged.

## Impact

- **New**: `scripts/components/GuardComponent.gd` (+ `.uid`)
- **Modified**: `scripts/entities/EntityFactory.gd` — preload + `_add_guard_component`
- **Modified**: `scripts/components/CombatComponent.gd` — `set_target(entity, hold_ground := false)` + out-of-range hold-ground branch in `_physics_process`
- **Tests**: new `test/unit/test_guard_component.gd` (+ `.uid`); hold-ground cases in combat tests; existing chase/player-order tests unchanged
- **Data**: none
- **Depends on**: #261 (Mode A slice of that issue)
- **Defers**: #441 retreat, #442 threat scoring, #443 squads, **#444 Mode B (leash/return + optional patrol)**, **#445 Mode B activation (G key / stance column)**, #446 fog-gated AI vision
