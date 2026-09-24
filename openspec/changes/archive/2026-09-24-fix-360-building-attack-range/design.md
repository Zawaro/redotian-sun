## Context

`CombatComponent` resolves engagement geometry against `_target.global_position`. For a building that position is the foundation-footprint center, because both `BuildingManager._cell_origin_to_world` and `MapLoader.placement_position` place buildings at `CellUtil.cell_origin_to_world(origin, foundation)` — the footprint center. Three families of behavior key off it:

- range (`_horizontal_distance` → `_target_in_range`, `_channel_in_range`, the `close` threshold),
- approach (`_move_toward_target`, ground and jumpjet branches, including the post-relocation range pull-back),
- facing (`_is_facing_target`, `_aim_turrets`, per-channel turret slew).

A 4x4 building's nearest edge can be 4 world units closer than its center, so short-range attackers close that much too far. `GuardComponent._find_nearest_enemy` independently measures to `other.global_position` and has the same center assumption. Tiberian Sun engages a building while any foundation cell is in range.

A second consumer interacts with the same geometry: `ProjectileController` flies to `_target.global_position` (the footprint center) and caps flight at `weapon.attack_range * CELL_SIZE`. Once the attacker stops at range from the nearest edge, the center sits `half_extent` further, so a physical projectile fizzles at the wall before dealing damage. The building hitbox is a 2x2 centered box (`HitboxComponent.size` default; no content sets `hitbox_size`), so the motion cast cannot catch the wall early either.

The footprint is an axis-aligned cell rectangle in world XZ (`CellUtil.cell_to_world` is a linear lattice, `CELL_SIZE = 2`). `EntityFactory._add_foundation_component` attaches `FoundationComponent` only when `foundation != Vector2i(1, 1)`, so 1x1 buildings and all units have no component and keep point semantics for free.

## Goals / Non-Goals

**Goals:**
- Range, approach destination, and facing for building targets key off the nearest point on the footprint.
- One shared nearest-point primitive, used by both `CombatComponent` and `GuardComponent` so they cannot disagree.
- Non-building targets and 1x1 buildings behave exactly as before.
- Cost stays O(1) per query, no per-frame iteration over foundation cells or the entity set.

**Non-Goals:**
- Rotated (non-axis-aligned) footprints. Foundation cell registration already ignores `rotation_y`; this design stays consistent with it rather than fixing rotation.
- A foundation-sized building hitbox. Projectiles still fly to the footprint centre (through the wall) and detonate there; sizing the hitbox to the foundation would remove that visual artifact but touches hit detection broadly. Tracked as a follow-up.
- The move-line endpoint still points at the footprint centre. Cosmetic.
- Any change to guard Mode B (sight + leash).

## Decisions

**Nearest point is an AABB clamp, not a cell search.** The contiguous foundation cells share a nearest point with their bounding rectangle, so `clamp(from, center - half, center + half)` is exact and O(1). Alternatives: iterating foundation cells (O(footprint), and `FoundationComponent` does not expose `_registered_cells` publicly), or scaling the weapon range by the footprint size (approximate, wrong at corners, and does not fix the approach destination). Clamp wins on correctness and cost.

**Math lives on `FoundationComponent` as `nearest_world_point(from)`.** It is the footprint authority, both consumers need it, and it keeps the geometry in one testable place. Alternatives: a private `CombatComponent` helper (would duplicate the clamp in `GuardComponent`), or a static `CellUtil` function (splits "what a building's bounds are" from the building). Instance method on the component, matching the class's existing role.

**`CombatComponent` caches the resolved `FoundationComponent` on `set_target`.** `_effective_target_pos()` runs several times per physics tick (range, `close`, turret slew, facing, approach). Caching the component reference (nulled in `clear_target`) keeps the per-tick path to a clamp with no `get_node_or_null`. Alternative: resolve the node inside `_effective_target_pos` each call — simpler, but repeated child lookups per tick across many attackers.

**`GuardComponent` resolves the component per building candidate inside the throttled scan.** The hood walk already does `get_node_or_null("HealthComponent")` per candidate; adding one lookup for `StatsComponent.is_structure()` candidates is acceptable at a 0.3 s throttle. Shared primitive keeps the measurement identical to combat. The hood radius is widened by `BUILDING_HOOD_MARGIN_CELLS` (4, not 3, to absorb cell rounding) because `SpatialHash` indexes each entity at its centre cell only; without it, a building whose centre is outside weapon range but edge inside it is never scanned. The margin covers the widest foundation in content (6x6 → half-extent 3 cells) plus one cell of slack. Alternative: index buildings across every footprint cell in `SpatialHash` — correct but invasive (`_entry_map`, `cell_key`, `_reconcile`, `_blocked_cells`, and every `get_entries` consumer assume one cell per entry), deferred as the root fix if guard housing gaps matter later.

**Structures are classified by `StatsComponent.is_structure()`, in both consumers.** `EntityFactory._add_foundation_component` attaches a `FoundationComponent` to any entity with `foundation != 1x1`, regardless of type, so component presence alone is not a structure test. `CombatComponent.set_target` resolves the foundation only when `is_structure()`, matching `GuardComponent`. Today all multi-cell entities are structures, so this only future-proofs; a multi-cell non-structure would otherwise be measured to the footprint by one system and its origin by the other.

**Projectile reach extends by the footprint half-diagonal for structure targets.** `ProjectileController.setup` adds `Vector2(hx, hz).length()` (half-extents from the target's `foundation`) to `_max_range` when the target is a structure. This covers exactly the centre offset the stop change introduced, without extending reach for arbitrary out-of-range targets — `test_max_range_fizzle_deals_no_damage` (range 0.5, unit target at 50) must keep fizzling. Alternatives: aim the projectile at the engagement point (removes through-wall flight, but changes homing semantics for moving targets and needs a `projectile-runtime` aim contract), or size the hitbox to the foundation (root fix, broad blast radius). Both deferred; the reach extension is the minimal correctness fix.

**The chase staleness key keeps using the footprint center.** `_chase_leg_enemy_cell` is compared against `world_to_cell(_target.global_position)`. The nearest point drifts as the attacker circles, so keying on it would trip the re-plan throttle every 0.15 s. The building center is static, so the existing throttle logic stays correct. Only the geometry consumers switch to the effective point.

**`_effective_target_pos()` is computed once at the top of `_move_toward_target` and reused.** The stop computation, the cell relocation, the in-range pull-back, and the final range verification must all measure to the same point, or the pull-back re-check contradicts the new range semantics.

**The `close` facing exemption now means "touching the wall".** `close` compares the effective-target distance to `CellUtil.CELL_SIZE`, so a body-mounted unit within a cell of the nearest wall fires without rotating (the updated `combat-facing` spec). This is the intended semantic — "target so close, don't bother turning" — but it fires un-faced slightly more often than the center-based check did. No deadlock: `aimed` is forced true on the close branch.

## Risks / Trade-offs

- [Nearest point shifts as the attacker moves during a chase leg] → The stop is computed once per plan from the attacker's current position; while `MOVING` the existing throttle blocks re-plans, and on arrival the idle re-check issues a corrected short leg if needed. Same convergence behavior the current center-based approach already relies on.
- [Rotated buildings measure against an unrotated rectangle] → Pre-existing ceiling: foundation cell registration already ignores rotation. Documented in a code comment and in the proposal; arbitrary yaw stays out of scope.
- [Guard acquisition of a static building becomes broader] → Intended consistency: a hold-ground guard can now engage a building its ordered attack could already fire on. Covered by a dedicated guard test.
- [The guard hood margin is coupled to the widest foundation in content] → 6x6 today (half-extent 3 cells); the constant is 4 to absorb cell rounding. A wider structure would need the constant bumped; the guard spec names the constant so the coupling is explicit. The root alternative (footprint-cell indexing) is noted above.
- [Cache staleness if the target's `FoundationComponent` is replaced after `set_target`] → Components are configured at spawn, before runtime targeting; `_effective_target_pos` guards with `is_instance_valid` and falls back to `global_position`.
- [Physical projectiles fizzle before reaching a multi-cell building] → `ProjectileController` extends max range by the target's foundation half-diagonal for structures. Regression test `test_physical_projectile_damages_large_building_from_edge_range` is verified to fail without the extension, while the unit-target max-range fizzle test stays green.
- [Multi-cell non-building entities could diverge between consumers] → Both `CombatComponent` and `GuardComponent` classify via `StatsComponent.is_structure()`, so a multi-cell non-structure measures as a point in both. Covered by a combat test.

## Open Questions

- None blocking. If rotated building support is later required, replace the AABB clamp with a rotation-aware footprint query in `FoundationComponent`; no call site outside it needs to change.
- Follow-up (not this change): size a building's `HitboxComponent` to its foundation so projectiles contact the wall at weapon range and stop flying through it. That would also let the projectile max-range extension be removed.
