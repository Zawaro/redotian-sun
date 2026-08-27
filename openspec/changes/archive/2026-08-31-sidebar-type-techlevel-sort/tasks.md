## 1. Sidebar sort keys

- [x] 1.1 Add `TYPE_RANK` (entity type → group rank mirroring `TAB_ENTITY_TYPES`) and `UNKNOWN_TYPE_RANK` consts to `Sidebar.gd`.
- [x] 1.2 Rewrite `_compare_build_items` to compare type rank → `tech_level` → display_name → id; update `sort_buildables` doc comment.

## 2. Data cleanup

- [x] 2.1 Remove the `sidebar_priority` export from `EntityData.gd`.
- [x] 2.2 Strip `sidebar_priority = N` lines from all entity `.tres` files.

## 3. Test coverage

- [x] 3.1 Pure sort tests: type group beats tech level; ascending tech level with -1 first; name/id tie-breaks; empty/single/no-mutation/shuffle-determinism regressions; unknown type sorts last.
- [x] 3.2 Data coverage: Vehicles tab lists every VEHICLE before every AIRCRAFT; tech_level non-decreasing within each type group per tab; every buildable has `tech_level >= -1`; every buildable's entity type maps to a sidebar tab.

## 4. Spec

- [x] 4.1 Add `sidebar-build-order` capability spec and archive the change.

## 5. Verify

- [x] 5.1 Run `redot --headless -s test/run_tests.gd` and confirm all pass.
- [x] 5.2 Run `gdlint` and `gdformat --check` on touched scripts, then grep for accidental tab insertion.
