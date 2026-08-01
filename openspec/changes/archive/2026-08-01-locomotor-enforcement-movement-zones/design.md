## Context

MovementController (scripts/components/MovementController.gd) currently stores `locomotor` and `movement_zone` from EntityData but never uses them. `_slope_coefficient()` (line 83) already applies tracked/wheeled uphill-downhill modifiers from GlobalRules, and crusher logic exists (`_try_crush`, line 468). The gap: terrain passability (movement zone filtering), per-locomotor terrain speeds, hover/amphibious/jumpjet behavior, and weight-based ice. TerrainSystem is a pure heightfield — cell `type` is geometry (clear/slope 1-6), not surface material. Pathfinder (scripts/core/Pathfinder.gd) costs only occupancy + height (`0.5 × |Δh|`, line 98).

A `Locomotor` defines per-terrain-type speed multiplier + pathing cost, a crush bitset, `SharesCell`, and a hard `|Δh| > 1 level → impassable` rule. Per-unit speed is multiplied by the terrain factor — weight does not affect speed.

This change follows the repo's existing data-driven pattern: GlobalRules already holds `armor_types`, `warheads`, `resource_types` dictionaries of `.tres` resources with helper lookups. LandTypes and Locomotors slot into the same shape.

## Goals / Non-Goals

**Goals:**
- Data-driven LandType registry (surface identity, extensible — modders can add e.g. lava) and Locomotor registry, registered in GlobalRules like armor/warheads.
- Terrain passability + speed filtering per locomotor in Pathfinder and MovementController, using float speed multipliers (0.0 = impassable, 1.0 = normal, 1.2 = bonus).
- Per-locomotor climb tolerance making height cliffs impassable (the height-proxy that functions before terrain painting exists).
- Hover locomotion (ignores slope, floats at `hover_height`), Amphibious (water+land), Jumpjet hybrid (walk, or fly when unreachable/far), Subterranean hybrid (surface, or dig when unreachable/far), Fly (air only), Ship (water only), distinct Foot/Track/Wheel terrain tables.
- Submarine expressed as `Ship` + `cloakable` stealth, not a distinct type.
- Ice as a damageable terrain **entity** (like trees): weight → one-time damage → break → occupant drowns; underlying cell is water.
- Fix `_slope_coefficient()` probe to sample the next waypoint cell.
- Fix Amphibious APC / Subterranean APC `.tres` data and add `movement_zone` consistency validation.

**Non-Goals:**
- Terrain *painting* of surface types in the map editor (registry + lookups are testable without it; cells default to `clear`).
- Dedicated subterranean underground *layer* (occupancy/rendering) — the dig phase is a direct move to the target; submarine stealth behavior; naval docking; aircraft altitude (`flight_level`); hover acceleration/brake physics.

## Decisions

### D1. Two new resource classes, registered in GlobalRules

`LandType.gd` — surface identity only (all movement behavior lives in Locomotors):
- `id`, `display_name`, `color` (editor/debug).

`Locomotor.gd`:
- `id`, `terrain_speeds: Dictionary` (land_type_id → float multiplier: `0.0`/absent = impassable, `1.0` = full, `1.2` = bonus), `climb_tolerance: int` (height levels), `crushes: PackedStringArray` (documented; crush behavior already exists per-entity), `is_hover`, `is_fly`, `is_jumpjet`, `is_subterranean: bool`, `hover_height_override: float` (0 = use GlobalRules.hover_height), `jumpjet_fly_distance: float`, `subterranean_dig_distance: float` (0 = alternate mode only when the primary path is impossible). Amphibious/ship passability is driven by `terrain_speeds` water entries, not flags.

GlobalRules gains `land_types: Dictionary` and `locomotors: Dictionary` plus `get_land_type(id)` / `get_locomotor(id)` and a registry validator (mirrors `validate_warhead_armor_keys`). The entity↔registry check (unknown `locomotor` id) lives in the entity-validation layer, which can see all EntityData resources — GlobalRules cannot.

*Alternative considered:* per-terrain speed table hardcoded in a static GDScript dict. Rejected — the whole point is moddability; resources + GlobalRules registry is the established repo pattern.

### D2. Pathing cost derived from terrain speed multiplier

A cell's pathing cost multiplier = `1.0 / multiplier` (cost is inversely proportional to speed). A `clear` cell at 1.0 costs 1.0; `rough` at 0.5 costs 2.0; `water` at 0.0 is impassable. Applied on top of the existing height cost. Multipliers are floats (not percentages) to match rules.ini's decimal coefficient style (`TrackedUphill=.5`, `WheeledDownhill=1.2`).

*Alternative considered:* separate `pathing_cost` field per land-type. Rejected as redundant — multiplier already encodes preference; pathing cost derives from speed the same way.

### D3. Passability and climb tolerance live in Pathfinder, driven by the unit's Locomotor

`find_path(start_world, end_world, blocked_cells, locomotor: Locomotor = null)`:
- When `locomotor` is null → current behavior (all passable), preserving existing callers/tests.
- Otherwise each neighbor is skipped if: terrain multiplier is 0.0/absent, OR `|neighbor_height - current_height| > climb_tolerance × HEIGHT_STEP`.
- Fly/jumpjet: no terrain or height restriction. A water cell holding an intact ice entity is passable to ground locomotors (see D6).
- **Hot path**: the Locomotor's `terrain_speeds` dict is resolved once before the A* loop, and the TerrainSystem reference is cached instead of re-looked-up per neighbor (Pathfinder.gd:11 currently does a `SceneTree.root` lookup per call).

*Alternative considered:* passability as a precomputed blocked-cell dictionary in MovementController. Rejected — it recomputes per move and spreads logic across layers; the cost query is a single source of truth.

### D4. MovementController applies terrain speed + hover float + hybrids

- `_terrain_speed_factor()`: look up current cell's land type multiplier for this unit's locomotor; multiply into `step`.
- Hover (`is_hover`): slope coefficient always 1.0; position snapped to `terrain + hover_height` (via a `_hover_height` field read from GlobalRules/Locomotor) instead of `_snap_to_terrain`.
- Amphibious: identical movement math to track; water passability handled purely by D3.
- Jumpjet: in `set_target_position`, first attempt walk pathing; if the path is empty OR longer than `jumpjet_fly_distance`, build a single straight-line waypoint (fly) to the target.
- Subterranean: same hybrid shape — surface pathing first; if empty OR beyond `subterranean_dig_distance`, move directly to the target (dig), re-emerging on arrival. No underground layer exists; the dig is a direct move.
- Aircraft (`is_fly`) keep today's behavior; `Ship` moves like a ground unit over water-only cells.

*Alternative considered:* a separate flight/underground state machine. Rejected — both hybrids are "primary path with an alternate-mode fallback", expressible with one branch each.

### D5. `_slope_coefficient()` probe fix

Replace the `direction * 1.0` world-space probe (line 97) with a query at the next waypoint cell center: `CellUtil.cell_to_world(_waypoints[_spline_segment() + 1])`. Slope is a cell-boundary property; sampling a fixed 1.0 m ahead mis-measures diagonal/curved paths.

### D6. Ice as a damageable terrain entity, weight-driven

Ice is a terrain **entity** (like trees/rocks) with a `HealthComponent`, placed on a cell whose underlying land type is `water`. While intact, the ice entity provides footing: ground locomotors can path onto and occupy its cell. On cell entry, the unit deals one-time weight-proportional damage (anchored to `IceCrackingWeight=2.0`); weights below the cracking threshold deal none. When health reaches 0 the ice is destroyed, occupants are killed (drowned), and the cell reverts to water passability.

*Alternative considered:* ice as a breakable LandType with per-cell strength tracked in TerrainSystem. Rejected — it would reinvent health tracking inside a geometry system, mutate passability via land-type flips, and contradict TS data (`[TerrainTypes] ICE01-05` are objects). The entity model reuses HealthComponent, SpatialHash occupancy, and the `_try_crush` cell-transition pattern.

### D7. `movement_zone` as metadata with consistency validation

`EntityData.movement_zone` is retained as the TS pathfinding domain class but is metadata only — it never gates passability. Validation rejects contradictory pairs (e.g. `Track` + zone `Subterannean`, or `Wheel` + zone `Crusher`) to catch data drift like the SAPC's current `movement_zone = "Normal"`.

## Risks / Trade-offs

- **Ice entity must override water passability** while intact, coupling Pathfinder to a live-entity query → Mitigation: passability checks the cell's ice-occupant state via SpatialHash (already the blocking authority); scoped and tested.
- **Pathfinder signature change** could silently change behavior for callers that don't pass a locomotor → Mitigation: null default = exact current behavior; existing tests unchanged; new tests cover the populated case. Unknown `locomotor` ids `push_error` loudly in `MovementController._ready()` instead of failing silently.
- **Terrain speeds affect movement feel** (tuning risk — reference numbers are for RA, not TS) → Mitigation: values live in `.tres`, trivially tunable; the TS-feel pass is a follow-up.
- **Jumpjet/subterranean fallbacks could look like teleporting** without transition animation → Mitigation: straight-waypoint alternate paths with a minimum flight/dig phase; animation polish deferred, functional behavior correct.
- **Hover float breaks `_snap_to_terrain` assumptions** (bounds/selection) → Mitigation: hover height read once per ready, applied in `_physics_process`; existing ground units unaffected.

## Migration Plan

1. Add `LandType.gd` + `Locomotor.gd` and default `.tres` files; register in `resources/global_rules.tres`.
2. Add `land_types`/`locomotors` dictionaries + helpers to GlobalRules; keep old fields.
3. Extend TerrainSystem with a per-cell land-type overlay (default `clear`).
4. Create the ice terrain entity (`.tres` + scene) with HealthComponent; underlying cells use the `water` land type.
5. Extend Pathfinder (D3) and MovementController (D4/D5) with null-locomotor backward-compatible paths.
6. Fix Amphibious APC (`locomotor = "Amphibious"`) and Subterranean APC (`locomotor = "Subterranean"`, `movement_zone = "Subterannean"`) `.tres` data; add zone-consistency validation.
7. Update `.tres` entity files (Hover MLRS, Jumpjet Infantry) to reference registered values.
8. Land on `feat/34-locomotor-enforcement-movement-zones`, archive the OpenSpec change.

Rollback: revert the two resource classes + GlobalRules registry additions; null-locomotor defaults preserve prior behavior.

## Open Questions

- Default terrain-speed multipliers for TS units (start from a reference table, tune later)?
- Ice strength / weight-damage curve — start from `IceCrackingWeight=2.0` as anchors; confirm feel in playtest.
- Should `Foot` be able to cross `water` in a future naval pass (TS infantry cannot; flag for later)?
- Whether `movement_zone` should eventually be removed entirely once its consistency validation proves out.
