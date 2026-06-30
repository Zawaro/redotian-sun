# Unit Testing for Core Systems - Redotian Sun

## Overview
Unit testing via custom minimal runner (`test/run_tests.gd`). GUT fails on Redot 26.1 — class_name registration breaks. Tests run from CLI and GitHub Actions CI.

## Setup

### Test Runner
- `test/run_tests.gd` — extends SceneTree, discovers `test_*.gd` files, calls `test_*` methods
- No framework dependencies, works on Redot 26.1 LTS

### Directory Structure
```
test/
├── run_tests.gd                          ← test runner
├── test_helper.gd                        ← assertion helpers (unused, kept for reference)
├── unit/
│   ├── test_pathfinder.gd                ← Phase 1: pure functions ✅
│   ├── test_terrain_system.gd            ← Phase 2: autoload state
│   ├── test_spatial_hash.gd              ← Phase 2: cell reservation
│   └── test_selection_manager.gd         ← Phase 2: selection state
└── integration/
    ├── test_pathfinder_terrain.gd        ← Phase 3: height queries
    └── test_movement_signals.gd          ← Phase 3: signal emission
```

### CLI Run
```bash
redot --headless -s test/run_tests.gd
```

## Test Coverage

### Phase 1 — Pure Functions (no SceneTree) ✅
| Function | File | What to assert |
|----------|------|----------------|
| `world_to_cell` | Pathfinder.gd | Known positions → expected cells |
| `cell_to_world` | Pathfinder.gd | Known cells → expected positions |
| `_cell_key` | Pathfinder.gd | Deterministic string output |

### Phase 2 — Autoload Singletons ✅
| System | File | What to assert |
|--------|------|----------------|
| TerrainSystem | test_terrain_system.gd | `init_grid`, `get_cell`, `set_cell`, `clear` |
| SpatialHash | test_spatial_hash.gd | `reserve_cell`, `release_cell`, `is_cell_idle` |
| SelectionManager | test_selection_manager.gd | `select_entity`, `deselect_all` |

### Phase 3 — Integration ✅
| Scenario | File | What to assert |
|----------|------|----------------|
| Pathfinder + TerrainSystem | test_pathfinder_terrain.gd | Height queries return valid floats, find_path works |
| MovementController | test_movement_signals.gd | ⚠️ Skipped — requires scene tree (test runner limitation) |

## CI/CD (GitHub Actions)

### Workflow: `.github/workflows/test.yml`
- **check-openspec**: Enforces no open changes in `openspec/changes/`
- **test**: Installs Redot 26.1, imports assets, runs `redot --headless -s test/run_tests.gd`

## Conventions
- Test files: `test_<module_name>.gd`
- Test methods: `func test_<what>():`
- Assertions: manual if/check with pass/fail counters (no assert() — crashes on failure)
- One test file per system
- Each test method tests one behavior
