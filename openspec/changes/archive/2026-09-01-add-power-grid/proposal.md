# Add Power Grid

## Why

The power grid is a core Tiberian Sun mechanic and the source of the game's central resource tension: every consumer drags the grid toward deficit, and deficit punishes you by shutting down critical structures and slowing production. Today `PowerComponent` stores a signed power value on entities but nothing aggregates it — buildings function identically at any power level, radar/defense/production buildings never go offline, and there is no reason to build power plants beyond tech prerequisites (#33).

## What Changes

- **New `PowerGrid` autoload** that registers every `PowerComponent` in the scene tree (tree `node_added`/`node_removed` signals — catches player placement, map-load starting bases, and MCV deploys), maintains per-player `output`/`drain` sums (ownership via `StatsComponent.player_id`), and recomputes purely event-driven (no polling).
- **`PowerComponent` gains runtime state**: an `is_online` flag and a `power_state_changed(is_online)` signal, driven by `set_online()`. Grid state changes fan out through this per-entity signal ("signal up, call down" inside the entity).
- **Low-power behavior when a player's sum is negative** (immediate, no delay):
  - Structures with `powered = true` shut down: `CombatComponent` stops acquiring/firing, `RadarComponent` reports offline, `ArtComponent` pauses `active_anims` (resume on recovery).
  - Production **slows** (not halts): build rate interpolates between `worst_low_power_build_rate_coefficient` (0.3) and `best_low_power_build_rate_coefficient` (0.75) using the `output / drain` ratio, integrated into `ProductionManager`'s existing speed cache (invalidated via a `grid_state_changed(player_id)` signal).
- **`GlobalRules` gains the two low-power build-rate coefficients** under the existing "Production and Power Effects" group. Note: the issue lists #26 as their source, but #26 closed without delivering them — they are added here.
- **Green `"{draw}/{supply}"` label** (grid-wide drain/output totals) drawn centered in the selection bracket by `SelectionOverlay` when a building with `power > 0` (a producer) is selected. Per-frame pull query against `PowerGrid`, no signals.
- **Data pass**: `powered = true` set on the TS-faithful structure set (radars, stealth generator, firestorm generator, missile silo, temple of nod, upgrade center, laser fence posts — verified against TS `rules.ini` during implementation).
- **Deliberately deferred**: `toggle_power` behavior, power sharing radius, sidebar power bar, red-light/smoke powered-down visuals, radar-driven minimap reveal. The signal contract is designed so these bolt on later without rework.

## Capabilities

### New Capabilities
- `power-grid`: Per-player power grid aggregation, low-power state (powered-down shutdown of combat/radar/animations, low-power build rate), runtime power state propagation, and the selected-producer draw/supply label.

### Modified Capabilities
- `global-rules`: Adds a requirement for the two low-power build-rate coefficient exports (`worst_low_power_build_rate_coefficient`, `best_low_power_build_rate_coefficient`).
- `production-manager`: Adds a requirement that production speed is multiplied by the low-power build-rate coefficient while the owner's grid is in deficit.
- `combat-firing`: Adds a requirement that a structure whose power is offline does not acquire targets or fire.

## Impact

- **New files**: `scripts/core/PowerGrid.gd` (autoload), `test/unit/test_power_grid.gd`.
- **Modified scripts**: `scripts/components/PowerComponent.gd` (runtime state + signal), `scripts/production/ProductionManager.gd` (rate coefficient + cache invalidation), `scripts/components/CombatComponent.gd` (offline gate), `scripts/components/RadarComponent.gd` (operational query), `scripts/components/ArtComponent.gd` (anim pause/resume), `scripts/data/GlobalRules.gd` (coefficients), `scripts/ui/SelectionOverlay.gd` (label).
- **Data**: `resources/entities/structures/**/*.tres` — `powered = true` pass.
- **project.godot**: one new autoload entry (25th singleton).
- **Backward compatibility**: no packed-scene changes — `PowerComponent` is script-attached by `EntityFactory`; `powered` defaults to `false` so entities without the data pass are unaffected. Structures with `power = 0` and no `PowerComponent` are simply never registered. `ProductionManager` speed fallback remains 1.0 when `PowerGrid` is absent (keeps unit tests hermetic).
- **Dependencies**: none new. Relies on existing `StatsComponent.player_id` ownership and `EntityData.power`/`powered` fields (both already present).
