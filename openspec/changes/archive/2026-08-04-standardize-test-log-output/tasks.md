## 1. TestHelper rework

- [x] 1.1 Add `static func fail(msg: String) -> void` that increments `_failed` and appends to `_errors`
- [x] 1.2 Make `assert_eq`/`assert_true` silent on success (remove `print("    PASS")`)
- [x] 1.3 Verify `_errors` accumulation and `reset()` still work

## 2. Runner reporting (backward compatible)

- [x] 2.1 Collect per-test records: suite, method name, `Time.get_ticks_usec()` delta, passed/failed deltas (sum of file-level counters AND TestHelper statics so all 58 files pass unchanged)
- [x] 2.2 Render console output: `--- <suite> (Xs) ---` header, per-test name + result + assert count + ms, per-suite rollup
- [x] 2.3 Render final summary (`passed/failed · asserts · total time`) and end-of-run failure list dumping `TestHelper._errors` detail
- [x] 2.4 CI mode: when `GITHUB_ACTIONS == "true"`, emit `::error` per failed test and append a markdown results table to `GITHUB_STEP_SUMMARY`

## 3. Quiet game-code debug prints

- [x] 3.1 Gate `SelectionManager.gd:16` startup print behind `OS.is_stdout_verbose()`
- [x] 3.2 Gate `TerrainRenderer.gd:29,100,185` debug prints behind `OS.is_stdout_verbose()`
- [x] 3.3 Confirm a default headless run emits no `[TerrainRenderer]`/startup lines; `--verbose` run restores them

## 4. Migrate test files to TestHelper

- [x] 4.1 Migrate `test/integration/*` files (5 files): convert PASS/FAIL blocks to `TestHelper.assert_true(cond, msg)`, guard-rails to `TestHelper.fail(msg)` + return, delete `_test_passed`/`_test_failed` vars and sync/reset lines
- [x] 4.2 Migrate first half of manual `test/unit/*` files (batch A, ~15 files)
- [x] 4.3 Migrate second half of manual `test/unit/*` files (batch B, remaining ~15 files)
- [x] 4.4 Delete `_test_passed`/`_test_failed` vars and sync/reset lines from the ~28 already-TestHelper files
- [x] 4.5 Cut runner over to TestHelper-only counters once no file declares `_test_passed`/`_test_failed`

## 5. TAP 14 mode

- [x] 5.1 Detect `--tap` in `OS.get_cmdline_user_args()`
- [x] 5.2 Emit `TAP version 14` + `1..N` plan
- [x] 5.3 Emit suite subtests (4-space indented, correlated test points)
- [x] 5.4 Emit YAML diagnostics on failing test points (escape `\` and `#` per TAP 14)
- [x] 5.5 Keep console renderer as the default

## 6. Verification

- [x] 6.1 Before/after migration: `redot --headless -s test/run_tests.gd` shows 2917 asserts, 0 failures. (Baseline was 2911; `test_economy_manager.gd` pre-existing bug undercounted by 6 — its pass paths printed `PASS` but never incremented `_test_passed`. Migration correctly counts every logical assertion.)
- [x] 6.2 `redot --headless -s test/run_tests.gd -- --tap` produces a well-formed TAP 14 stream
- [x] 6.3 `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check` pass; no tabs introduced
- [x] 6.4 Simulated CI run (`GITHUB_ACTIONS=true` + `GITHUB_STEP_SUMMARY`) emits `::error` lines and a markdown table
