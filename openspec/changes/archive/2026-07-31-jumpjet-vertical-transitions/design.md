## Context

`MovementController` implements jumpjet hybrid locomotion (walk-first, fly-fallback) from #34. Its flight altitude is currently `_hover_height`, read from `GlobalRules.hover_height` (or `Locomotor.hover_height_override`), shared with hover units. There is no vertical motion: `_snap_to_terrain()` lerps Y at 0.95/frame and the IDLE branch assigns Y directly, so the jumpjet appears to snap between ground and flight altitude.

`CombatComponent` issues attack-approach moves via `mc.set_target_position(stop_pos)` with no zone awareness, and its range check uses full 3D distance (`global_position.distance_to(target.global_position)`). A jumpjet hovering at `~4.08` world units above terrain therefore reads as further away than its weapon range even when horizontally in range.

## Goals / Non-Goals

**Goals:**
- Configurable jumpjet flight altitude driven by the Locomotor data (terrain height units, default 6.0).
- Explicit vertical states (GROUND/ASCENDING/AIR/DESCENDING) with Y movement at `move_speed`.
- Attack approach preserves the current zone (ground attack on land, air attack airborne); mid-transition attack ascends to target height first.
- Walk-first move orders: walk on foot when reachable, fly-fallback to the destination then land; fly move orders land on arrival.
- Any new order while descending returns the unit to the air zone.
- Horizontal (XZ) combat range check so altitude never blocks firing.

**Non-Goals:**
- Jumpjet animation states (flight/landed art).
- Per-entity height overrides (Locomotor-level is enough).
- Aircraft (`is_fly`) altitude — those keep their current instant-height behavior.
- Generalized attack *targeting* rules (a weapon target-type filter) — out of scope; only the range measurement changes. The JumpCannon data sets `anti_air = true` / `anti_ground = true` so jumpjets can engage both ground and air targets, matching the jumpjet spec requirement.

## Decisions

### D1. `jumpjet_target_height` on Locomotor, in terrain height units

Add `@export var jumpjet_target_height: float = 6.0` to `Locomotor.gd`. It is stored in terrain height units (each = `TerrainSystem.HEIGHT_STEP`), matching the `climb_tolerance` (height-level) convention already in the class. `MovementController._resolve_locomotor()` computes `_jumpjet_air_height = jumpjet_target_height * TerrainSystem.HEIGHT_STEP`. `resources/locomotors/Jumpjet.tres` sets `jumpjet_target_height = 6.0` explicitly.

*Alternative considered:* reuse `hover_height_override`. Rejected — it is hover-specific, has a `0 = use GlobalRules` sentinel, and mixing jumpjet altitude into it would break hover data semantics. A dedicated field keeps the two locomotion families independent.

### D2. Vertical state machine with `move_speed` transitions

Add `enum VerticalState { GROUND, ASCENDING, AIR, DESCENDING }` and `_vertical_state`. A single `_update_vertical(delta)` drives Y toward the zone target:
- GROUND → `terrain_y`
- AIR → `terrain_y + _jumpjet_air_height`
- ASCENDING → move up by `move_speed * delta`; on reaching the target → AIR
- DESCENDING → move down by `move_speed * delta`; on reaching the target → GROUND

`_is_floating()` becomes `_is_hover or (_is_jumpjet and _vertical_state != GROUND)`; `_hybrid_active` is kept as the path-shape flag (fly vs walk) but no longer determines floating. `_update_vertical` runs in `_physics_process` (IDLE branch) and replaces the jumpjet's Y handling in `_snap_to_terrain()` and the arrival branches — all Y-snaps are guarded to skip jumpjets.

*Alternative considered:* reusing `State` (IDLE/ROTATING/MOVING/WAIT). Rejected — that enum already encodes horizontal lifecycle; vertical motion is orthogonal and interleaves with all of them (a unit can descend while walking). A parallel enum keeps the state space small and testable.

### D3. Zone retention via a `keep_zone` parameter

`set_target_position(target, unblock_buildings = false, keep_zone = false)`. When `keep_zone` (attack approach) and jumpjet:
- hybrid fallback is forced: fly when `_vertical_state != GROUND`, walk when grounded;
- desired zone = GROUND when grounded, AIR otherwise (mid-transition → ascend and attack).

`CombatComponent._move_toward_target()` passes `keep_zone = true`.

*Alternative considered:* CombatComponent setting a persistent "attacking" flag on the MC. Rejected — the movement decision belongs in `set_target_position`, and a per-call parameter avoids cross-component state that can go stale when an attack is cancelled.

### D4. Desired-zone rules per order

- **Move order**: desired = GROUND if the walk path exists (walking), AIR if fly fallback engaged.
- **Attack order (`keep_zone`)**: desired = GROUND if `_vertical_state == GROUND`, else AIR.
- **Any new order while `DESCENDING`**: desired = AIR (interrupt the landing, ascend back).
- `_apply_zone_desire()` transitions the state machine (GROUND→ASCENDING, AIR→DESCENDING, ASCENDING→DESCENDING on reversal, DESCENDING→ASCENDING on reversal).

### D5. Horizontal combat range

`CombatComponent._physics_process()` measures range with the Y component zeroed:
`Vector3(global_position.x, 0, global_position.z).distance_to(Vector3(target.x, 0, target.z))`.
`_move_toward_target()` already computes its approach offset on the XZ plane, so this makes the in-range test consistent with how stop positions are chosen. This benefits all ranged units, not just jumpjets (hover units no longer read as slightly out of range).

*Alternative considered:* adding per-weapon "ignore altitude" flags. Rejected — RTS engagement range is conventionally planar; making it XZ everywhere is the simpler and correct default.

## Risks / Trade-offs

- **Vertical transitions change feel for all jumpjet movement** → Mitigation: transitions use the existing `move_speed`; at default speed (8.0) a 4.08-unit ascent takes ~0.5s, which reads as natural flight.
- **`keep_zone` param grows `set_target_position`'s signature** → Mitigation: third optional param defaults false; all existing callers unchanged.
- **XZ range check could make ground-level units appear to have longer effective range on cliffs** → Mitigation: standard RTS behavior; C&C measures range on the plane, not the slope.
- **Descending interrupt (D4) could feel like it ignores the new order** → Mitigation: the ascend is the interrupt response; the new order's own desired zone is applied after reaching AIR (the walk path is still computed and the unit descends to it when it's a walk order).

## Migration Plan

1. Add `jumpjet_target_height` to `Locomotor.gd` + `Jumpjet.tres`.
2. Implement vertical state machine + desired-zone logic in `MovementController.gd`.
3. Add `keep_zone` to `set_target_position`; wire `CombatComponent._move_toward_target()`.
4. XZ range check in `CombatComponent`.
5. Unit tests; run full suite + lint/format.
6. Archive the OpenSpec change; commit on `feat/34-locomotor-enforcement-movement-zones` referencing #34.

Rollback: revert `MovementController.gd`, `CombatComponent.gd`, `Locomotor.gd`, `Jumpjet.tres`, and the archived spec delta. No data migration needed (new field defaults to 6.0).

## Open Questions

- Should the vertical transition speed be a separate Locomotor field rather than reusing `move_speed`? Default to `move_speed`; add a field only if playtesting demands it.
- Should hover units also get the XZ range check benefit explicitly specced? Yes — covered by the combat-firing delta as a shared behavior.
