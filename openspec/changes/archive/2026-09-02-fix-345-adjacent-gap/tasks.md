## 1. Regression tests (must fail before the fix)

- [x] 1.1 Add `test_adjacent_1_allows_one_cell_gap` to `test/unit/test_building_manager.gd`: adjacent=1, friendly registry entry with cells `[(3,3)]` + StatsComponent (local player), 2x2 footprint origin `(5,3)` (min Chebyshev distance 2 = 1-cell gap) → accepted. Verify it FAILS on un-patched code.
- [x] 1.2 Add `test_adjacent_2_allows_two_cell_gap`: adjacent=2, same neighbor, origin `(6,3)` (distance 3 = 2-cell gap) → accepted. Verify it FAILS on un-patched code.
- [x] 1.3 Add `test_adjacent_2_rejects_three_cell_gap`: adjacent=2, same neighbor, origin `(7,3)` (distance 4 = 3-cell gap) → rejected (boundary guard).
- [x] 1.4 Run `redot --headless -s test/run_tests.gd`; confirm existing 4 adjacency tests pass and the two new "accepted" cases fail for the intended reason.

## 2. Fix

- [x] 2.1 In `scripts/buildings/BuildingManager.gd` `_is_adjacency_satisfied`, change the acceptance condition from `<= required` to `<= required + 1`; reword the doc comment (L122-123) to gap semantics ("at most `adjacent` empty cells between footprints, Chebyshev distance `adjacent + 1`; `adjacent <= 0` = no requirement").
- [x] 2.2 Reword the `EntityData.adjacent` doc comment (scripts/data/EntityData.gd:257) to gap semantics.

## 3. Verify

- [x] 3.1 Run full suite `redot --headless -s test/run_tests.gd` — all pass, including the previously failing 1.1/1.2.
- [x] 3.2 Lint + format: `gdlint` and `gdformat --check` on touched files; grep for introduced tabs in multi-line strings.

## 4. Docs

- [x] 4.1 Add `adjacent` entry to `GLOSSARY.md`: max empty-cell gap allowed between a new structure's footprint and existing friendly footprints; `<= 0` = no requirement (diverges from TS must-touch/negative semantics).
