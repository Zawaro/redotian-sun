# Armor Type System

## Why

Damage is applied flat — `HealthComponent.take_damage(weapon.damage, ...)` subtracts raw weapon damage with no armor math. The balance data for armor already exists in `references/rules.ini` (`Armor=` classes on units, `Verses=` damage-per-armor percentages on warheads), but nothing consumes it. `GlobalRules.armor_types` is a hardcoded scalar dictionary that does not match the source data model, and `WarheadData.armor_damage_multipliers` is a positional array that silently breaks if armor classes are ever added. Tuning combat means editing code, and the game plays like every unit has no armor.

## What Changes

- **New `ArmorType` resource class** (`ArmorType extends Resource`, mirroring `ResourceType`): id, display_name, color. Armor classes become data — 5 `.tres` files (`none`, `wood`, `light`, `heavy`, `concrete`), extensible without schema changes.
- **`GlobalRules.armor_types` becomes a registry** mapping armor id → `ArmorType` resource (replaces the hardcoded `{name: {modifier: float}}` dict).
- **`WarheadData.armor_damage_multipliers` becomes a keyed Dictionary** `{armor_id: float}` (replaces the positional `PackedFloat32Array[5]`). Values mirror rules.ini `Verses=` percentages.
- **Warhead data population**: ~20 warhead `.tres` files authored from `references/rules.ini` `Verses=` lines.
- **Warhead registry on GlobalRules**: `warheads: Dictionary` mapping warhead id → `WarheadData`, mirroring `resource_types`.
- **Per-warhead damage resolution**: `CombatComponent` resolves `weapon.warhead` → `WarheadData`, looks up the target's `StatsComponent.armor` in the warhead's multiplier dict, applies the modifier to `weapon.damage`, and clamps to `[min_damage, max_damage]` (from rules.ini `[CombatDamage]` MinDamage=1 / MaxDamage=1000). **BREAKING**: `take_damage` receives the final computed damage instead of raw weapon damage.
- **`GlobalRules` gains `min_damage` / `max_damage`** fields.
- **Non-armor GlobalRules wiring** (carried from PR #157, redesigned to fit the new armor model): veterancy multipliers apply (veteran_combat on attacker damage, veteran_armor on incoming damage, veteran_speed on movement), movement slope coefficients (tracked/wheeled uphill/downhill) apply from terrain grade, production reads `build_speed` / `multiple_factory`, repair reads `repair_step`.
- **Specs updated**: `global-rules` (armor type database requirement, veterancy/movement/production/repair consumption) and `combat-firing` (hitscan damage application requirement) reflect the new model.

## Capabilities

### New Capabilities
- `armor-types`: ArmorType resource class, armor type `.tres` data files, and the GlobalRules armor type registry with lookup/validation accessors.

### Modified Capabilities
- `global-rules`: armor_types becomes a registry of ArmorType resources keyed by id (replacing the scalar modifier dict); adds a warhead registry, `min_damage`/`max_damage`, and `get_warhead()`/`get_armor_type()` accessors.
- `combat-firing`: hitscan damage application resolves the weapon's warhead against the target's armor type and applies the clamped modifier before calling `take_damage`.

## Impact

- `scripts/data/ArmorType.gd` — new resource class
- `scripts/data/GlobalRules.gd` — registry types, new fields, accessors
- `scripts/data/WarheadData.gd` — keyed multiplier dict, validate() changes
- `scripts/components/CombatComponent.gd` — warhead/armor resolution in `_fire_weapon`
- `resources/global_rules.tres` — armor type + warhead registry entries
- `resources/armor_types/*.tres` — 5 new armor data files
- `resources/warheads/*.tres` — ~20 new warhead data files
- `scripts/components/StatsComponent.gd` — `veteran_level` field
- `scripts/components/MovementController.gd` — veteran_speed + slope coefficients
- `scripts/buildings/BuildingManager.gd` — repair_step consumption
- `scripts/production/ProductionManager.gd` — build_speed / multiple_factory consumption
- `openspec/specs/global-rules/spec.md`, `openspec/specs/combat-firing/spec.md` — requirement updates
- No `.tscn` scene changes; `StatsComponent.armor` and `EntityData.armor` remain the armor type source
