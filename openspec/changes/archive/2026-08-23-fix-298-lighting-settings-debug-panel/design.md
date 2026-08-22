## Context

`DebugMenu.gd` resolves its `lighting_controls` field by looking up a child named `LightingControls` under `get_parent()` — which is the `HUD` CanvasLayer in `MapBase01.tscn`. But `LightingControls` (a `Node3D` with `scripts/environment/LightingControls.gd`) is a direct child of `MapBase01`, sibling to `HUD`. The lookup always returns `null`, so `_init_lighting_sliders()` guards on that null and returns early. Every lighting slider and the sun-color picker stay unwired.

Investigating against a real `MapBase01` scene exposed a second, subtler defect: even the correct group lookup fails if it fires in `DebugMenu._ready()` before `LightingControls._ready()` registers the `lighting_controls` group. HUD always readies its subtree (containing `DebugMenu`) before the later sibling `LightingControls`, so an eager one-shot resolve still yields `null` in the running game.

`LightingControls.gd` already implements real setters (`_apply_sun`, `_apply_shadow`, `_apply_environment`) that mutate `DirectionalLight3D` / `WorldEnvironment` properties, and the panel's slider handlers write through Redot's dynamic `Object.set(name, value)`, which routes into those setters. So the whole data path is intact — it just never gets connected.

## Goals / Non-Goals

**Goals:**
- Make `DebugMenu` reliably find `LightingControls` regardless of scene load order.
- Keep the change minimal and consistent with existing lookup conventions.
- Add a regression test against the real scene that fails on the pre-fix and passes after.

**Non-Goals:**
- Rewriting `LightingControls` or its apply logic (it works).
- Re-organizing the `MapBase01` scene tree.
- Adding lighting presets or persistence across scene changes.

## Decisions

**Decision 1: Find the node via a scene group, not a parent crawl.**
`DebugMenu` already uses a named group for itself — `add_to_group("debug_menu")` — and other lookups in the codebase (e.g. `UIUtil.is_mouse_over_debug_menu`) resolve via `get_tree().get_first_node_in_group(...)`. Mirror that.

- `LightingControls._ready()` adds `add_to_group("lighting_controls")`.
- `DebugMenu` resolves `get_tree().get_first_node_in_group("lighting_controls")` instead of `get_parent().get_node_or_null(...)`.

Alternative considered: climb the tree (`get_parent().get_parent()`). Smaller diff initially, but it bakes the panel's `HUD` depth into the lookup and breaks if the hierarchy ever changes. The group is depth-agnostic.

**Decision 2: Resolve lazily, not at `_ready()`.**
Because `LightingControls._ready()` (which registers the group) runs after `DebugMenu._ready()`, the eager one-shot read is insufficient. Move the group resolve into a guarded `_init_lighting_sliders()` that re-checks the group each call if its reference is still `null`, and re-invoke it when the Lighting section is opened. A `_lighting_sliders_wired` flag prevents double-connecting the same signals on repeated opens.

**Decision 3 — Regression test drives the real scene nodes.**
Instantiate the real `scenes/maps/MapBase01.tscn`, wait for full ready, open the Lighting section (its intended user trigger), then drive `lighting_controls.set(...)` (the slider handler's action) and assert the real `DirectionalLight3D.light_energy` / `WorldEnvironment.environment.fog_density` change. Because the test uses the real packed scene, it catches the load-order defect a fabricated-node test would miss. It fails pre-fix (null `lighting_controls`) and passes post-fix.

## Risks / Trade-offs

- **Group name collision** → Choose `lighting_controls`, a specific name unlikely to collide. If a collision appears, `get_first_node_in_group` returns the first match, which is acceptable for a debug facility.
- **Lazy resolve depends on a retry trigger** → If the Lighting section is never opened, the sliders stay unwired. That holding behavior (a collapsed section) is acceptable; the open action is exactly when a human expects lighting to respond.
- **Behavioral test weight** → The integration-style test is heavier than a unit test, but it catches the real load-order bug and matches the repo's "behavior, not implementation" guidance.