## Why

The test suite's log output is unstandardized: ~2,700 bare `PASS` lines with no test names, no timing, no per-suite rollups, two competing assertion idioms across 58 files, and interleaved game-code debug prints. Failures are buried, CI has no digestible result, and nothing is machine-readable.

## What Changes

- **Runner-driven reporting**: `test/run_tests.gd` prints each `test_*` method with name, pass/fail, assertion count, and duration; prints per-suite rollups, a final summary, and a failure list.
- **Single assertion idiom**: migrate ~30 manually-written test files to `TestHelper`; remove per-file `_test_passed`/`_test_failed` vars and the sync/reset idiom. Tests stop printing directly; `TestHelper` is silent on success and collects failure details.
- **TAP 14 machine output**: optional `-- --tap` flag emits the Test Anything Protocol v14 stream (plan, suite subtests, YAML failure diagnostics).
- **CI-native annotations**: when `GITHUB_ACTIONS=true`, the runner emits `::error` per failed test and a `GITHUB_STEP_SUMMARY` markdown table.
- **Quiet game-code prints**: gate `SelectionManager` startup print and `TerrainRenderer` per-cell debug logs behind `OS.is_stdout_verbose()` so they stop polluting the test log.
- **TestHelper additions**: new `fail(msg)` assertion; `_errors` surfaced to the runner (currently collected but never printed).

## Capabilities

### New Capabilities
- `test-output`: standardized, attributable test log output — single assertion API, runner-driven per-test/suite reporting, optional TAP 14 machine format, and CI-native failure annotations.

### Modified Capabilities
<!-- No existing spec covers the test runner; nothing changes. -->

## Impact

- `test/run_tests.gd` — rewritten reporting/renderers.
- `test/test_helper.gd` — silent-on-success, new `fail()`, error surfacing.
- ~30 `test/unit/*.gd` and `test/integration/*.gd` files — mechanical migration to `TestHelper`, removal of counter vars and sync lines.
- `scripts/core/SelectionManager.gd` — gate startup print.
- `scripts/core/TerrainRenderer.gd` — gate debug logs.
- `.github/workflows/test.yml` — unchanged shell; CI mode is detected by the runner via the `GITHUB_ACTIONS` env var.
- Pure GDScript; no new dependencies, no scene changes.
