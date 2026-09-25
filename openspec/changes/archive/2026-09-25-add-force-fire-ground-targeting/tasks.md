## 1. Ground engagement in CombatComponent

- [x] 1.1Add `_target_pos: Vector3` as the engagement source of truth and a `set_ground_target(pos: Vector3, hold_ground: bool = false)` entry point that shares a private `_begin_engagement()` with `set_target()` (stop current move, reset channel runtime, connect MC signal, approach when not hold-ground)
- [x] 1.2Re-key `_effective_target_pos()` to return the foundation-nearest point when `_target` is set and `_target_pos` otherwise, so range, body facing and turret slew follow it unchanged
- [x] 1.3Re-key `_horizontal_distance()`, the `_physics_process` guard, the turret-slew guard, the chase cell (`_chase_leg_enemy_cell`) and the stale-leg check off `_attack_active` / `_target_pos`; clear on invalid target **only** when `_target != null` so a position never self-clears
- [x] 1.4Add `is_engaged() -> bool` reporting true for entity **and** ground engagements; keep `get_target()` returning the entity or null
- [x] 1.5Verify `_connect_health_signal()` and `weapon_fired` tolerate a null target (no `HealthComponent` to connect, `target` emitted as null)
- [x] 1.6Unit tests (`test/unit/test_combat_component.gd`): ground engagement fires in range, repeats across cooldowns without re-issue, survives many idle ticks with no order, `is_engaged()` true while `get_target()` is null, approaches when out of range

## 2. Force-fire order generation

- [x] 2.1`CombatComponent.get_order_for_target()`: when `MOD_FORCE_ATTACK` is held and `weapons` is non-empty, return an ATTACK `OrderResult` for a null target and for an ally/own/neutral entity; without the modifier keep the hostile-only path byte-identical
- [x] 2.2`UnitOrderGenerator.get_orders()`: for `target == null` **and** `MOD_FORCE_ATTACK` held, run `OrderResolver.resolve_all()` and emit the highest-priority result; leave the existing undeploy/MOVE branch untouched when the modifier is absent
- [x] 2.3`UnitOrderGenerator.get_cursor()`: mirror 2.2 by resolving under the modifier so the cursor reads `result.cursor`
- [x] 2.4Unit tests (`test/unit/test_order_system.gd` / generator tests): Ctrl on empty ground → ATTACK order + ATTACK cursor; no Ctrl → MOVE; unarmed selection → MOVE; ally/neutral → ATTACK only under Ctrl; hostile without Ctrl unchanged; deployed+armed selection under Ctrl wins the undeploy tie (30 > 5)

## 3. Shroud gate for ground force-fire

- [x] 3.1In `OrderSystem`, add a ground gate beside `_fog_filter_target()` that strips `MOD_FORCE_ATTACK` when `target == null`, `ShroudSystem.is_shroud_enabled()` and `not ShroudSystem.is_explored(local_id, world_to_cell(bounds_pos))`; call it from both `get_cursor()` and `get_orders()` after the bounds gate
- [x] 3.2Leave `_fog_filter_target()`'s entity clause on visibility untouched
- [x] 3.3Unit tests: unexplored cell + Ctrl → move; explored-but-fogged cell + Ctrl → attack; gate applies with `fog_of_war` false but shroud on; entity fog scenarios from the existing suite still green

## 4. Shot resolution — occupant and overlay passes

- [x] 4.1Add `SpatialHash.resolve_cell_victim(cell: Vector2i, impact_pos: Vector3, shooter: Node3D) -> Node3D`: entries at any level with a `HealthComponent` whose `entity_type` is INFANTRY/VEHICLE/AIRCRAFT/BUILDING, nearest in 3D to `impact_pos`, excluding `shooter` only (allies and neutrals eligible)
- [x] 4.2`ProjectileController`: accept the ordered position in `setup()`, seed `_last_known_target_pos` from it (falling back to `target.global_position`), and split `_detonate_on()` into a `detonate(victim, position)` that accepts a null victim — `_compute_damage_for()` must not deref a null victim
- [x] 4.3`CombatComponent._apply_hitscan_damage()`: when there is no entity target, resolve the occupant at `_target_pos` and apply to it; with an entity target keep today's behaviour exactly (including the no-`HealthComponent` skip)
- [x] 4.4Add the overlay pass over the impact cell: bridge (`bridge_kind == LOW && !bridge_end` + `can_damage_walls`), ice (`breakable_surface` + `breakable_ice` feature + `can_damage_walls`), tiberium (`resource_category == "tiberium"` + `can_damage_tiberium`), skipping an overlay that is itself the shot's entity target
- [x] 4.5Tiberium lookup short-circuits on `SpatialHash.has_resource_cell(cell)` before scanning `get_nodes_in_group("resources")` for that cell
- [x] 4.6Play `warhead.impact_fx` and `warhead.sound_impact` at the impact position when neither pass applied damage (the victim path already plays them through `EntityFactory._on_entity_damaged`)
- [x] 4.7Unit/integration tests: enemy walks into the cell after the order → damaged; ally in the cell → damaged; shooter's own cell → shooter exempt; empty cell → no entity damage but impact FX plays; bridge/ice/tiberium positive and negative per warhead flag; ice with `breakable_ice` off → untouched; HIGH span and end piece → untouched; entity-targeted shot on a target without `HealthComponent` → skipped, no occupant substituted

## 5. Guard vision and engagement awareness

- [x] 5.1`GuardComponent._is_blocked()`: replace `_combat.get_target() != null` with `_combat.is_engaged()` so a ground engagement suppresses the scan
- [x] 5.2`_find_nearest_enemy()`: filter candidates to `ShroudSystem.is_visible(_stats.player_id, candidate_cell)` — owning player, never the local player
- [x] 5.3Do **not** add a visibility drop gate: an acquired engagement is retained when the target leaves visibility
- [x] 5.4Unit tests (`test/unit/test_guard_component.gd`): invisible in-range enemy not acquired; visible in-range enemy acquired; engaged target that leaves visibility is retained; computer-owned guard evaluated against its own player; guard does not steal a ground engagement

## 6. Stop command

- [x] 6.1`MouseHandler.apply_selection_hotkey(is_stop)`: when stopping, also call `clear_target()` on each selected entity's `CombatComponent`
- [x] 6.2Unit test: Stop during a fire mission clears the engagement, the unit goes idle, and `GuardComponent` may acquire on its next scan — closes the existing `stop-command` "Stop during combat" scenario

## 7. Regression coverage

- [x] 7.1Plain left-click on a bridge still issues a move onto the deck (no modifier → existing branch untouched)
- [x] 7.2Entity fog gate, bounds gate and out-of-bounds rejection scenarios still pass unchanged
- [x] 7.3Player move still cancels both entity and ground engagements via `movement_started`; combat-initiated chase moves still preserve them

## 8. Docs and verification

- [x] 8.1`GLOSSARY.md`: add `force fire`, `ground engagement` and `legal target` under **Orders & Selection**, and correct the existing `fog-gated targeting` row for the fog/shroud split
- [x] 8.2Run the full suite: `redot --headless -s test/run_tests.gd`
- [x] 8.3Lint and format: `gdlint scripts/**/*.gd test/**/*.gd`, `gdformat --check scripts/**/*.gd test/**/*.gd`, then `grep -P '\t' scripts/**/*.gd` for tab introduction
- [ ] 8.4 In-editor smoke: Ctrl+click on empty ground, on an ally, on a tiberium cell and on a LOW bridge; plain click on each as the control; Ctrl+S mid-fire; guard idle before and after
- [x] 8.5 `openspec validate add-force-fire-ground-targeting` still passes; reference #264 and #446 in the commit/PR (close #446)

## 9. Review fixes

- [x] 9.1 Detach the previous entity's `health_zero` before an entity → ground transition, so its death cannot `clear_target()` the player's ground engagement; regression test asserts the connection is gone and the engagement survives
- [x] 9.2 Reject `set_target(null)` with `push_error()` + `return` instead of engaging at the previous target's stale coordinates; strengthened `test_target_invalidated_no_crash` with an `_attack_active` assertion (a freed reference already compares equal to null, so the old assertion passed vacuously)
- [x] 9.3 Test guard visibility at the same footprint point the range test uses, so a structure with a visible in-range edge and a shrouded centre is still acquired
- [x] 9.4 Resolve a victimless ground blast — occupant *and* overlays — at one point (the ordered position) so an overshoot cannot split them across a cell boundary; pinned by `test_ground_blast_resolves_one_cell_for_both_passes`
- [x] 9.5 Fall back to the building-footprint registry in `resolve_cell_victim()` so an edge cell of a large structure still resolves its occupant (`register_building_cells()` now records the owning entity)
- [x] 9.6 Spec: describe the entity gate as shroud/fog *cover state* rather than `fog_of_war`, with scenarios for both-covers-off and fog-off-alone
- [x] 9.7 Spec: mixed Ctrl+ground selection — armed units fire, unarmed units hold
- [x] 9.8 Full suite green with no new script errors versus a clean-tree baseline run
