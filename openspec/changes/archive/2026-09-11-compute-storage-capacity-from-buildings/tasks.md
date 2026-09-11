## 1. Implement storage summation

- [x] 1.1 `scripts/economy/EconomyManager.gd`: replace the flat-constant body of `get_storage_capacity(player_id, category)` with a sum over `PrerequisiteSystem.get_player_buildings(player_id)`; for each `entity_id → count`, add `EntityFactory.get_entity_data(entity_id).storage_capacity.get(category, 0) * count`. Keep the signature `(player_id: int, category: String = DEFAULT_CATEGORY) -> int`.
- [x] 1.2 Remove the now-unused `TIBERIUM_CAPACITY` constant and the `ponytail:` comment that admitted the shortcut.
- [x] 1.3 Guard nulls: skip entity ids whose `EntityFactory.get_entity_data` returns null, and treat a missing/non-Dictionary `storage_capacity` entry as 0.

## 2. Core tests

- [x] 2.1 `test/unit/test_economy_manager.gd`: rewrite `test_storage_capacity_category`. Build synthetic `EntityData` (via `EntityData.new()` with `id` + `storage_capacity`) and register them with `PrerequisiteSystem.register_building(pid, data)` — no TS-specific ids. Assert: one building declaring `{"tiberium": 2000}` → 2000; two such buildings → 4000; category absent from all buildings → 0; a player with no registrations → 0.
- [x] 2.2 Add a building-loss case: after `PrerequisiteSystem.unregister_building(pid, data)`, `get_storage_capacity(pid, "tiberium")` returns 0. Clean up registrations at test end so suites stay independent.
- [x] 2.3 Confirm the change is a genuine regression test: the expanded `test_storage_capacity_category` must fail against the old flat-2000 implementation for the summation and empty-base cases.
- [x] 2.4 Run `redot --headless -s test/run_tests.gd` and ensure all suites pass.

## 3. Spec sync and verification

- [x] 3.1 Update the stale shortcut notes: `plans/1-3_economy_resources.md:19` and `scripts/data/EntityData.gd:165-167` no longer claim "no consumer yet" for `storage_capacity`.
- [x] 3.2 Run `openspec validate compute-storage-capacity-from-buildings` and fix any delta-format errors.
- [x] 3.3 Run `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd`; after any `gdformat`, grep for tab introduction in multi-line strings.

## 4. Review follow-ups

- [x] 4.1 `SelectComponent._build_storage_bar`: connect `PrerequisiteSystem.prerequisites_changed` and re-scale when the owner's capacity changes; `update_storage_bar` now zeroes the fill when capacity drops to 0.
- [x] 4.2 `test/unit/test_select_component.gd`: model production order (`add_child` → assert empty → register → assert re-scale) and add a capacity-change re-scale case; this fails if the bar has no capacity-change listener.
- [x] 4.3 `PrerequisiteSystem`: connect `GameContext.game_changed` and clear `_player_buildings` (emitting `prerequisites_changed` per affected player) so a runtime game switch cannot leave stale owned ids.

