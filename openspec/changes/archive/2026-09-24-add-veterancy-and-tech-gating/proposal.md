## Why

Two core Tiberian Sun progression systems are wired up but inert. Veterancy is only half-built: `HealthComponent`, `CombatComponent` and `MovementController` all read `StatsComponent.veteran_level` and apply `GlobalRules` multipliers, but nothing ever assigns a rank — there is no kill attribution, no experience counter and no `promote()` path, so `veteran_level` is `0` for the entire game. Tech level is equally dead: `EntityData.tech_level` exists and the sidebar even sorts by it, but nothing gates on it, so every `buildable` type is available from match start. Issue #37 (`StatsComponent: Armor Lookup, Vision, Veterancy`) stalled on a proposed API (`get_armor_modifier()`) that cannot work as written and never delivered the production system these mechanics actually need.

## What Changes

- **Kill attribution plumbing.** `HealthComponent.take_damage()` gains an optional attacker source; every damage path (hitscan, projectile, collision hitbox, crush) supplies it. On death the component records the killer and emits it, so credit flows to whoever dealt the fatal blow rather than to whoever happened to still be targeting the victim.
- **New `VeterancySystem` autoload.** Receives kill events, resolves the killer's `StatsComponent`, and applies the TS credit formula `victim.cost / (killer.cost × veteran_ratio)`, clamped to `veteran_cap`. Only `Trainable` killers accumulate; allied killers receive nothing; killerless deaths (capture/sell/sink) credit nobody.
- **StatsComponent becomes the per-instance rank store.** Adds an `experience` figure, derives `veteran_level` from it at the fixed thresholds (`<1` rookie, `[1,2)` veteran, `≥2` elite), gates earning on `trainable`, and emits `veterancy_changed(level)`. `trainable` defaults on for infantry/vehicle/aircraft and off for buildings.
- **Rank sources beyond kills.** `initial_veteran` (GlobalRules) creates starting units elite. Crate/armory/TeamType promotion paths are out of scope for this change.
- **Remaining veteran consumers wired.** `veteran_sight` drives the revealer radius (re-registered on promotion), `veteran_rof` shortens weapon reload, and `SelectionOverlay` draws a rank insignia.
- **Tech-level gating.** A per-player current tech level is resolved from the scenario (campaign) or rules default (skirmish/multiplayer) onto `PlayerData.tech_level`. `PrerequisiteSystem.can_build()` follows original TS (OpenTS): `-1` means permanently unbuildable, and any positive `tech_level` requires the house's current level to be at least that value. The two buildable MCV entities currently at `-1` are migrated to a positive starting level.
- **Type helpers.** `StatsComponent.is_unit()` plus `is_infantry()/is_vehicle()/is_structure()/is_aircraft()` replace the `INFANTRY ∨ VEHICLE ∨ AIRCRAFT` predicate copied across `TurretComponent`, `EntityPlacer`, `ArtComponent`, `EntityFactory` and others.
- **Non-goals.** Elite weapon substitution (`Elite=`), veterancy crates, Armory servicing, ability-token gating (`VeteranAbilities`/`EliteAbilities`), the building-raises-house-tech-level behavior, and the `EntityData` armor-modifier API #37 originally asked for (armor resistance stays `(warhead × armor)` on `GlobalRules`/`WarheadData`).

## Capabilities

### New Capabilities

- `veterancy`: experience accumulation and rank derivation for trainable entities, kill attribution through the damage pipeline, the credit formula and its gates, rank-change signalling, the `InitialVeteran` source, and rank-insignia display.
- `tech-level`: the per-player current tech level, its scenario/session sources, and the build-list gate that compares it against `EntityData.tech_level`.

### Modified Capabilities

- `global-rules`: add the veteran sight and ROF multiplier helpers and a rules-level default tech level alongside the existing combat/speed/armor multipliers.
- `fog-of-war`: a revealer's radius reflects the owner's veteran sight multiplier and refreshes when rank changes.
- `combat-firing`: weapon reload delay is shortened by the veteran ROF multiplier.
- `entity-components`: `StatsComponent` gains identity helpers and the trainable/rank state other components read.

## Impact

Affected scripts: `scripts/components/` (`StatsComponent`, `HealthComponent`, `CombatComponent`, `VisionComponent`, `HitboxComponent`, `ProjectileController`, `MovementController`), `scripts/core/` (`PlayerManager`), `scripts/data/` (`GlobalRules`, `Mission`, `PlayerData`, `EntityData`), `scripts/production/PrerequisiteSystem`, `scripts/ui/SelectionOverlay`. `project.godot` gains the `VeterancySystem` autoload. New tests under `test/unit/` and `test/integration/`. `GLOSSARY.md` gains `experience` / `trainable` / `veteran_cap` and the current-tech-level term. Issue #37 is rescoped to match this reality.
