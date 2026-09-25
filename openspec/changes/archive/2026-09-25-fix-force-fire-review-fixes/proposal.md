## Why

A second review pass on the archived `add-force-fire-ground-targeting` change (commits `06e516d6` + `c78163ff`) found six real defects that shipped with it. They range from a visible double impact effect to an unreachable range guard and a mis-judged shroud gate. The prior review round (tasks 9.x) was folded into the change before archive; these are post-archive findings.

## What Changes

- **One impact report per resolved shot.** A detonation that damages both an entity occupant and a cell overlay played `WarheadData.impact_fx` and `sound_impact` twice at the same point. `EntityFactory` now ignores cell overlays (bridge/ice/tiberium) at the per-victim damage choke point; the shot's single report comes from the entity victim or the cell-damage fallback.
- **No overlay scan for warheads that cannot hurt overlays.** `SpatialHash.find_cell_overlays` returns immediately when `not can_damage_walls and not can_damage_tiberium`, so most shots pay no bridge/ice registry scan.
- **Ground projectiles fizzle at max range.** A ground shot has no live target to invalidate it, and its branch returned before the entity-path max-range guard. It now frees itself past `_max_range`.
- **Force-fire shroud gate judged on the clicked cell.** `OrderSystem` passes the raw `target_pos`, not the bounds-clamped `bounds.pos`, to the shroud gate — matching the requirement that the *clicked* cell be explored.
- **Minimap orders target the top surface.** The minimap built `cell_to_world` at ground height and set no target level, so a bridge click aimed beneath the deck. It now uses the cell's top surface level/height and sets `MOD_TARGET_LEVEL`.
- **Archived manual task closed.** `add-force-fire-ground-targeting` task 8.4 is marked complete with a note that automated tests cover its cases (no open manual task left at archive).

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `entity-factory`: the warhead impact FX requirement is scoped to a single report per resolved shot and excludes cell overlays from the per-victim trigger.
- `audio-system`: the warhead impact report requirement is scoped the same way.

The remaining fixes are implementation conformance to requirements that already state the intended behavior — `order-system` ("the clicked cell has been explored"), `projectile-runtime` ("exhaustion of its maximum range"), and `gameplay-minimap` ("the same orders that the same click would issue in the gameplay area"). They carry no spec delta; the new regression tests pin them.

## Impact

- Code: `scripts/entities/EntityFactory.gd`, `scripts/core/SpatialHash.gd`, `scripts/components/ProjectileController.gd`, `scripts/core/OrderSystem.gd`, `scripts/ui/Minimap.gd`.
- Tests: `test/unit/test_ground_shot_damage.gd`, `test/unit/test_force_fire_ground.gd`.
- Process artifact: `openspec/changes/archive/2026-09-25-add-force-fire-ground-targeting/tasks.md`.
- No API, save-format, or scene changes.
