# Task Completion

Run from repo root before declaring a coding task done:

1. `gdlint scripts/**/*.gd test/**/*.gd`
2. `gdformat --check scripts/**/*.gd test/**/*.gd`
3. If you reformatted: `grep -P '\t' scripts/**/*.gd` — fail if tabs appeared (gdformat can introduce them inside multiline strings).
4. `redot --headless -s test/run_tests.gd` — full suite must pass.

CI (`.github/workflows/test.yml`) runs lint + format on every push/PR.

Tests must validate requirements/gameplay behavior independently of the implementation (see AGENTS.md "Test Design"); include positive, negative, boundary, and regression cases. New `.gd`/`.tscn` files require their generated `.uid` to be committed alongside.
