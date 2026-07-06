---
applyTo: '**'
---

# Agent Configuration for Redotian Sun

## Project Overview

Redotian Sun is an unofficial fan remake of *Command & Conquer: Tiberian Sun*, rebuilt from scratch using the **Redot Engine 26.1 LTS** (Forward Plus). Unlike the original 2D/2.5‑D version, this remake is fully rendered in 3‑D while preserving core RTS gameplay mechanics — base building, unit production, combat, fog of war, and economy.

Current implementation status:
- **Core systems**: Selection manager, camera controller, mouse handler, bounds system, scene management
- **Entity components**: HealthComponent, HitboxComponent, SelectComponent (GDScript + component scenes)
- **Entities implemented**: Nod Buggy (unit), GDI ConYard (structure), Civilian Guard Tower (neutral structure), Temp Infantry placeholder
- **UI**: Main menu with blur shader effect, FPS counter label
- **World**: Default lighting/environment scene, test map and base map placeholders

## Engine & Runtime

| Detail | Value |
|--------|-------|
| Engine | Redot 26.1 LTS (Forward Plus renderer) |
| Scripting language | GDScript only — no C# bindings (.gdnlib / .gdns files exist in project yet |
| Main scene | `scenes/MainScene.tscn` (UID: c6s5n02jefgmd) |
| Autoloaded singletons | `SelectionManager` (`scripts/core/SelectionManager.gd`) — the sole autoload registered in `project.godot` |
| Viewport resolution | 1920×1080, stretch mode = viewport |

## Folder Structure (Actual)

### `scripts/` — GDScript source files (23 .gd files total)

```
scripts/
├── components/     # Reusable entity behavior scripts
│   ├── HealthComponent.gd
│   ├── HitboxComponent.gd
│   ├── MovementController.gd
│   └── SelectComponent.gd
├── core/           # Engine-level systems (autoloaded or wired in scenes)
│   ├── BoundsSystem.gd
│   ├── DebugVisualizer.gd
│   ├── Pathfinder.gd
│   ├── SceneManager.gd       ← empty, pending deletion
│   ├── SelectionManager.gd    ← autoload singleton
│   ├── SpatialHash.gd
│   ├── TerrainCollision.gd
│   ├── TerrainRenderer.gd
│   └── TerrainSystem.gd
├── editor/         # Map editor tools
│   ├── HeightPainter.gd
│   ├── MapEditor.gd
│   └── Minimap.gd
├── hud/            # Camera, mouse input handling for gameplay view
│   ├── Camera01.gd
│   ├── CameraController.gd
│   └── MouseHandler.gd
├── maps/           # Map-specific scripts
│   └── TestMap02.gd
└── ui/             # Menu/UI logic (main menu items, FPS counter)
    ├── FPSCounterLabel01.gd
    ├── MainMenu01.gd
    └── MainMenuItem01.gd
```

### `scenes/` — Packed scenes (23 .tscn files total)

```
scenes/
├── MainScene.tscn                  # Entry point scene
├── LoadingScreen.tscn              # Loading screen placeholder
├── components/                     # Component entity definitions (.tscn + matching .gd scripts above)
│   ├── HealthComponent.tscn
│   ├── HitboxComponent.tscn
│   └── SelectComponent.tscn
├── core/                           # Core system scenes (gameplay container, bounds visualizer)
│   ├── Gameplay.tscn
│   └── BoundsSystem.tscn
├── environment/                    # Lighting & world settings
│   ├── DefaultSunLight01.tscn
│   └── DefaultWorldEnvironment01.tscn    ← uses assets/hdri/syferfontein_6d_clear_1k.hdr
├── entities/                       # Placeable game units, structures, infantry
│   ├── infantry/TempInfantry01.tscn     # Placeholder — no gameplay logic yet
│   ├── structures/gdi/GDIConyard01.tscn  # GDI faction construction yard
│   └── structures/neutral/CivilianGuardTower01.tscn
├── hud/                            # Camera & mouse handler scene instances
│   ├── Camera01.tscn
│   └── MouseHandler.tscn
├── maps/                           # Playable map definitions (not unit tests)
│   ├── MapBase01.tscn
│   └── TestMap01.tscn
└── ui/                             # Menu UI scenes (.tscn instances of scripts/ui/*)
    ├── FPSCounter01.tscn
    ├── MainMenu01.tscn             ← active main menu scene
    ├── MainMenuItem01.tscn
    └── MainMenu01_old.tscn         (# deprecated backup, do not modify or delete without note)
```

### `assets/` — External resources (models, textures, fonts, UI images, HDRI maps)

| Subdirectory | Contents | Notable files |
|---|---|---|
| `fonts/Poppins/` | Font families used in UI | Poppins-SemiBold.ttf |
| `hdri/` | Environment map for world lighting | syferfontein_6d_clear_1k.hdr (6-directional) |
| `models/` | .glb mesh files (+ exported texture PNGs) | nod_buggy01, prism_tower01, gdi_conyard01, civ_guardtower01, placeholder_terrain01 |
| `resources/materials/` | Custom material resources (.tres) | DefaultMaterial01.tres (single shared default) |
| `textures/` | Surface textures for models & terrain (.png/.jpg) | nod_buggy01 surface maps, terraforming tiles, civ tower map + prism_tower metal texture |
| `ui/` | Menu background images and UI overlays | tsmenu2k.png (TS-style menu), background01_final01.jpg |

### `shaders/` — Shader resources (.gdshader)

```
shaders/ui/MainMenuItemBlur01.gdshader   ← blur effect applied to main menu items
```

> No world/environment shaders exist yet. Only a single UI shader is present in the project.

### `plans/` — Design & planning documents (21 .md files, organized by category)

| Category | Files | Topic |
|----------|-------|-------|
| 1 | camera_selection.md, base_building.md, economy_resources.md, unit_production.md | Core gameplay pillars |
| 2 | navigation.md, movement_commands.md | Movement systems |
| 3 | combat_weapons.md, combat_ai.md | Combat & AI behavior |
| 4 | fog_vision.md, map_exploration.md | Fog of war / vision system |
| 5 | rts_interface.md, game_management.md | UI flow & game state management |
| 6 | terrain_systems.md, map_design.md | World generation & level design rules |
| 7 | faction_systems.md, unit_roster.md | Faction identities & entity roster |
| 8 | multiplayer.md, modding_support.md | Online play & mod API plans |
| 9 | unit_testing.md, final_polish.md | QA checklist & release criteria |

- **Roadmap**: `project_planning_roadmap.md` — overall project timeline and milestones.

## What Does NOT Exist Yet (Important for Agents)

- **No build system** — no Makefile, Justfile, .editorconfig, Dockerfile, or shell scripts. The project is built entirely through the Redot editor and export templates.
- **No C# / native library bindings** — no `.gdnlib`, `.gdns`, or `Godot.csproj` files. Everything is pure GDScript + scenes.

## Testing & Linting

### Running Tests

```bash
redot --headless -s test/run_tests.gd
```

The test suite uses a minimal custom runner (`test/run_tests.gd`) — no external test framework. Tests are in `test/unit/` and `test/integration/`.

### Linting

```bash
pip install gdtoolkit
gdlint scripts/**/*.gd test/**/*.gd
gdformat --check scripts/**/*.gd test/**/*.gd
```

CI runs lint + format check on every push and PR via GitHub Actions (`.github/workflows/test.yml`). Configuration is in `.gdlintrc`.

## Redot Documentation & Research Tools

Agents should **always use Context7 MCP** (`resolve-library-id` + `query-docs`) to fetch library/engine documentation in-session. The Redot Engine library ID is `/redot-engine/redot-docs`. This ensures you always have access to the latest, version-specific docs with code examples — prefer this over static web links that may change or become outdated.

For general web searches (news, tutorials, third-party resources), **use SearXNG MCP** (`searxng_searxng_web_search`). Do not browse arbitrary URLs directly unless provided by the user.

Web references for manual lookup:
| Resource | URL |
|----------|-----|
| Engine overview & docs (26.1 LTS) | https://docs.redotengine.org/lts-26.1/ |
| Shader Language Reference | https://docs.redotengine.org/tutorials/shaders/ |
| 3D Systems | https://docs.redotengine.org/lts-26.1/tutorials/3d/index.html |
| GDScript Basics | https://docs.redotengine.org/tutorials/scripting/gdscript/ |

*Agents should always prefer Redot docs over upstream Godot docs when there are differences.*

## GDScript Best Practices

### Indentation — Spaces Only

Use **4 spaces** for indentation in all GDScript files. Never use tabs. Mixing tabs and spaces causes parse errors in Redot's GDScript parser. If editing a file that already uses a different convention, convert the entire file to 4-space indentation before saving.

**Important**: `gdformat` can occasionally introduce tab characters when reformatting multi-line strings. Always run `grep -P '\t' scripts/**/*.gd` after formatting to verify no tabs were introduced. If tabs are found, convert them back to 4 spaces before committing.

### Naming Conventions

| Category | Convention | Example |
|----------|-----------|---------|
| Classes / Scripts | PascalCase + `class_name` | `class_name HealthComponent extends Node3D` |
| Signals | past_tense_snake_case (describe what happened) | `signal health_changed(current: int)` |
| Constants | SCREAMING_SNAKE_CASE | `const MAX_SPEED: float = 200.0` |
| Variables / Functions | snake_case (`_snake_case` for private) | `var current_health`, `_clamp_value()` |

### Type Hints — REQUIRED

Use explicit type hints on every variable, parameter, and return value. Redot's GDScript provides autocomplete and compile-time checks when types are declared.

```gdscript
@onready var sprite_3d: Sprite3D = $Sprite3D
var speed: float = 100.0
func take_damage(amount: int) -> void: ...
signal score_updated(new_score: int, old_score: int)
```

### Node References

| Prefer | Avoid |
|--------|-------|
| `@onready var x: Type = $Path` (≤2 levels deep) | `get_node()` inside `_ready()`, deep paths `$A/B/C/D/E/F` |
| `%UniqueName` for autoloaded/root-wired nodes | Hardcoded string paths to sibling scenes' children |

### Signal-Driven Architecture — "Signal Up, Call Down"

Children emit signals; parents connect and react. Children must **never** directly call parent methods or hold references upward through the scene tree.

```gdscript
# Child emits (no knowledge of parent)
signal health_changed(current: int, maximum: int)
func take_damage(amount: int) -> void:
    _current_health = maxi(0, _current_health - amount)
    health_changed.emit(_current_health, max_health)

# Parent connects and reacts
@onready var health_component: HealthComponent = $HealthComponent
func _ready() -> void:
    health_component.health_changed.connect(_on_health_changed)
```

### Resource Loading Strategy

| Mechanism | When to Use | Example |
|-----------|-------------|---------|
| `preload()` | Compile-time resolved, small/critical assets | `const BULLET_SCENE: PackedScene = preload("res://scenes/bullet.tscn")` |
| `load()` at runtime | Dynamic/optional content only (never in `_process`) | `return load(scene_path) as PackedScene` |
| Threaded loading | Large scenes/assets to prevent frame stutter | `ResourceLoader.load_threaded_request(path)` |

### Script Structure Template

Order sections **in this exact order** in every GDScript file:

1. `class_name` + doc comments
2. Signals (consumers connect here)
3. Enums
4. `@export` fields
5. Constants (`const`)
6. Public variables (`var`)
7. Private variables (`_var`)
8. `@onready` cached node references
9. Lifecycle methods: `_enter_tree()` → `_ready()` → `_process()` / `_physics_process()` → `_unhandled_input()` → `_exit_tree()`
10. Public methods (callable from other nodes)
11. Private methods (`_method`)

### Editor Tool Scripts — `@tool` Annotation

Use `@tool` for editor-time scripts with custom inspectors, real-time preview, and scene validation. Always guard runtime-only calls:

```gdscript
@tool
extends Node3D

func _get_configuration_warnings() -> PackedStringArray:
    var issues := validate_entity_scene() as PackedStringArray
    if not issues.is_empty(): return PackedStringArray(issues)
    return PackedStringArray([])

func _enter_tree() -> void:
    if Engine.is_editor_hint():
        # Editor-specific logic here
```

### Common Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Polling in `_process()` for infrequent changes | Wastes CPU every frame | Use signals or `await` with timers |
| `get_parent().get_parent()...` chains | Tight coupling, breaks on refactor | Connect via signals, use `%UniqueName` |
| Deep node paths `$A/B/C/D/E/F` | Fragile to scene reorganization | Use `@onready var x: Type = $SiblingOrChild` |
| Calling `load()` in `_process()` / tight loops | Frame stutter, memory churn | Move to `_ready()`, use `preload()` or cache with `const`/`@onready var` |
| String-based signals (`emit_signal("x", val)`) | Typos silently ignored; no autocomplete | Use typed signal declarations + `.emit(value)` |
| Untyped `@onready var x = $NodePath` | Loses type hints, disables IDE autocomplete | Always add explicit type: `@onready var sprite_3d: Sprite3D = $Sprite3D` |
| Logic inside autoload singletons (GameManager with all rules) | Hard to test; couples every subsystem together | Keep autoloads thin — expose only state + signals |
| Magic numbers (`if speed > 200 and damage == 15`) | Unclear meaning, impossible to tune | Extract into named constants or `@export` fields |
| `node != null` check after potential free | Freed nodes are non-null in GDScript — accessing crashes | Use `is_instance_valid(node)` instead |

### Redot Engine 26.1 LTS API Notes

- **Renderer**: Forward Plus only (`StandardMaterial3D` / `ORMMaterial3D`).
- **Collision layers**: StaticBody3D defaults to layer 1. Set masks via bit shifts: `collision_mask = 1 << LAYER_NUMBER`.
- **await syntax**: Full GDScript `await` support — use for timers, signals (`await node.timeout`). No need for deprecated `yield()`.
- **Process modes**: `PROCESS_MODE_INHERIT`, `PROCESS_MODE_PAUSED`, `PROCESS_MODE_ALWAYS`, `PROCESS_MODE_WHEN_PAUSED`.

## Key Conventions Observed in Codebase

- **Naming**: PascalCase for classes, scripts, scenes; snake_case for variables and functions. Scene files mirror their script names (e.g., `HealthComponent.tscn` ↔ `scripts/components/HealthComponent.gd`).
- **Error handling**: Use `push_error()` + `return` for runtime precondition guards. `assert()` is stripped in release builds — never use it for runtime checks.
- **Scene composition**: Component scripts are attached to component scenes (`components/*.tscn`) which are then instantiated as children of entity scenes (e.g., entities/units/nod/NodBuggy.tscn). Core systems like `BoundsSystem` and camera/mouse input have dedicated scene instances in the gameplay hierarchy.
- **Autoloads**: Only one autoload is registered — `SelectionManager`. Additional singletons should be added via project settings, not hardcoded references.
- **Signal syntax**: Use typed `signal_name.emit(args)` instead of `emit_signal("name", args)` for autocomplete and compile-time checks.

## Full Skill Reference

For complete GDScript best practices (state machines, object pooling, save/load patterns, export annotations reference), see `.agents/skills/redot-engine-best-practices/SKILL.md`.
