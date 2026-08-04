## Context

The test suite runs via `redot --headless -s test/run_tests.gd` (CI: `.github/workflows/test.yml`). The runner iterates `test_*` methods per file, reading per-file `_test_passed`/`_test_failed` counter deltas. Two assertion idioms coexist: ~28 `TestHelper`-based files (bare `    PASS` print, `_errors` collected but never surfaced, `TestHelper.reset()` called at the end of each test) and ~30 manually-written files (bespoke `    PASS: <msg>`/`    FAIL: <detail>` prints with hand-rolled counter blocks). Output has no test names, no timing, no suite rollups, and is polluted by `SelectionManager._ready` (`print("✅ ...")`) and `TerrainRenderer` per-cell `[TerrainRenderer]` debug prints.

Constraint: the runner must stay minimal (project philosophy: no framework, pure GDScript, no new dependencies). CI is GitHub Actions.

## Goals / Non-Goals

**Goals:**
- Single reporting path: tests report through `TestHelper`; the runner owns all output.
- Attributable, timed, rollup'd human-readable console output.
- Optional TAP 14 machine-readable stream.
- CI-native failure surfacing (annotations + step summary) with zero shell parsing.
- Clean test log (game-code debug prints silenced by default).

**Non-Goals:**
- Not adopting GUT/GdUnit or any third-party framework.
- Not fixing the latent `BoundsSystem` `!is_inside_tree()` error surfaced by `test_map_editor_e2e.gd:223` (separate issue).
- Not filtering engine-owned stderr teardown messages (RID leaks) — the standardized log is stdout.
- Not restructuring test files beyond the mechanical migration.

## Decisions

**D1. Runner drives the format; tests only count.**
The runner already has the hook (`get_script_method_list()`, counter deltas per method). It gains per-test timing (`Time.get_ticks_usec()`) and renders all output. Rationale: single place to change formatting; test files stay dumb. Alternative (per-file formatting) rejected — 58 duplicated renderers.
New contract: runner calls `TestHelper.reset()` before each test, reads `TestHelper._passed`/`_failed`/`_errors` after. File-level `_test_passed`/`_test_failed` vars and the end-of-test `+= TestHelper._passed; TestHelper.reset()` idiom are deleted across all test files.

**D2. One TAP point = one `test_*` method; suites = TAP 14 subtests.**
638 test methods → 638 test points, not 2911 assertion points. Keeps output digestible and maps 1:1 to the runner's per-method accounting. Suites are emitted as 4-space-indented subtests with correlated test points (spec v14 formalizes this). Failure detail rides as YAML diagnostics from `TestHelper._errors`. Alternative (flat points with `suite::test` prefixes) rejected — subtests are the idiomatic TAP nesting and barely more code.

**D3. Console and TAP are two renderers over one result stream.**
The runner collects a per-test record (suite, name, passed, failed, errors, duration_usec), then renders either console (default) or TAP (`-- --tap`). Flag read via `OS.get_cmdline_user_args()` (`redot --headless -s test/run_tests.gd -- --tap`). Keeps both formats honest to the same data.

**D4. CI mode lives in the runner.**
When `OS.get_environment("GITHUB_ACTIONS") == "true"`, the runner additionally emits `::error file=test/unit/<suite>.gd::<test>` per failure and appends a markdown table to `GITHUB_STEP_SUMMARY`. Rationale: no bash/awk parsing in `test.yml`, format changes stay in one file. Alternative (jq/awk extraction in the workflow) rejected — fragile and duplicated.

**D5. Game-code debug prints gated behind `OS.is_stdout_verbose()`.**
`SelectionManager.gd:16` and `TerrainRenderer.gd:29,100,185` prints wrap in `if OS.is_stdout_verbose():`. Zero new plumbing; `--verbose` restores them. Alternative (new GlobalRules flag / env var) rejected — more surface area for a debug-only concern.

**D6. `TestHelper.fail(msg)` for unconditional failures.**
Guard-rail patterns like `if _bm == null: ...` become `TestHelper.fail("BuildingManager not injected")` + `return`. `assert_eq`/`assert_true` unchanged; both silent on success, appending to `_errors` on failure.

## Risks / Trade-offs

- **Wide mechanical migration** (~30 files, ~480 methods) → chunk by directory, land runner rework first (backward compatible: still read old counters), migrate files suite-by-suite; CI stays green throughout.
- **Count regression** during migration (a converted test must produce identical pass/fail counts) → verification step runs before/after migration: 2911 asserts, 0 failures must match.
- **Ordering of failure detail**: `TestHelper` no longer prints during the test (previously FAIL printed inline). Detail appears in the end-of-run failure list instead of inline at failure time. → Acceptable; the console marks the failing test in place and defers detail to the summary, pytest-style.
- **TAP escaping**: `#` and `\` in descriptions (from failure messages) could break directive parsing → escape `\` and `#` per TAP 14 escaping rules when emitting test point descriptions.
- **Old files break the new runner contract if migration lags** → runner stays dual-source (reads both file counters and TestHelper statics, summing) until all files are migrated, then cuts over.

## Migration Plan

1. Phase 1 (backward compatible): runner renders names/timing/rollups/summary; `TestHelper` adds `fail()`, drops success prints; CI mode + noise gating; runner sums file counters AND TestHelper statics so all 58 files pass unchanged.
2. Phase 2: migrate manual files to `TestHelper`; delete counter vars + sync/reset lines; when the last file is migrated, runner cuts over to TestHelper-only counters.
3. Phase 3: TAP 14 renderer behind `-- --tap`.
Rollback: revert the change; no schema or scene changes involved.

## Open Questions

- None blocking. Per-file assertion-count semantics after migration: a compound manual check (`if a and b and c:`) becomes one `assert_true(a and b and c, "...")` (1 assertion) rather than split asserts, keeping counts stable — confirmed as the migration rule.
