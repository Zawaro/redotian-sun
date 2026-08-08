## Why

Fog of war is the last 0% system in the game. `GlobalRules.fog_of_war` and `EntityData.sight` exist but have no consumer, and there is no visibility grid anywhere. Mission play, base defense, and the eventual skirmish loop all depend on an authoritative per-player fog-of-war layer before any visual shroud or entity culling can be built (rendering/culling is a follow-up issue #198).

## What Changes

- Add a `ShroudSystem` autoload: authoritative per-player visibility grid sized to the terrain grid, with three resolved cell states (shroud / fog / visible).
- Height-aware shadowcasting via per-cell Bresenham LOS: a cell blocks vision when its terrain height exceeds the viewer height by more than a delta, or when it is a building cell. Air revealers ignore blockers.
- Ref-counted revealer registration (`register_revealer` / `unregister_revealer`) so overlapping and stacking vision is correct.
- Allied sharing: visibility/exploration queries fold in same-team players (query-time union).
- Reveal limiter: no cell is ever revealed outside the blue visible-bounds play area (`BoundsSystem.is_in_play_area`).
- Circular reveal APIs for the mission/trigger layer: `explore_area` (permanent explore) and `reveal_area` (temporary visible that reverts to explored).
- Shroud growth: when `shroud_grows` is enabled, the unexplored frontier expands one cell per `shroud_growth_interval` gameplay seconds; cells under active vision are protected.
- Two new `GlobalRules` fields: `shroud_grows` (bool, default false) and `shroud_growth_interval` (float, default 10.0). `fog_of_war` (existing, default false) gates the interaction filter.
- Fog-gated interaction: a target entity (or force-fire ground target) is interactable only while its cell is visible to the local player. Shrouded targets fall through to a move order. This applies to commands, cursors, hover preview, and selection, including resource entities (tiberium). All gated on `fog_of_war == true`.
- `SpatialHash.is_building_cell(cell)` helper for vision blocking lookups.
- No visual rendering in this change (fog plane, entity culling, VisionComponent = follow-up issue #198).

## Capabilities

### New Capabilities

- `fog-of-war`: authoritative per-player shroud grid with height-aware shadowcasting, allied sharing, blue-bounds reveal limits, circular trigger reveals, optional shroud growth, and fog-gated interaction filtering.

### Modified Capabilities

- `global-rules`: adds `shroud_grows` and `shroud_growth_interval`; documents the existing `fog_of_war` gate.
- `spatial-hash`: adds `is_building_cell` for per-cell vision-blocking lookups.
- `order-system`: adds fog-gated target filtering (shrouded targets are not attackable/selectable and fall through to move).

## Impact

- **New file:** `scripts/core/ShroudSystem.gd` (autoload).
- **Modified:** `project.godot` (register autoload), `scripts/data/GlobalRules.gd`, `scripts/core/SpatialHash.gd`, `scripts/core/OrderSystem.gd`, `scripts/hud/MouseHandler.gd`, `scripts/core/SelectionManager.gd`, `AGENTS.md` (autoload table).
- **New test:** `test/unit/test_shroud_system.gd`.
- **Backward compatible:** all changes are additive; fog is inert until `fog_of_war` is enabled, so existing maps and skirmish behavior are unaffected.
