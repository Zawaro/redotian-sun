## 1. GlobalRules foundations

- [x] 1.1 Add `get_veteran_sight_multiplier(level)` and `get_veteran_rof_multiplier(level)` to `GlobalRules`, reusing the existing `_veteran_multiplier(base, level)` helper.
- [x] 1.2 Add `@export var tech_level: int = 10` to `GlobalRules` with a doc comment naming it the session fallback.
- [x] 1.3 Extend `test/unit/test_global_rules_wiring.gd` with cases for both new multipliers, the `veteran_sight = 0.0` neutral case, and the cap clamp.

## 2. StatsComponent rank and identity state

- [x] 2.1 Add `experience: float = 0`, `trainable: bool`, `veterancy_changed(level)` signal, `add_kill_experience(victim_cost, victim_owner)`, and a private `_recompute_rank()` that derives `veteran_level` from `experience` at thresholds 1 and 2 and emits the signal on change.
- [x] 2.2 In `configure()`, set `trainable = data.trainable or entity_type != EntityType.BUILDING`.
- [x] 2.3 Add `is_unit()`, `is_infantry()`, `is_vehicle()`, `is_structure()`, `is_aircraft()` predicates.
- [x] 2.4 Add `test/unit/test_stats_component.gd` covering rank thresholds, cap clamp, trainable defaults per type, and each predicate (positive and negative).

## 3. Kill attribution plumbing

- [x] 3.1 Add `source: Node3D = null` to `HealthComponent.take_damage`, record `last_attacker`, and emit a new `killed(killer)` signal on death alongside the unchanged `health_zero`.
- [x] 3.2 Pass the attacker from `CombatComponent._apply_hitscan_damage` (self) and from `ProjectileController` (`_shooter`).
- [x] 3.3 Pass the attacker from `HitboxComponent.receive_damage_source` (the entered node) and from the `MovementController` crush path (the crusher).
- [x] 3.4 Extend `test/unit/test_health_component` coverage: fatal hit records source and emits `killed`; non-lethal emits nothing; killerless death still fires `health_zero`; existing listeners unaffected.

## 4. VeterancySystem autoload

- [x] 4.1 Create `scripts/core/VeterancySystem.gd` registering `HealthComponent` nodes via `get_tree().node_added`/`node_removed` (mirror `RadarSystem`) and crediting the killer on `killed`.
- [x] 4.2 Implement the credit path: resolve victim cost and killer cost from `EntityData.cost`, skip when killer invalid, not `trainable`, allied, `veteran_ratio <= 0`, or killer cost `<= 0`, then call the killer's `add_kill_experience`.
- [x] 4.3 Register `VeterancySystem` in `project.godot` after `GameContext` and alongside the other systems; keep `GameContext` first.
- [x] 4.4 Add `test/unit/test_veterancy_system.gd`: cheap-kills-expensive promotes, expensive-kills-cheap does not, cap clamps, allied excluded, untrainable excluded, zero-ratio guarded, only the fatal blow credited, dead-before-resolution guarded.

## 5. Promotion sources

- [x] 5.1 Apply `GlobalRules.initial_veteran` in `StatsComponent.configure` (create entity at elite without consulting the cap).
- [x] 5.2 Test that `initial_veteran = true` yields `veteran_level = 2` and default yields `0`, and that this path ignores `trainable`.

## 6. Veteran consumers

- [x] 6.1 `VisionComponent`: connect to `veterancy_changed`, re-register the revealer at `roundi(sight × get_veteran_sight_multiplier(level))`.
- [x] 6.2 `CombatComponent`: divide the per-group cooldown by `get_veteran_rof_multiplier(veteran_level)` when setting it after a shot.
- [x] 6.3 `SelectionOverlay`: draw a rank insignia for veteran/elite entities owned by the local or an allied player; hide enemy ranks.
- [x] 6.4 Add tests: fog revealer radius grows on promotion and is unchanged at `veteran_sight = 0.0`; weapon cooldown shortens for a veteran; selection overlay draws insignia for allied ranks and none for rookies/enemies.

## 7. Entity-type helper adoption

- [x] 7.1 Replace the inline `INFANTRY ∨ VEHICLE ∨ AIRCRAFT` comparisons in `TurretComponent`, `EntityPlacer`, `ArtComponent`, `EntityFactory` (and any other duplicate) with `is_unit()`.
- [x] 7.2 Re-run existing movement/placement/turret tests to confirm no behavior change.

## 8. Tech-level gating

- [x] 8.1 Add `tech_level: int = -1` (inherit sentinel) to `Mission`.
- [x] 8.2 Add `tech_level: int` to `PlayerData`.
- [x] 8.3 Resolve `mission.tech_level` → `GlobalRules.tech_level` onto each player in `PlayerManager.begin_mission` and `_init_defaults` (mirror `resolve_starting_credits`).
- [x] 8.4 Add the tech-level guard to `PrerequisiteSystem.can_build`: reject when `entity_data.tech_level == -1`, and reject when `entity_data.tech_level` exceeds the player's current level; keep the debug `no_prereqs` bypass.
- [x] 8.5 Migrate the two buildable MCVs (`games/ts/entities/vehicles/gdi_mcv.tres`, `nod_mcv.tres`) from `tech_level = -1` to `tech_level = 1`; update the `EntityData.tech_level` doc comment to "requires the house's tech level to be at least this value; -1 = never buildable".
- [x] 8.6 Add tests in `test/unit/test_global_rules_wiring.gd` / a new `test/unit/test_tech_level_gate.gd`: at-level passes, above-level fails, `-1` fails, mission override resolves, rules fallback resolves, debug override bypasses, and the same setup succeeds before the tech condition is introduced.

## 9. Docs and ticket

- [x] 9.1 Update `GLOSSARY.md`: add `experience`, `trainable`, `veteran_cap`, and a current-tech-level entry; correct the `tech_level` entry so `-1` reads as "never buildable" (original TS semantics).
- [x] 9.2 Run `gdlint` and `gdformat --check` on changed scripts and tests, then `redot --headless -s test/run_tests.gd`.
- [x] 9.3 Rewrite GitHub issue #37 to match this scope (close the armor/vision-API items as "implemented differently"; carry veterancy producer, tech gate and type helpers).
