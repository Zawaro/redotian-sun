## Why

When a unit attacks a building, `CombatComponent` measures horizontal distance to `_target.global_position`, which for a building is the **center** of its foundation footprint. Range, approach destination, and facing all key off that center point, so a short-range attacker must walk around and hug the wall until the footprint **center** enters weapon range instead of stopping as soon as the nearest foundation edge is in range. Large structures (construction yard, refinery) make it worst: the attacker closes into defensive fire to satisfy a check it should already satisfy. Tiberian Sun engages a building while any foundation cell is in range.

## What Changes

- Measure engagement range to the **nearest point on the target's foundation footprint** (a clamped projection onto the footprint rectangle) for targets that are structures (`StatsComponent.is_structure()`) and have a `FoundationComponent`; all other targets keep measuring to `global_position`.
- Compute the chase stop position and its in-range pull-back against that same nearest point, so an attacker stops `range` from the nearest wall instead of `range` from the center.
- Slew body facing and `yaw_free` turrets toward the nearest footprint point for building targets.
- Apply the same nearest-footprint measurement to `GuardComponent` acquisition so hold-ground guards and ordered attacks agree on whether a building is in range; widen the guard scan hood by a bounded margin because `SpatialHash` indexes entities at their centre cell.
- Extend a physical projectile's maximum range by the target foundation's half-diagonal, so a shot fired from nearest-edge range still reaches the (further) footprint centre instead of fizzling at the wall.
- Add `FoundationComponent.nearest_world_point(from)` as the single shared nearest-point primitive.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `combat-firing`: range checking and chase-stop/approach geometry measure to the nearest foundation point for structure targets; non-structure multi-cell entities measure as points.
- `combat-facing`: body and turret facing slew toward the nearest foundation point for building targets.
- `foundation-component`: new query for the nearest world-space point on a foundation footprint.
- `guard-auto-engage`: acquisition distance to building candidates uses the nearest foundation point, with a widened hood margin.
- `projectile-runtime`: max range is extended by the target foundation half-diagonal for structure targets.

## Impact

- `scripts/components/CombatComponent.gd` — `_horizontal_distance`, `_effective_target_pos`, approach (`_move_toward_target`), turret aim (`_aim_turrets`, `_tick_channel`), body facing (`_is_facing_target`).
- `scripts/components/GuardComponent.gd` — `_find_nearest_enemy` distance/range filter and hood margin.
- `scripts/components/ProjectileController.gd` — `setup` extends `_max_range` for structure targets.
- `scripts/components/FoundationComponent.gd` — new `nearest_world_point(from)`.
- Tests: `test/unit/test_foundation_component.gd`, `test/unit/test_combat_component.gd`, `test/unit/test_combat_component_jumpjet.gd`, `test/unit/test_guard_component.gd`, `test/integration/test_projectile_flight.gd`.
- No scene (`.tscn`) or data (`.tres`) changes; no save/load format impact.
- 1x1 buildings are unaffected: `EntityFactory` only attaches `FoundationComponent` when `foundation != Vector2i(1, 1)`.
- Known ceiling: the footprint rectangle is derived from `global_position ± foundation/2` and ignores `rotation_y`; this matches existing foundation cell registration, which already ignores rotation. Arbitrary non-axis-aligned rotation stays out of scope.
- Known ceiling: projectiles still fly to the footprint centre (through the wall); a foundation-sized building hitbox would remove that visual artifact, tracked as a follow-up.
