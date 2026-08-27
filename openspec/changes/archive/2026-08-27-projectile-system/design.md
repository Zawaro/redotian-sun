# Design: Projectile System

## Context

The receiver side of the damage pipeline is done: `HitboxComponent._try_deal_damage` (scripts/components/HitboxComponent.gd) duck-types `get_damage_info()` on any area entering its collision mask and forwards `{amount, type}` to `HealthComponent.take_damage()`. Nothing produces that payload. `CombatComponent._fire_weapon` (scripts/components/CombatComponent.gd:182) computes armor-multiplied damage inline and applies it directly.

Data is fully populated: 44/44 weapon `.tres` files set `projectile`, and `resources/projectiles/` holds matching `ProjectileData` files (26 in the invisible family, 11 guided/ballistic visible). GlobalRules has registries for warheads, armor types, and locomotors, but none for projectiles. No weapon or projectile `.tres` defines a speed anywhere in the data set.

Two prior explorations fixed the shape: the branch decision (issue #78, updated after studying the original TS engine's `BulletClass`) and the architecture call (data-flag branches in one controller, mirroring `MovementController` + locomotor data, not component-per-behavior nodes).

## Goals / Non-Goals

**Goals:**
- Close the producer side: every weapon dispatch ends in a projectile that detonates through `HitboxComponent`.
- Preserve current hitscan balance exactly for the invisible family (26 weapons) so the migration is invisible in play.
- Tunneling-proof detection for fast visible projectiles.
- Flight behavior driven entirely by `ProjectileData` flags; adding arcing/bouncy/cluster later is a branch inside one controller, not a new architecture.

**Non-Goals:**
- Splash damage, distance falloff, shared damage helper (#323 owns that; this change keeps the existing inline armor math per branch).
- Impact/explosion visuals (#321 owns the spawner; this change only emits `impacted`).
- Arcing, bouncy, cluster, proximity fuse, trailers, LOS raycasts, projectile-vs-terrain collision.
- A ProjectileManager autoload or projectile pooling (dozens concurrent, not hundreds; revisit if profiling says otherwise).

## Decisions

**One controller script with data-flag branches, not node components.**
Entities decompose into component nodes because they aggregate long-lived, laterally-interacting behaviors. A projectile has one job for 15–30 frames and its variation is a single axis (flight model). `MovementController` already established the in-repo pattern: one controller, behavior branches resolved from a data resource (locomotor flags). The original TS engine made the same call (`BulletTypeClass` flat flags branched in one `AI()`). Rejected: `FlightModel` strategy scripts per type — more files and wiring for zero reuse, since all variants share spawn, payload, arming, detonation, and FX plumbing.

**Two flight behaviors, chosen by data.**
- `is_invisible = true` → teleport-detonate: position at the target coordinate, detonate synchronously at dispatch (same tick the legacy hitscan applied damage; no physics-frame dependency). This is what the original engine did for inviso bullets, and it means Vulcan-family weapons keep zero travel time and identical damage timing. The first migration step touches all 26 invisible weapons at once with behavior preserved.
- Everything else visible → straight-line flight with optional homing. Guided projectiles steer via heading slerp capped at `homing_turn_rate` (degrees/sec), launch aimed directly at the target.

Rejected: making invisible projectiles real flyers with hidden meshes. That adds travel time to 26 weapons and silently rebalances the game.

**Shape-cast polling, not `area_entered` signals.**
Overlap events fire on discrete overlap transitions. A projectile moving more than a cell width (2.0 world units) per physics frame can step across a thin hitbox without ever overlapping. The controller casts its collision shape along the frame's full motion segment (previous position → next position) and takes the closest valid hit. This also yields the hit point directly, which snap-to-victim needs. Cost is one cast per projectile per frame; trivial at the projectile counts an RTS match produces. The same cast powers contact detonation, so there is exactly one detection mechanism, not two.

**Four detonation triggers, evaluated in order.**
Contact (segment cast hit) → close proximity to target while armed → overshoot (target distance stopped decreasing between frames) → max range derived from `weapon.attack_range * CellUtil.CELL_SIZE`. Overshoot and stall handling follow the original engine's fuse semantics (EXPLODE_CLOSE / EXPLODE_FAR): a dodged guided missile detonates beside its target instead of orbiting forever. Close-proximity and short-range contact detonations snap the blast position onto the victim center so hits read as hits.

**Arming by frames, not distance.**
`ProjectileData.arm_delay` counts physics frames during which detonation is suppressed entirely (the unarmed cast ignores all hitboxes). The original engine armed by distance; we keep frames because the field is already shipped in `.tres` data (arm_delay = 2 on heatseekers) and frame semantics are unambiguous in a fixed-tick physics loop.

**Friendly-fire exclusion at detection, not at damage.**
The controller filters cast results: skip the shooter node and any node whose owner is allied with the shooter's owner (PlayerManager team check). Skipping at detection means allied projectiles physically pass through allies rather than detonating for zero damage — matches the original engine and avoids friendly projectiles making allies untargetable cover.

**Damage math duplicated per branch for now, helper later.**
The projectile computes `weapon.damage × warhead armor multiplier`, clamped to `[min_damage, max_damage]`, at detonation against the victim's armor. This intentionally mirrors the existing inline `_fire_weapon` math so the fallback path and projectile path agree. #323 extracts the shared helper (and adds `damage_modifier` + distance falloff); this change does not pre-refactor it.

**Speed precedence with a GlobalRules floor.**
`ProjectileData.speed_override` > new `WeaponData.speed` > new `GlobalRules.default_projectile_speed`. Both new fields default to 0.0 so no `.tres` churn; the GlobalRules floor (target ~12.0 world units/sec, tune in play) guarantees no zero-speed stalling while the per-weapon speed pass happens later. World-units-per-second (not per-frame) keeps speed independent of tick rate, consistent with the frame-rate-independent-timing spec.

**Projectile registry mirrors warheads.**
`GlobalRules` gains `projectiles: Dictionary` + `get_projectile(id)`, populated by wiring the existing `resources/projectiles/*.tres` files into `global_rules.tres` the same way warheads are wired today. Editor work, no new loading code, consistent with the codebase's registry pattern.

**Lifecycle: plain child of gameplay root.**
`CombatComponent` instantiates, configures, and adds it to the gameplay root node. `queue_free` on terminal states; a map reload frees in-flight projectiles with the scene. No autoload, no pooling, no manager.

## Risks / Trade-offs

- [Teleport-detonate skips hitbox-side validation the flight path has] → The invisible path still routes through the `HitboxComponent` pipeline with `source`/`position` in the payload; the hitbox just receives an area moved onto its victim. Owner exclusion moves into the controller (never detonate on shooter), tested explicitly.
- [Speed defaults are guesses until play] → GlobalRules floor + `WeaponData.speed` are the tuning knobs; defaults chosen to read correctly at 60fps against 2–8 cell ranges. Mark as playtest-tuning in tasks.
- [Inline damage math now exists in two places] → Accepted duplication; #323 replaces both with the shared helper. Regression tests pin both paths to identical outputs meanwhile.
- [Shape cast misses area-only colliders] → Casts run with `collide_with_areas = true` since `HitboxComponent` is an Area3D; covered by the tunneling test at >1 cell/frame.
- [Projectile visuals before #321] → Placeholder mesh (small quad/sphere, `tint_color`, `graphic_name` ignored) so flight is verifiable; warhead-driven FX lands with the spawner.

## Migration Plan

No data migration. All weapons already carry projectile ids; the dispatch branch activates them at merge. The fallback path keeps any weapon safe from a broken id. Rollback = revert the `_fire_weapon` branch; no scene or data edits are load-bearing.

## Open Questions

- Exact `default_projectile_speed` and per-weapon speeds: defer to playtest; spec pins the precedence, not the numbers.
- Should `WeaponData.speed` be per-weapon or live on the projectile side only? Spec says per-weapon (matches the original engine's weapon-side `MaxSpeed`); revisit if data entry feels wrong.
- Civilian/neutral ownership semantics for the ally check (PlayerManager team model) — confirm neutral factions are neither ally nor shooter at implementation time.
