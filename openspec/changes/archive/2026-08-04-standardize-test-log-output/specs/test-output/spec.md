## ADDED Requirements

### Requirement: Runner-driven per-test reporting
The test runner SHALL report each `test_*` method with its name, PASS/FAIL status, assertion count, and elapsed time, grouped under its suite. The runner SHALL print a per-suite rollup and a final summary of totals. On any failure, the runner SHALL print a failure list at the end of the run with the suite, test name, and failure detail for each failed test.

#### Scenario: Passing test is attributed
- **WHEN** the runner executes a passing `test_*` method
- **THEN** output shows the test name with a PASS result, assertion count, and duration under its suite header

#### Scenario: Failing test surfaces detail
- **WHEN** a `test_*` method contains at least one failed assertion
- **THEN** the test is reported FAIL and the runner prints the assertion failure detail in the end-of-run failure list

#### Scenario: Suite rollup
- **WHEN** the runner finishes all `test_*` methods in a suite
- **THEN** output shows the suite name, its elapsed time, and its passed/failed totals

### Requirement: Single assertion API
Test files SHALL report results exclusively through `TestHelper` static assertions. The runner SHALL derive per-test pass/fail from `TestHelper` counters reset before each test. Direct `print()` of PASS/FAIL lines from test files SHALL be removed. TestHelper SHALL be silent on successful assertions and SHALL accumulate failure messages for the runner to display. TestHelper SHALL provide a `fail(msg)` assertion for unconditional failures.

#### Scenario: Assertion passes silently
- **WHEN** an `assert_eq` or `assert_true` succeeds
- **THEN** no output line is printed for the success and the pass counter increments

#### Scenario: Assertion failure recorded
- **WHEN** an `assert_eq` or `assert_true` fails
- **THEN** the failure message is recorded and the fail counter increments

#### Scenario: Guard-rail failure
- **WHEN** a test hits a precondition it cannot satisfy (e.g., missing injected autoload)
- **THEN** it calls `TestHelper.fail` with a message and returns, and the test is reported FAIL

#### Scenario: Legacy counters removed
- **WHEN** a test file is migrated to the new contract
- **THEN** its `_test_passed`/`_test_failed` variables and `TestHelper.reset()` sync lines are removed and the runner still counts the test correctly

### Requirement: Optional TAP 14 machine output
The runner SHALL support a `--tap` mode (enabled via `-- --tap` command-line user argument) that emits a Test Anything Protocol version 14 stream instead of the human-readable console format. The TAP stream SHALL include a version line, a plan, one test point per `test_*` method, suite subtests (4-space indented with correlated test points), and YAML diagnostics on failing test points. Human-readable console output SHALL remain the default when no flag is given.

#### Scenario: TAP stream structure
- **WHEN** the runner runs with the `--tap` flag
- **THEN** stdout begins with `TAP version 14` and contains a `1..N` plan and one `ok`/`not ok` line per test method

#### Scenario: Suite as subtest
- **WHEN** a suite contains test methods
- **THEN** its test points are emitted as a 4-space-indented subtest terminated by a correlated test point reflecting the suite result

#### Scenario: Failure diagnostics
- **WHEN** a test point fails
- **THEN** it is followed by a YAML diagnostic block containing the failure message

### Requirement: CI-native annotations
When the `GITHUB_ACTIONS` environment variable is set to `true`, the runner SHALL emit one `::error` workflow command per failed test and SHALL write a markdown summary table (suite, test, duration) to the `GITHUB_STEP_SUMMARY` environment file path. CI SHALL surface failures without shell-side parsing of test output.

#### Scenario: Failure annotation emitted
- **WHEN** a test fails in a GitHub Actions run
- **THEN** the runner emits an `::error` workflow command naming the failing suite and test

#### Scenario: Step summary written
- **WHEN** the run completes in a GitHub Actions run
- **THEN** the runner writes a markdown table of results to the `GITHUB_STEP_SUMMARY` file

#### Scenario: Local runs unaffected
- **WHEN** `GITHUB_ACTIONS` is not set
- **THEN** the runner emits no workflow commands and no step summary

### Requirement: Quiet game-code debug prints
The `SelectionManager` startup print and the `TerrainRenderer` per-cell debug logs SHALL be gated so they are only emitted when stdout verbose mode is active (`OS.is_stdout_verbose()`). They SHALL NOT pollute standard test runs.

#### Scenario: Default run is quiet
- **WHEN** the test suite runs without `--verbose`
- **THEN** no `[TerrainRenderer]` cell-change lines or SelectionManager startup line appear in the test log

#### Scenario: Verbose run restores debug output
- **WHEN** the engine runs with verbose stdout enabled
- **THEN** the debug prints are emitted as before
