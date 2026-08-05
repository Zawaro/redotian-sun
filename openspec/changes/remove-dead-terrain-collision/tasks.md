# Implementation Tasks

## 1. Removal

- [x] 1.1 Delete `scripts/core/TerrainCollision.gd` and `scripts/core/TerrainCollision.gd.uid`
- [x] 1.2 Remove the `COLLISION_SCRIPT` const and `test_collision_body_mirrors_renderer_transform()` from `test/unit/test_terrain_renderer_pivot.gd` (keep the other three tests and the file's `tile_transform` math coverage)
- [x] 1.3 Remove the `TerrainCollision` entry from the `scripts/core/` listing in `AGENTS.md`

## 2. Verification

- [x] 2.1 Grep `scripts/`, `scenes/`, `test/`, `project.godot`, and `AGENTS.md` for `TerrainCollision` — no remaining references
- [x] 2.2 `redot --headless --import` succeeds
- [x] 2.3 `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd` pass; `grep -P '\t'` shows no tabs introduced
- [x] 2.4 Full test suite (`redot --headless -s test/run_tests.gd`) passes
