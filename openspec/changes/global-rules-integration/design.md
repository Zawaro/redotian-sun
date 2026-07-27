## Context

`GlobalRules` is a `Resource` holding every balance value, loaded once by the `EntityFactory` autoload and reachable everywhere via `EntityFactory.get_global_rules()` — the pattern already used by `HarvestComponent`, `ResourceComponent`, `DockUnloadComponent`, and `PlayerManager`. The values exist but the consuming systems either ignore them or hardcode equivalents:

- `HealthComponent.take_damage()` subtracts raw damage — no armor math at all.
- `StatsComponent` has no veterancy field; no system applies veteran bonuses.
- `MovementController` never receives `locomotor` from `EntityData` and ignores terrain slope.
- `ProductionManager._get_production_speed()` returns a hardcoded `1.0 + (count-1)*0.25`; `EntityData.get_build_time()` bakes in a private `BUILD_SPEED = 0.8` constant duplicating `GlobalRules.build_speed`.
- `BuildingManager.repair_building()` heals a literal `8` HP.

The combat firing path (`CombatComponent._attack`) is still a stub, so no weapon currently deals damage through the pipeline. Damage today reaches `HealthComponent` only via projectile hitboxes (`HitboxComponent`), crushing (`kill()`), and resource harvesting.

## Goals / Non-Goals

**Goals:**
- Make `GlobalRules` the single source of truth for armor, veterancy, movement-slope, production, and repair math.
- Wire each value into the system that should read it, guarding against a null rules singleton.
- Keep all derived-value math as pure, independently testable helper methods on `GlobalRules`.
- No behavior change for existing content: defaults (`veteran_level = 0`, armor `"none"` → 1.0) must leave current gameplay identical.

**Non-Goals:**
- Building the combat firing pipeline (weapons dealing damage) — out of scope; `CombatComponent` only gains a veteran-scaled damage accessor for the future firing code.
- A continuous auto-repair tick driver. Repair is currently order-triggered (one heal per repair order). We source `repair_step` from rules; `repair_rate` (tick interval) remains unused until an auto-repair driver exists.
- Wiring `move_speed` from `EntityData.speed` (units currently use the controller default) — that is a separate movement concern, not a `GlobalRules` value.
- `WarheadData.armor_damage_multipliers` per-warhead damage tables — these belong to the combat firing path; this change uses the simpler per-target `armor_types` modifier the issue specifies.

## Decisions

**1. Centralize math on `GlobalRules` as pure methods.**
Each formula becomes a method on the resource, so it can be unit-tested by instantiating `GlobalRules.new()` with no scene tree:
- `compute_final_damage(base_damage, armor_type, veteran_level) -> int` — applies armor modifier and veteran armor reduction, floors at 1 for any positive input.
- `veteran_combat_multiplier(level)`, `veteran_speed_multiplier(level)`, `veteran_armor_multiplier(level)` — additive-percentage multipliers, level clamped to `veteran_cap`.
- `production_speed_multiplier(factory_count)` — `1.0 + max(0, count-1) * multiple_factory`.
- `movement_slope_coefficient(locomotor, grade)` — tracked/wheeled uphill/downhill interpolation; unknown locomotor returns 1.0.

*Why:* keeps consumers thin, avoids duplicating the same arithmetic across five files, and makes the balance logic the testable unit. Alternative (inline math in each component) was rejected — it re-scatters the very constants this change consolidates.

**2. Armor uses per-target `armor_types` modifier, not per-warhead tables.**
The issue specifies `armor_types[armor][modifier]` keyed on the *target's* `StatsComponent.armor`. `HealthComponent` resolves its sibling `StatsComponent` and the rules singleton lazily (cached), applying `compute_final_damage`. Resources/harvesting pass through unchanged because their armor is `"none"` (modifier 1.0). *Why not `WarheadData` tables:* that requires the not-yet-built firing path to supply a resolved warhead; the per-target modifier is the coherent slice available today and matches the issue.

**3. Veterancy split by where it is observable today.**
`veteran_armor` (damage taken) and `veteran_speed` (movement) are wired live because those paths exist. `veteran_combat` is exposed as `CombatComponent.get_effective_damage(weapon)` for the firing code to consume later — added now so the field is not dead, but not forced through a nonexistent damage path.

**4. Production: inject `build_speed`, source `multiple_factory`.**
`EntityData.get_build_time(build_speed := BUILD_SPEED)` gains an optional parameter; `ProductionManager` passes `rules.build_speed`, so the resource wins at runtime while the constant remains a safe fallback for tests and non-production callers. `_get_production_speed` uses `rules.production_speed_multiplier(count)`. Both guard against a null rules result and fall back to prior behavior.

**5. Movement locomotor wired via a new `configure()`.**
`MovementController` gains `configure(data)` (auto-invoked by `EntityFactory._configure_components`) setting `locomotor`/`movement_zone` from `EntityData`. Per frame while moving, it samples the terrain grade ahead and multiplies speed by `movement_slope_coefficient`. `veteran_speed` scales `move_speed` once in `_ready`.

## Risks / Trade-offs

- **Signal semantics change**: `HealthComponent.damage_taken` will emit the post-armor amount instead of the raw amount. → Acceptable and more correct; no consumer relies on the raw value for anything but display.
- **Minimum-1-damage floor on harvesting**: resource armor is `"none"` (1.0) and harvest damage far exceeds 1, so the floor never raises harvest damage. → Verified by tracing the three `take_damage` callers.
- **Null rules singleton in tests/headless**: every consumer guards `if rules:` and falls back to prior behavior. → Pure helpers are tested directly on a `GlobalRules.new()` instance, independent of the autoload.
- **Slope sampling cost**: one extra terrain height sample per moving unit per frame. → Negligible; `MovementController` already samples terrain height every frame.

## Migration Plan

Purely additive to code; no resource/scene schema changes. `veteran_level` defaults to 0 and armor `"none"` is identity, so shipped content behaves identically. Rollback is reverting the scripts — no data migration.

## Open Questions

- Exact `multiple_factory` balance (0.5 vs the previous implicit 0.25) is a tuning decision now owned by `global_rules.tres`; the code simply reads whatever the resource holds.
