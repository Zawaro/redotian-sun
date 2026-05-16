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

### `scripts/` — GDScript source files (12 .gd files total)

```
scripts/
├── components/     # Reusable entity behavior scripts + HitboxComponent.tres resource
│   ├── HealthComponent.gd
│   ├── HitboxComponent.gd
│   └── SelectComponent.gd
├── core/           # Engine-level systems (autoloaded or wired in scenes)
│   ├── BoundsSystem.gd
│   ├── SceneManager.gd
│   └── SelectionManager.gd    ← autoload singleton
├── hud/            # Camera, mouse input handling for gameplay view
│   ├── Camera01.gd
│   ├── CameraController.gd
│   └── MouseHandler.gd         ← uses assert() for precondition guards
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

- **No test framework** — no Godot tests (`*test.gd`, integration scenes, or CI). See `plans/9-1_unit_testing.md` for the planned approach.
- **No build system** — no Makefile, Justfile, .editorconfig, Dockerfile, or shell scripts. The project is built entirely through the Redot editor and export templates.
- **No C# / native library bindings** — no `.gdnlib`, `.gdns`, or `Godot.csproj` files. Everything is pure GDScript + scenes.
- **No CI/CD pipeline** — development happens inside the engine; exports are done manually via Redot editor export presets.

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

## Key Conventions Observed in Codebase

- **Naming**: PascalCase for classes, scripts, scenes; snake_case is not used. Scene files mirror their script names (e.g., `HealthComponent.tscn` ↔ `scripts/components/HealthComponent.gd`).
- **Assertions over error handling** — `MouseHandler.gd` uses GDScript's built-in `assert()` calls for precondition guards rather than try/catch or explicit checks.
- **Scene composition**: Component scripts are attached to component scenes (`components/*.tscn`) which are then instantiated as children of entity scenes (e.g., entities/units/nod/NodBuggy.tscn). Core systems like `BoundsSystem` and camera/mouse input have dedicated scene instances in the gameplay hierarchy.
- **Autoloads**: Only one autoload is registered — `SelectionManager`. Additional singletons should be added via project settings, not hardcoded references.
