---
applyTo: '**'
---

# Agent Configuration for Redotian Sun

## Project Overview

Redotian Sun is a fan remake of *Command & Conquer: Tiberian Sun*, built in **Redot Engine 26.1 LTS** (Forward Plus). Fully 3D, preserving core RTS mechanics — base building, unit production, combat, fog of war, economy. Pure GDScript, no C#.

## Engine & Runtime

| Detail | Value |
|--------|-------|
| Engine | Redot 26.1 LTS (Forward Plus renderer) |
| Main scene | `scenes/MainScene.tscn` |
| Viewport | 1920×1080, stretch mode = viewport |

### Autoloads (8 singletons, all registered in `project.godot`)

| Singleton | Script | Purpose |
|-----------|--------|---------|
| `SelectionManager` | `scripts/core/SelectionManager.gd` | Entity selection tracking |
| `DebugVisualizer` | `scripts/core/DebugVisualizer.gd` | Debug mesh overlays |
| `SpatialHashSingleton` | `scripts/core/SpatialHash.gd` | Spatial partitioning |
| `TerrainSystem` | `scripts/core/TerrainSystem.gd` | Terrain grid management |
| `EntityFactory` | `scripts/entities/EntityFactory.gd` | Creates entities from EntityData resources |
| `BuildingManager` | `scripts/buildings/BuildingManager.gd` | Build mode, placement, preview |
| `EconomyManager` | `scripts/economy/EconomyManager.gd` | Per-player credits, deductions |
| `TiberiumGrowthSystem` | `scripts/core/TiberiumGrowthSystem.gd` | Tiberium spread and tree regrowth |

## Folder Structure

| Directory | Purpose |
|-----------|---------|
| `scripts/components/` | 19 reusable entity behaviors (Health, Hitbox, Select, Combat, Movement, Art, Factory, Harvest, Tiberium, etc.) |
| `scripts/core/` | Engine-level systems: SelectionManager, BoundsSystem, Pathfinder, SpatialHash, Terrain*, TiberiumGrowth, DebugVisualizer, EntityMaskManager, PixelArtManager, SplineUtil |
| `scripts/data/` | Resource type definitions: EntityData, WeaponData, ArtData, WarheadData, PlayerData, GlobalRules, MapOverride, ActiveAnimData |
| `scripts/entities/` | EntityFactory autoload — creates entities from data resources |
| `scripts/buildings/` | BuildingManager — build mode, placement, preview system |
| `scripts/economy/` | EconomyManager — per-player credit tracking |
| `scripts/editor/` | Map editor tools: HeightPainter, MapEditor, Minimap |
| `scripts/hud/` | Camera01, CameraController, MouseHandler |
| `scripts/maps/` | Map-specific scripts (TestMap02, MapLoader) |
| `scripts/ui/` | Main menu, Sidebar, FPS counter |
| `scenes/` | 37 packed scenes: entities, components, maps, UI, environment, editor |
| `resources/` | `.tres` resource files — entity definitions, art configs, global rules |
| `assets/` | Models (.glb), textures, fonts, HDRI, UI images |
| `shaders/` | Single UI shader (`MainMenuItemBlur01.gdshader`) |
| `plans/` | 22 design docs organized by gameplay category (1-1 through 9-2, plus roadmap) |
| `test/` | Custom test runner, `TestHelper` class, unit and integration tests |
| `openspec/` | OpenSpec change management (must archive changes before merge — CI enforces) |

## Data-Driven Architecture

Entities are defined as `EntityData` resources (`.tres` files under `resources/entities/`). EntityFactory autoload reads these at runtime and dynamically attaches component scenes/scripts based on data properties. The data class hierarchy:

- `EntityData` (base) — identity, stats, combat, movement, build requirements
  - `WeaponData` — weapon definitions (damage, range, rate, warhead)
  - `ArtData` — sprite/animation references
  - `WarheadData` — damage type, radius, effects
  - `PlayerData` — per-player state
  - `GlobalRules` — game-wide constants (loaded from `resources/global_rules.tres`)

Each entity type also has an art `.tres` (e.g., `resources/art/structures/gdi/gacnst_art.tres`) mapping animation states to sprite frames.

## What Does NOT Exist Yet

- **No build system** — built entirely through the Redot editor. No Makefile, Justfile, Dockerfile, or shell scripts.
- **No C# / native bindings** — pure GDScript + scenes only.

## Testing & Linting

### Running Tests

```bash
redot --headless -s test/run_tests.gd
```

Custom runner (`test/run_tests.gd`) discovers and runs all `test_*.gd` files in `test/unit/` and `test/integration/`. No external framework.

Test files use `TestHelper` class (`test/test_helper.gd`) with static assertions:
- `TestHelper.assert_eq(got, expected, msg)`
- `TestHelper.assert_true(value, msg)`
- `TestHelper.reset()` — called between test methods

The runner auto-injects autoloads as shorthand vars: `_ts` (TerrainSystem), `_sh` (SpatialHash), `_sm` (SelectionManager), `_bm` (BuildingManager), `_em` (EconomyManager).

### Linting

```bash
pip install gdtoolkit
gdlint scripts/**/*.gd test/**/*.gd
gdformat --check scripts/**/*.gd test/**/*.gd
```

CI runs lint + format on every push/PR (`.github/workflows/test.yml`). Config in `.gdlintrc`. Formatter config in `gdformatrc` (4-space indent, 100 char line length).

**After `gdformat`**: always run `grep -P '\t' scripts/**/*.gd` to check for tab introduction in multi-line strings.

## GDScript Conventions

### Indentation — Spaces Only

4 spaces, never tabs. Mixing causes parse errors in Redot.

### Type Hints — REQUIRED

Every variable, parameter, and return value must have explicit type hints.

### Signal-Driven Architecture — "Signal Up, Call Down"

Children emit signals; parents connect and react. Children never call parent methods directly.

### Error Handling

- `push_error()` + `return` for runtime precondition guards
- `assert()` is stripped in release builds — never use for runtime checks
- `is_instance_valid(node)` instead of `node != null` after potential free

### Signal Syntax

Use typed `signal_name.emit(args)` — never `emit_signal("name", args)`.

### Doc Comments — `##` vs `#`

- `## Comment` — Redot editor doc comment. Shows as a tooltip hint in the Inspector when hovering the `@export` property below it. Use these as section headers above `@export` groups in Resource scripts.
- `# Comment` — Regular code documentation. Use for explaining logic, not for editor-facing descriptions.

### Script Structure Order

1. `class_name` + doc comments
2. Signals
3. Enums
4. `@export` fields
5. Constants (`const`)
6. Public variables
7. Private variables (`_var`)
8. `@onready` cached node references
9. Lifecycle: `_enter_tree()` → `_ready()` → `_process()` / `_physics_process()` → `_unhandled_input()` → `_exit_tree()`
10. Public methods
11. Private methods (`_method`)

## Key Conventions

- **Naming**: PascalCase for classes/scenes, snake_case for vars/funcs. Scene files mirror script names (e.g., `HealthComponent.tscn` ↔ `scripts/components/HealthComponent.gd`).
- **Scene composition**: Component scenes (`components/*.tscn`) are instantiated as children of entity scenes. Core systems have dedicated scene instances in the gameplay hierarchy.
- **Autoloads**: 8 autoloads registered in `project.godot`. Add new singletons via project settings, not hardcoded references.

## Research Tools

### Codebase Memory (MCP) — Preferred for Code Discovery

This repo is indexed in `codebase-memory-mcp`. Use its graph tools **before** grep/glob/read when searching for code:

- `search_graph` — find functions, classes, routes, variables by pattern or natural language
- `trace_path` — trace callers, callees, or data flow through the code graph
- `get_code_snippet` — read specific function/class source code
- `query_graph` — run Cypher queries for complex patterns

Fall back to grep/glob only for string literals, config values, or non-code files.

#### Indexing mode — MUST use `full`

This project's source code lives in `scripts/` (Redot/Godot convention). The indexer's `moderate` and `fast` modes skip `scripts/` (it's in `FAST_SKIP_DIRS`). Always use `mode: "full"` when indexing or re-indexing this repo, or GDScript files won't be in the graph.

#### Project path convention

The `project` argument uses the repo's **absolute path** with all `/` replaced by `-`. Short names like `redotian-sun` don't resolve correctly. To find the correct project identifier:

1. Run `codebase-memory-mcp index_status` with the full path: `project: "mnt/work2/Redot/redotian-sun"` → the response includes a `root_path` field confirming the canonical path
2. Or run `codebase-memory-mcp list_projects` to see all indexed project IDs — the one starting with the repo's absolute path is this project

Example: repo at `/mnt/work2/Redot/redotian-sun` → project ID is `mnt-work2-Redot-redotian-sun`.

To re-index this repo (e.g. after adding new scripts):
```
codebase-memory-mcp index_repository repo_path="/mnt/work2/Redot/redotian-sun" mode="full"
```

### Redot Engine Docs (Context7 MCP)

Use `resolve-library-id` + `query-docs` for Redot docs (library ID: `/redot-engine/redot-docs`). Prefer Redot docs over upstream Godot docs.

### Web Search (SearXNG MCP)

Use `searxng_searxng_web_search` for general web searches, tutorials, third-party resources.

### Reference URLs

| Resource | URL |
|----------|-----|
| Engine docs (26.1 LTS) | https://docs.redotengine.org/lts-26.1/ |
| Shader Language | https://docs.redotengine.org/tutorials/shaders/ |
| 3D Systems | https://docs.redotengine.org/lts-26.1/tutorials/3d/index.html |
| GDScript Basics | https://docs.redotengine.org/tutorials/scripting/gdscript/ |

## Full Skill Reference

For complete GDScript best practices (state machines, object pooling, save/load patterns, export annotations), see `.agents/skills/redot-engine-best-practices/SKILL.md`.
