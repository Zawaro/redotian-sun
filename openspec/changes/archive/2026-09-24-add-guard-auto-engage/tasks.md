## 1. CombatComponent hold-ground

- [x] 1.1 Add `var _hold_ground: bool = false` and change signature to `set_target(entity: Node3D, hold_ground: bool = false)`; set `_hold_ground = hold_ground` inside `set_target`, reset false in `clear_target`
- [x] 1.2 In `_physics_process`, when `not _target_in_range()`: if `_hold_ground` then `clear_target(); return` (before `_aim_turrets` / `_move_toward_target`)
- [x] 1.3 Confirm all existing `set_target(...)` call sites still compile with the default (player `_attack`, tests)

## 2. GuardComponent core

- [x] 2.1 Create `scripts/components/GuardComponent.gd` (`class_name GuardComponent extends Node`) with throttle constant, per-instance phase offset, sibling resolution (CombatComponent, MovementController, PowerComponent, StatsComponent), and `_physics_process` gate: skip when editor/preview/map-editor, invalid parent, power offline, combat target active, or MC `is_moving()`
- [x] 2.2 Compute acquisition radius = longest weapon `attack_range * CellUtil.CELL_SIZE` (from sibling CombatComponent weapons or cached EntityData via configure); circular SpatialHash hood with `r_cells = max(1, ceil(range_world / CELL_SIZE))`; filter `player_id >= 0`, not self, `PlayerManager.is_enemy`; nearest by horizontal distance²
- [x] 2.3 On a found candidate, call `CombatComponent.set_target(nearest, true)`; no-op if CombatComponent missing
- [x] 2.4 Create `scripts/components/GuardComponent.gd.uid` (commit the `.uid`)

## 3. EntityFactory wiring

- [x] 3.1 Preload `GUARD_COMPONENT_SCRIPT` in `scripts/entities/EntityFactory.gd`
- [x] 3.2 Add `_add_guard_component(entity, data)` gated on `not data.weapons.is_empty()`, script-only attach (`Node.new()` + `set_script`), name `"GuardComponent"`, `owner = entity`
- [x] 3.3 Call `_add_guard_component` from `_add_components` immediately after `_add_combat_component`

## 4. Tests

- [x] 4.1 Create `test/unit/test_guard_component.gd` (+ `.uid`): helpers build armed entity (Combat + Guard + Stats + optional MC/Power) and place hostile/friendly at known positions
- [x] 4.2 Assert armed entity receives GuardComponent; unarmed does not
- [x] 4.3 Assert idle guard acquires enemy inside longest weapon range with hold-ground (Combat `get_target()` non-null)
- [x] 4.4 Assert enemy beyond weapon range (even within sight) is **not** acquired
- [x] 4.5 Assert friendly/neutral within range ignored; multiple in-range enemies → nearest
- [x] 4.6 Assert hold-ground: after acquire, force target out of range → target cleared, **no** `MovementController.set_target_position` chase (unit position unchanged)
- [x] 4.7 Assert player `set_target` (default) still chases when out of range (regression — may already live in `test_combat_component.gd`)
- [x] 4.8 Assert no scan while Combat target active; no acquisition while MC `is_moving()`; no acquisition while power offline
- [x] 4.9 Assert re-acquire after `clear_target()` when another enemy remains in weapon range; stays idle when none
- [x] 4.10 Assert throttle: multiple `_physics_process` calls within one interval produce at most one scan
- [x] 4.11 Run `redot --headless -s test/run_tests.gd` — full suite green

## 5. Docs and lint

- [x] 5.1 Update `GLOSSARY.md` Units & Combat: "acquisition range" (Mode A = weapon range; Mode B sight deferred #444) and "hold ground"; link `guard-auto-engage` / `combat-firing`
- [x] 5.2 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`
- [x] 5.3 Confirm no tabs: `grep -P '\t' scripts/**/*.gd test/**/*.gd`
