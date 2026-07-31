# Armor Type System — Design

## Context

Damage currently bypasses armor entirely: `CombatComponent._fire_weapon()` calls
`health.take_damage(weapon.damage, weapon.warhead)` (raw damage), and
`HealthComponent.take_damage()` subtracts it unchanged. The balance source of truth
(`references/rules.ini`) defines:

- Per-entity armor classes: `Armor=none/wood/light/heavy/concrete`
- Per-warhead damage percentages: `Verses=none%,wood%,light%,heavy%,concrete%`
  (e.g. `[SA] Verses=100%,60%,40%,25%,10%`, `[AP] Verses=25%,65%,75%,100%,60%`)
- Global clamps: `[CombatDamage] MinDamage=1`, `MaxDamage=1000`

The existing `GlobalRules.armor_types` dict (`{name: {modifier: float}}`) is a
fabricated scalar abstraction that does not exist in the source data and cannot
express per-warhead differences. `WarheadData.armor_damage_multipliers` is a
positional `PackedFloat32Array[5]` that couples every warhead to the exact 5-class
convention — adding an armor class breaks every warhead resource.

A parallel unmerged effort (PR #157) wires GlobalRules veterancy/movement/production/
repair values; its armor section is being replaced by this design.

## Goals / Non-Goals

**Goals:**
- Armor classes become data: an `ArmorType` resource (id, display_name, color) mirroring the existing `ResourceType` pattern, so new armor classes are added by dropping a `.tres` — no schema or code change.
- Warhead armor multipliers become a keyed dictionary `{armor_id: percentage}`, populated faithfully from rules.ini `Verses=` values.
- `CombatComponent` resolves `weapon.warhead` → `WarheadData`, multiplies base damage by the percentage for the target's `StatsComponent.armor`, and clamps to `[min_damage, max_damage]`.
- `GlobalRules` becomes the single registry for armor types and warheads (mirroring `resource_types`).
- Wire the remaining GlobalRules values (veterancy, movement slope, production, repair) into their consumers.
- Backward-compatible defaults: unknown armor/warhead ids resolve to 1.0 (full damage); existing entities keep `armor = "none"`.

**Non-Goals:**
- No `ArmorComponent` — `StatsComponent.armor` stays the armor source. OpenRA-style multi-armor stacking, conditionally-disabled armor, and per-hit-shape armor types are explicitly deferred.
- No projectile visuals, death explosions, auto-repair tick driver, or veterancy *promotion* from kills — those are separate changes (#186, #187, veterancy promotion).
- No difficulty-scaled house armor multipliers (`[Easy]/[Normal]/[Difficult]`).

## Decisions

### D1: `ArmorType` resource class (new data type)
New `scripts/data/ArmorType.gd` (`class_name ArmorType extends Resource`) with
`id`, `display_name`, `color`. Five `.tres` files under `resources/armor_types/`
(`none`, `wood`, `light`, `heavy`, `concrete`). Registered in `GlobalRules.armor_types`
as `{id: ArmorType}`, exactly like `resource_types` is today.
- *Why:* TS hardcodes the armor class list; making it data is the entire point. The `ResourceType` pattern already proves the registry approach in this codebase.
- *Alternative considered:* keep the scalar `{modifier}` dict. Rejected — it cannot represent per-warhead behavior and doesn't exist in the source.

### D2: Warhead multipliers keyed by armor id
`WarheadData.armor_damage_multipliers` changes from `PackedFloat32Array[5]` to a
`Dictionary` `{armor_id: float}` (0.0–6.0, values from `Verses=` percentages). `validate()`
checks every key exists in `GlobalRules.armor_types` and every registered armor type has an entry.
- *Why:* keyed lookup is order-independent and survives armor-class additions. Percentage > 1.0 is valid (e.g. Fire=600%) — overkill warheads exist.
- *Alternative considered:* keep positional array + index constant. Rejected — that's exactly the TS hardcode we're removing.

### D3: Damage resolution in CombatComponent (attacker-side)
`_fire_weapon()` resolves `weapon.warhead` via `GlobalRules.get_warhead()`, looks up
`armor_damage_multipliers[target_stats.armor]` (default 1.0 on miss), computes
`final = clampi(round(weapon.damage * multiplier), min_damage, max_damage)`, then calls
`health.take_damage(final, weapon.warhead)`.
- *Why:* the attacker owns the weapon/warhead; the defender only knows its own armor. This is the source-data model (`Verses` is a warhead property).
- *Alternative considered:* resolve in `HealthComponent.take_damage()` by `damage_type` string (PR #157's approach). Rejected — it makes the defender depend on the full warhead registry and can't express attacker-specific context.

### D4: GlobalRules registries + clamps
`GlobalRules` gains: `armor_types` (repurposed to `{id: ArmorType}`), `warheads` (`{id: WarheadData}`), `min_damage: int = 1`, `max_damage: int = 1000`, and accessors
`get_armor_type(id)`, `get_warhead(id)`, `get_armor_ids()`.
- *Why:* one registry for all tunable data, mirroring `resource_types`; no new autoload needed.
- *Alternative considered:* separate autoload for warheads. Rejected — symmetry and fewer singletons.

### D5: Remaining GlobalRules wiring (from PR #157 approach)
- `StatsComponent.veteran_level: int = 0`; `HealthComponent` reduces incoming damage by `veteran_armor_multiplier(level)`.
- `MovementController` scales speed by `veteran_speed_multiplier(level)` and applies tracked/wheeled uphill/downhill slope coefficients from terrain grade.
- `ProductionManager` reads `build_speed` and `multiple_factory`; `EntityData.get_build_time()` accepts an optional build_speed.
- `BuildingManager.repair_building()` heals `repair_step` from rules.
- `CombatComponent.get_effective_damage()` exposes `veteran_combat` scaling for the firing path.
- *Why:* these values are defined but unused; wiring them makes GlobalRules the single source of truth. No behavior change for defaults.

## Risks / Trade-offs

- [Positional→keyed migration could break other WarheadData readers] → only `sonicwarhead.tres` exists; grep confirms no production readers of `armor_damage_multipliers` outside `validate()`. Migration is one resource file.
- [Existing entities with `armor` strings not in the registry] → `get_armor_type()` and the multiplier lookup default to full damage (1.0); `validate()` warns but doesn't crash.
- [Rounding changes damage slightly vs. float math] → use `round()` to keep integer health; rules.ini health is integer. `DamageVersus` in the reference engine also integer-izes.
- [Warhead data population is large (~20 .tres)] → mechanical, driven by the `Verses=` table; only warheads actually referenced by weapon `.tres` files are populated.
- [`take_damage` semantics change (post-armor value)] → no consumer relies on the raw value for logic; debug UI reads `current_health`.

## Migration Plan

1. Add `ArmorType` class + 5 armor `.tres`; register in `global_rules.tres`.
2. Rework `WarheadData` to keyed dict; author ~20 warhead `.tres` from `Verses=`.
3. Add `GlobalRules` registries, clamps, accessors; wire into `CombatComponent._fire_weapon`.
4. Apply remaining wiring (veterancy/movement/production/repair).
5. Update `global-rules` and `combat-firing` specs; add unit tests (multiplier lookup, min/max clamp, 0%-armor, unknown ids, veterancy, slope).
6. Rollback = revert the scripts + resources; no scene/schema migration.
