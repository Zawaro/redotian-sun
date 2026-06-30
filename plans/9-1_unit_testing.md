# Unit Testing for Core Systems - Redotian Sun

## Overview
Unit testing via [GUT](https://github.com/bitwes/Gut) (Godot Unit Test) v9.x. Tests run in-editor, from CLI, and in GitHub Actions CI.

## Setup

### Install GUT
1. `AssetLib` → search "GUT" → install, OR
2. `git clone https://github.com/bitwes/Gut.git addons/gut`
3. Enable plugin in `Project > Project Settings > Plugins`

### Directory Structure
```
test/
├── unit/
│   ├── test_pathfinder.gd
│   ├── test_terrain_system.gd
│   └── test_spatial_hash.gd
├── integration/
│   └── test_movement.gd
└── .gutconfig.json
```

### `.gutconfig.json`
```json
{
  "dirs": ["res://test/unit/", "res://test/integration/"],
  "include_subdirs": true,
  "log_level": 1
}
```

### CLI Run
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```

## Test Coverage

### Phase 1 — Pure Functions (no SceneTree)
| Function | File | What to assert |
|----------|------|----------------|
| `world_to_cell` | Pathfinder.gd | Known positions → expected cells |
| `cell_to_world` | Pathfinder.gd | Known cells → expected positions |
| `_cell_key` | Pathfinder.gd | Deterministic string output |

### Phase 2 — Autoload Singletons
| System | What to assert |
|--------|----------------|
| TerrainSystem | `init_grid`, `get_cell`, `set_cell`, `clear` |
| SpatialHash | `occupy_cell`, `release_cell`, `is_occupied` |
| SelectionManager | `select`, `deselect`, `get_selected` |

### Phase 3 — Integration
| Scenario | What to assert |
|----------|----------------|
| Pathfinder + TerrainSystem | Height queries return valid floats |
| MovementController | `arrived` signal emitted after path complete |

## CI/CD (GitHub Actions)

### Workflow: `.github/workflows/test.yml`
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Godot Heads-Up
        uses: chickensoft-games/setup-godot@v2
        with:
          version: "4.4.1"
          mono: false
      - name: Import project
        run: godot --headless --import
      - name: Run tests
        run: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit -gjunit_xml_file=results.xml
      - name: Upload results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: results.xml
```

## Conventions
- Test files: `test_<module_name>.gd`
- Test classes: `extends GutTest`
- Test methods: `func test_<what>():`
- One assert per behavior (or group related asserts in same test)
- Use `before_each()` for setup, `after_each()` for cleanup
- No `load()` in tests — use `preload()` or mock data
