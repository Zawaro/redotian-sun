## Why

Units currently cross crystal (resource) fields at full speed. In Tiberian Sun,
tiberium slows movement — wheeled and amphibious units significantly — and the
slowdown must apply to both pathfinding cost and actual movement speed so units
both route around and crawl through crystal fields. Water passability is already
handled per-locomotor by the `Locomotor.terrain_speeds` model (merged as part of
the locomotor work): ground units lack a `water` entry (impassable), while
hover/ship/amphibious declare their water speed.

An earlier iteration of this change modelled movement costs as a single global
`GlobalRules.terrain_movement_costs` table. That approach was rejected: it
double-counted rough terrain, applied a uniform tiberium cost to units that TS
does not penalise (hover, fly), and its `water: 0` gate blocked hover/ship/
amphibious units that the per-locomotor model explicitly allows onto water. The
`Locomotor.terrain_speeds` model already owns per-surface movement behaviour and
is the single source of truth.

## What Changes

- Add a **`resource` land type** (not named "tiberium", because the slowdown
  applies to any resource crystal field — tiberium stays a resource name).
- Give every ground locomotor a `resource` speed in `terrain_speeds`, using the
  real TS tiberium percentages: Foot/Jumpjet `0.9`, Track/Subterranean `0.7`,
  Wheel/Amphibious `0.5`; Hover keeps `1.0` (floats above the field); Ship has
  no entry (impassable, matching TS).
- Resolve a cell to the `resource` land type whenever a resource crystal
  occupies it, reusing the existing `SpatialHash` resource-cell registry — no
  new bookkeeping in resource components, and the resolution stays in sync as
  crystals grow and are harvested.
- The penalty flows through existing systems automatically: `Pathfinder` costs
  each step at `base / speed_multiplier` and `MovementController` multiplies
  movement speed by the same multiplier. No new cost plumbing is introduced.

## Capabilities

### New Capabilities
- `resource-movement-costs`: a `resource` land type whose per-locomotor speeds
  penalise crystal-field movement in both pathfinding and actual speed.

### Modified Capabilities
- `land-types`: the `resource` land type is registered in `GlobalRules`.
- `locomotor`: every ground locomotor declares a `resource` terrain speed.
- `terrain-movement-costs`: `TerrainSystem.get_land_type()` resolves
  resource-occupied cells to `resource`.
- `pathfinder`: crystal fields now cost more per step via the per-locomotor
  multiplier (previously no terrain weight beyond height).

## Impact

- `scripts/core/TerrainSystem.gd` — `get_land_type()` resolves resource cells.
- `scripts/data/GlobalRules.gd` — no code change (resource registered in data).
- `resources/land_types/resource.tres` — new resource.
- `resources/locomotors/*.tres` — `resource` speed entries.
- `scripts/core/Pathfinder.gd` — removes the rejected global cost table and
  overlay from the earlier iteration; per-locomotor cost already applies.
- Reuses `SpatialHash` resource-cell registry (no changes to
  `ResourceComponent` / `ResourceGrowthSystem`).
- Backward compatible: maps without resource cells resolve to `clear` exactly
  as before; hover/fly behave unchanged.
