## Why

None of the lighting settings in the Debug panel have any effect because `DebugMenu` can never find the `LightingControls` node: it looks it up as a child of its own parent (`HUD`), but `LightingControls` is actually a sibling of `HUD` on `MapBase01`. The lookup returns `null` every time, so `_init_lighting_sliders()` silently bails before wiring any slider signal. The sliders are functional code — they write through Redot's dynamic `Object.set(name, value)` into real setters that apply to the scene light. The fix is a lookup, not a reimplementation.

## What Changes

- Register `LightingControls` in a named scene group so the `DebugMenu` panel can find it regardless of where each node sits in the scene tree.
- Resolve `DebugMenu.lighting_controls` via that group instead of a fragile direct-parent-child path.
- Add a regression test that proves a lighting slider mutation propagates to the actual scene light/environment nodes (fails on current code, passes after fix).

## Capabilities

### New Capabilities
- `lighting-controls`: The Debug panel's lighting sliders and sun-color picker must resolve and apply to the live scene's sun light (`LightPivot` / `DirectionalLight3D`) and world environment (`WorldEnvironment`), so runtime changes to elevation, rotation, intensity, color, shadow strength, ambient, fog, sky rotation, and glow intensity are visible.

### Modified Capabilities
<!-- None. Existing debug-menu capability has no spec-level requirement changes. -->

## Impact

- `scripts/environment/LightingControls.gd` — group registration in `_ready()`.
- `scripts/ui/DebugMenu.gd:75-77` — replace the failed parent lookup with a group lookup.
- `scenes/maps/MapBase01.tscn` — unchanged (already instances both nodes correctly).
- `test/` — new regression test under the custom runner.