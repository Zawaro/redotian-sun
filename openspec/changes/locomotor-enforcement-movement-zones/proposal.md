## Why

All units move identically regardless of being tracked, wheeled, hover, or on foot. The `locomotor` and `movement_zone` fields exist on `EntityData` and are populated in `.tres` files but are never consumed beyond storing them, so terrain type, slope, water, and weight have no gameplay effect. This is GH issue #34.

## What Changes

- Introduce a data-driven **LandType registry** — fully customizable terrain surface types (e.g. clear, rough, road, water, cliff, and modder-defined ones like lava). LandTypes are surface identity only (id, name, color); movement behavior lives in the Locomotor registry. Replaces the current height-only terrain model.
- Introduce a **Locomotor registry** with all TS locomotor types plus naval and future-proofed types: `Foot`, `Track`, `Wheel`, `Hover`, `Amphibious`, `Fly` (Winged), `Jumpjet`, `Subterranean`, and `Ship`. Each defines a **float-multiplier terrain speed table** (0.0 = impassable, 1.0 = normal, 1.2 = bonus), climb tolerance, crush set, and behavior flags. A submarine is a `Ship` with stealth (`cloakable`), not a distinct type.
- **Movement zone filtering** in `Pathfinder`/`MovementController`: cells impassable to a unit's locomotor are excluded from pathing; a per-locomotor **climb tolerance** makes height cliffs impassable (`|Δh| > tolerance → blocked`, the height-proxy that works before LandTypes land).
- **Hover locomotion**: ignores slope coefficients, floats at `GlobalRules.hover_height` (boost on straightaways deferred by the issue).
- **Amphibious locomotion**: passes water and land; applied to the GDI Amphibious APC.
- **Jumpjet hybrid**: walks like foot by default, but flies straight to the target when unreachable by walking or beyond `jumpjet_fly_distance`; pure aircraft (`Fly`) never walk.
- **Subterranean hybrid**: travels on the surface like Track up to `subterranean_dig_distance`, and digs directly to the target beyond that or when no surface path exists.
- **Ice + weight**: ice is a damageable terrain **entity** (like trees) whose underlying cell is water. A unit entering its cell deals one-time weight-proportional damage (anchored to `IceCrackingWeight`); when the ice breaks, occupants drown and the cell reverts to water passability.
- Fix `_slope_coefficient()` probe in `MovementController` to sample the next waypoint cell instead of 1.0 m ahead.
- Fix entity data errors: Nod Subterranean APC (`movement_zone = "Normal"`, `locomotor = "Track"`) and GDI Amphibious APC (`locomotor = "Track"`) do not match rules.ini.
- Add `movement_zone` consistency validation so contradictory locomotor/zone pairs (e.g. the SAPC) fail loudly.

## Capabilities

### New Capabilities
- `land-types`: LandType registry resource — surface identity (id, name, color), fully customizable and extensible at runtime.
- `locomotor`: Locomotor registry + all locomotor types and their props (float terrain-speed multipliers, climb tolerance, crush set, hover/amphibious/jumpjet/subterranean/ship behavior) + movement zone filtering in pathfinding.
- `ice-drowning`: ice as a damageable terrain entity with weight-based damage and occupant drowning.

### Modified Capabilities
- `pathfinder`: add per-locomotor climb tolerance as a hard impassability check (height discontinuity), and terrain passability filtering via the LandType registry.
- `entity-data`: `locomotor` and `movement_zone` gain enumerated semantics with consistency validation; `weight` gains documented meaning (ice damage, not speed); submarine = `Ship` + `cloakable`.

## Impact

- **New resources**: `LandType.gd` (+ `.tres` files), `Locomotor.gd` (+ `.tres` files), ice terrain entity (`.tres` + scene), registered in `resources/global_rules.tres` as dictionaries (mirrors existing `armor_types` / `warheads` / `resource_types` pattern).
- **Modified scripts**: `scripts/core/Pathfinder.gd` (climb tolerance + passability), `scripts/core/TerrainSystem.gd` (land-type lookup), `scripts/components/MovementController.gd` (hover float, amphibious, jumpjet/subterranean hybrids, slope probe fix, weight-based ice damage), `scripts/data/GlobalRules.gd` (registries + helpers), `scripts/data/EntityData.gd` (validation).
- **Modified resources**: `resources/global_rules.tres`, affected `.tres` entity files (Amphibious APC, Subterranean APC, Hover MLRS, Jumpjet Infantry).
- **New/updated specs**: `openspec/specs/land-types/`, `locomotor/`, `ice-drowning/`; deltas to `pathfinder/`, `entity-data/`.
- **Tests**: unit tests for climb tolerance, passability filtering, hover float, jumpjet/subterranean hybrids, ice entity break/drown, and registry validation.
- Terrain surface types (e.g. `water`) require terrain-painting (map editor) work to appear on real maps; the height-proxy and registries are testable immediately.
