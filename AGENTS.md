---
applyTo: '**'
---

# Agent Configuration for Redotian Sun

## Agents
| Name | Description |
|------|-------------|
| `code-reviewer` | Reviews code changes, ensures style and correctness. |
| `bug-fixer` | Investigates failing tests or runtime errors, applies fixes. |
| `documentation` | Generates/updates README, docs, comments. |
| `test-runner` | Executes unit & integration tests, reports results. |
| `performance-tuner` | Analyzes shader / GDScript performance, suggests optimizations. |

## Project Overview

Redotian Sun is an unofficial fan remake of *Command & Conquer: Tiberian Sun*, rebuilt from scratch using the **Redot Engine** (a Godot fork). Unlike the original 2D/2.5‑D version, this remake is fully rendered in 3‑D, providing a more immersive visual experience while preserving core gameplay mechanics. The project aims to faithfully re‑implement the original gameplay while adding modern performance, cross‑platform support and modding capabilities.

## Folder Structure

- `assets/` – All external assets organized by type:
  - `ui/` – UI textures, fonts, panels.
  - `audio/` – Music and sound effects.
  - `tilesets/`, `models/`, etc. for game world resources.
- `scripts/` – GDScript code split into subsystems (`ui/`, `gameplay/`, `data/`). Keeps logic separate from scene files.
- `scenes/` – Packed scenes grouped by purpose (`ui/`, `world/`, `tools/`). Makes the hierarchy tidy and reusable.
- `shaders/` – All shader resources in a dedicated folder, often sub‑categorized (UI, world).
- `project.godot` – Root project file.

(Adjust as your project grows.)

## Redot Documentation

- **Redot Engine Overview** – https://docs.redotengine.org/
- **Shader Language Reference** – https://docs.redotengine.org/tutorials/shaders/
- **Rendering and Shading** – https://docs.redotengine.org/tutorials/shaders/
- **2D Systems** – https://docs.redotengine.org/tutorials/2d/
- **GDScript Basics** – https://docs.redotengine.org/tutorials/scripting/gdscript/
- **3D Systems** – https://docs.redotengine.org/lts-26.1/tutorials/3d/index.html

Feel free to add or remove agents as needed.

*Note: Agents should refer to the **Redot Documentation** section above when needing guidance on engine features, shader optimization, or other development topics.*
