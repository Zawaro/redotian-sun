## Context

Movement behaviour is owned by the `Locomotor` registry (merged before this
change): each locomotor declares `terrain_speeds` — land type id → speed
multiplier, where `0.0`/absent = impassable. Two consumers read it:

- `Pathfinder.find_path()` gates passability via
  `Locomotor.is_passable(land)` and weights each step at `base / multiplier`
  through `_cost_multiplier()`.
- `MovementController._terrain_speed_factor()` multiplies per-frame speed by
  `get_speed_multiplier(TerrainSystem.get_land_type(cell))`.

`TerrainSystem.get_land_type(cell)` returns the painted land-type overlay
(`_land_types`) or `DEFAULT_LAND_TYPE` (`"clear"`).

`SpatialHash` already tracks occupied resource crystal cells via
`register_resource_cell` / `unregister_resource_cell`, driven by
`ResourceComponent` on spawn and depletion. `has_resource_cell(cell)` queries it
in the same grid-index space `get_land_type` receives.

The earlier iteration of this change added a global
`GlobalRules.terrain_movement_costs` table (`{"clear":100, "rough":160,
"tiberium":120, "water":0}`) plus a parallel `TerrainSystem._terrain_types`
overlay. Review against the per-locomotor model rejected it: the table
double-counted rough (global 1.6× on top of the per-locomotor inverse), applied a
uniform tiberium cost that matches no real TS value and penalised hover/fly, and
its unconditional `water: 0` gate blocked hover/ship/amphibious units whose
`terrain_speeds` explicitly permit water — making their water entries dead code
and short-circuiting the intact-ice footing feature.

## Goals / Non-Goals

**Goals:**
- Crystal (resource) fields slow ground units in both path cost and movement
  speed, using real TS percentages.
- Resource resolution derives from the existing `SpatialHash` registry, stays in
  sync on growth/harvest, and requires no resource-component changes.
- Remove the rejected global table and parallel overlay from the earlier
  iteration.

**Non-Goals:**
- A terrain-painting UI in the map editor.
- A separate movement-cost table — `terrain_speeds` is the single source of
  truth (`base / multiplier` is the cost).
- Distinguishing tiberium from other resource categories (e.g. TS veins/weeds);
  one `resource` land type covers all registered crystal cells.
- Penalising hover/fly over crystal fields (they do not contact the ground; TS
  keeps hover at 100%).

## Decisions

**1. Name the land type `resource`, not `tiberium`.**
The penalty applies to any registered resource crystal cell, and "tiberium"
already names a specific resource in this codebase. `resource` keeps the surface
concept separate from the resource name. Real TS values are used for the speeds.

**2. Per-locomotor `resource` speeds, applied to every ground locomotor.**
`terrain_speeds` gain a `resource` entry using the TS tiberium percentages:
Foot/Jumpjet `0.9`, Track/Subterranean `0.7`, Wheel/Amphibious `0.5`. Hover
declares `1.0` explicitly (floats above the field). Ship keeps no entry
(impassable, TS Float = 0%). Fly needs none (airborne). `is_passable` and
`get_speed_multiplier` need no changes — they already consume the table.

**3. `TerrainSystem.get_land_type()` resolves resource-occupied cells.**
Before the painted overlay, if `SpatialHash.instance.has_resource_cell(cell)`
then return `RESOURCE_LAND_TYPE`. The registry is the single source of truth, so
a harvested crystal instantly reverts the cell to its painted/default type. The
check is an O(1) dictionary lookup, null-guarded; it replaces the earlier
iteration's separate `_terrain_types` overlay and the pathfinder's
`_terrain_type_for` bridge. This also fixes a latent bug from the earlier
iteration, where `MovementController` never saw crystal fields (it reads
`get_land_type`, not the pathfinder overlay) — units detoured around crystals at
full pathing cost yet crossed them at full speed. Now both consumers agree.

**4. `Pathfinder` cost is the per-locomotor inverse — no new plumbing.**
`_cost_multiplier()` already returns `1.0 / get_speed_multiplier(land)`, so a
wheeled unit crossing a `resource` cell pays `2.0×` per step once the land type
resolves. Water passability stays per-locomotor: ground units lack a `water`
entry, hover/ship/amphibious declare theirs. The earlier iteration's
`terrain_cost` table, `_get_terrain_costs()`, `_terrain_type_for()`, and the
global `<= 0` impassable gate are removed.

**5. No map-JSON changes.**
The earlier iteration persisted `terrain_types` in the map JSON. Resource
resolution is now derived at runtime from the `SpatialHash` registry, which is
already populated by `ResourceComponent`, so no serialization is needed.

## Risks / Trade-offs

- [Resource lookup adds a dictionary read per `get_land_type` call] →
  `has_resource_cell` is O(1) and the call already did an overlay lookup;
  negligible next to the A* loop and per-frame speed factor.
- [Foot/Tracked slowed even though TS keeps them at clear speed on tiberium] →
  Accepted per product direction: every ground unit should feel the penalty.
  Values remain TS-derived and ordered (wheel < tracked < foot).
- [Removing the global table changes water behaviour for pathing without a
  locomotor] → Intentional: `find_path` without a locomotor means no passability
  filtering (documented in the pathfinder spec); units always supply their
  locomotor in practice.
