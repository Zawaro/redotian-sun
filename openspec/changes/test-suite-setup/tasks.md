## 1. Test Runner

- [x] 1.1 Discover GUT incompatible with Redot 26.1 LTS (class_name registration fails)
- [x] 1.2 Create minimal test runner at `test/run_tests.gd` (extends SceneTree, no framework)
- [x] 1.3 Runner discovers test files, calls `test_*` methods, reads pass/fail counts

## 2. Test Infrastructure

- [x] 2.1 Create `test/unit/` directory
- [x] 2.2 Create `test/integration/` directory
- [x] 2.3 Create `test/.gutconfig.json` (kept for documentation, not used by runner)

## 3. Pathfinder Smoke Tests

- [x] 3.1 Create `test/unit/test_pathfinder.gd` extending Node
- [x] 3.2 Write `test_world_to_cell_origin` — assert `Vector3.ZERO` → `Vector2i(0, 0)`
- [x] 3.3 Write `test_world_to_cell_positive` — assert `Vector3(5, 0, 5)` → `Vector2i(2, 2)`
- [x] 3.4 Write `test_world_to_cell_negative` — assert `Vector3(-3, 0, -3)` → `Vector2i(-2, -2)`
- [x] 3.5 Write `test_cell_to_world_origin` — assert `Vector2i(0, 0)` → `Vector3(1, 0, 1)`
- [x] 3.6 Write `test_cell_to_world_roundtrip` — convert cell→world→cell, assert equality
- [x] 3.7 Write `test_cell_key_deterministic` — call `_cell_key` twice, assert same result

## 4. Verify

- [x] 4.1 Run `redot --headless -s test/run_tests.gd`
- [x] 4.2 Confirm all 6 tests pass ✓
- [x] 4.3 GUT fails on Redot — fell back to custom minimal runner

## 5. GitHub Actions CI

- [x] 5.1 Create `.github/workflows/` directory
- [x] 5.2 Create `.github/workflows/test.yml` workflow file
- [x] 5.3 Workflow triggers on push and pull_request
- [x] 5.4 Workflow installs Redot 26.1 LTS headless binary
- [x] 5.5 Workflow runs `redot --headless --import` to cache assets
- [x] 5.6 Workflow runs `redot --headless -s test/run_tests.gd`
- [x] 5.7 Workflow fails if test exit code is non-zero

## 6. OpenSpec Lint Check

- [x] 6.1 Add `check-openspec` job to `.github/workflows/test.yml`
- [x] 6.2 Check fails if `openspec/changes/` has directories other than `archive/`
- [x] 6.3 Error message lists offending directories
