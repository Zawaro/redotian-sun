## Why

Full codebase review (issue #16) identified 16 validated findings — 4 bugs, 5 dead code items, 5 over-engineering issues, 2 style violations — all confirmed against Redot 26.1 LTS documentation. Several findings represent real crash risk in release builds (assert stripped), desyncable state (grid_cells without setter), and framerate-dependent behavior. This change fixes all findings, adds CI linting to prevent regressions, and updates project docs.

## What Changes

- **Bug fixes**: Replace `assert()` with `push_error()` + `return` in MouseHandler (4 locations); replace fragile relative path in BoundsSystem with `@export`; add setter to `grid_cells` in TerrainSystem; remove hardcoded `* 60.0` framerate multiplier in CameraController
- **Dead code removal**: Delete empty SceneManager.gd, unused `_on_deselected()` method, unused `grid_size` getter, duplicate `_vkey()` function, duplicate `raise_cell()` call
- **Refactoring**: Optimize Pathfinder heap key lookups; extract catmull-rom spline utils from MovementController into SplineUtil; move MapEditor UI from code to scene; extract health bar/outline generation from SelectComponent into SelectionVisuals
- **Style**: Replace string-based `emit_signal()` with typed `.emit()` in HealthComponent; fix PascalCase variable in MainMenuItem01
- **CI**: Add gdtoolkit lint + format-check job to GitHub Actions
- **Docs**: Update AGENTS.md (test suite, linting, folder structure) and README.md (development section)

## Capabilities

### New Capabilities
- `code-quality`: Runtime error handling, signal emit patterns, naming conventions
- `terrain-grid-safety`: Grid cell state consistency via setter enforcement
- `camera-framerate`: Frame-rate independent camera movement
- `selection-visuals`: Separated presentation layer for unit selection display
- `pathfinding-optimization`: Efficient A* heap operations with cached keys
- `ci-linting`: Automated GDScript lint and format checking in CI

### Modified Capabilities
<!-- No existing specs directory — all capabilities are new -->

## Impact

- 15 files edited, 1 deleted, 3 created
- ~500 net lines removed
- No API changes, no scene format changes
- No breaking changes to existing gameplay
- CI pipeline gains new lint job (additive)
