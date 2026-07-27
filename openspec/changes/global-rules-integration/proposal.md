## Why

`GlobalRules` (loaded from `resources/global_rules.tres`) defines every tunable balance value — armor modifiers, veterancy bonuses, movement coefficients, production and repair constants — but almost nothing reads from it. Balance values are instead hardcoded in scattered places (`EntityData.BUILD_SPEED`, a literal `0.25` factory bonus, a literal `8` HP repair step, no armor math at all), so tuning the game means editing code in several files instead of one resource. This change wires the existing values into the gameplay systems that should consume them.

## What Changes

- **Damage now respects armor**: `HealthComponent.take_damage()` looks up the target's armor type in `GlobalRules.armor_types` and applies the modifier, with a guaranteed minimum of 1 damage.
- **Veterancy multipliers apply**: `StatsComponent` gains a `veteran_level` field; incoming damage is reduced by `veteran_armor`, movement speed is boosted by `veteran_speed`, and `CombatComponent` exposes veteran-scaled weapon damage via `veteran_combat`.
- **Terrain slope affects movement**: `MovementController` reads its `locomotor` (wired from `EntityData`) and the local terrain grade, applying tracked/wheeled uphill/downhill coefficients to speed.
- **Production constants sourced from rules**: `ProductionManager` uses `build_speed` and `multiple_factory` from `GlobalRules` instead of the hardcoded constant and literal, removing the duplicate `EntityData.BUILD_SPEED`.
- **Repair step sourced from rules**: `BuildingManager.repair_building()` heals `repair_step` HP from `GlobalRules` instead of a literal `8`.
- All balance math is centralized as pure helper methods on `GlobalRules`, making it the single source of truth and independently testable.

## Capabilities

### New Capabilities
- `global-rules-integration`: Defines how gameplay systems (health/damage, veterancy, movement, production, repair) consume `GlobalRules` values at runtime, and the centralized helper methods that compute the derived values.

### Modified Capabilities
<!-- No existing spec's REQUIREMENTS change; the global-rules spec still describes the resource itself. This change adds consumption behavior as a new capability. -->

## Impact

- **Scripts**: `scripts/data/GlobalRules.gd` (new helper methods), `scripts/components/HealthComponent.gd`, `scripts/components/StatsComponent.gd`, `scripts/components/MovementController.gd`, `scripts/components/CombatComponent.gd`, `scripts/production/ProductionManager.gd`, `scripts/data/EntityData.gd`, `scripts/buildings/BuildingManager.gd`.
- **Runtime access**: components read the singleton via the established `EntityFactory.get_global_rules()` pattern; all reads guard against a null result and fall back to prior behavior.
- **Backward compatibility**: no `.tscn` or resource schema changes; `veteran_level` defaults to 0 so existing entities are unaffected. `EntityData.get_build_time()` keeps its constant fallback for callers that pass no rules.
- **Tests**: new unit tests for the `GlobalRules` helpers and the `HealthComponent` armor/veterancy path.
