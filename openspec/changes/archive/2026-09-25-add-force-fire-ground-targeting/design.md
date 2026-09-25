## Context

The Ctrl modifier already travels the full distance: `MouseHandler.build_modifiers()` snapshots it into `OrderResult.MOD_FORCE_ATTACK`, `OrderSystem` forwards it through its bounds and fog gates, `OrderResolver` hands it to every component's `get_order_for_target()`. Three gates then discard it:

1. `UnitOrderGenerator.get_orders()` builds a MOVE whenever `target == null`, before any component sees the modifier.
2. `CombatComponent.get_order_for_target()` returns `null` for a null target and only reaches the `force_attack` branch behind `stats.player_id >= 0`, so neutrals fall through.
3. `CombatComponent` has no notion of engaging a *position* — `_target: Node3D` is the sole source of truth for range, facing, turret slew, chase, and target-death cleanup.

A fourth gate sits further upstream: the mouse raycast queries collision layers `1<<15` and `1<<16`, while bridge/ice hitboxes live on `LAYER_HITBOX_GROUND = 1<<1`, and `_find_entity_parent()` requires a `SelectComponent` that `TERRAIN`/`OVERLAY` entities never receive. A click on a bridge therefore resolves to a ground pick today, which is why the deck-level move works.

Two specs already anticipate work here: `order-system` carries a `Force-fire into shroud gated` scenario (vacuous — ground force-fire does not exist), and `stop-command` carries `Stop during combat` (unimplemented and untested). Issue #446 files the missing guard-vision gate.

Damage is the other half. `WarheadData.can_damage_walls`, `can_damage_wood` and `can_damage_tiberium` are declared with zero readers; `WarheadData.splash_radius` and `WeaponData.splash_radius` are likewise dead. A shot with no entity victim cannot land anywhere: `_apply_hitscan_damage()` derefs `target` unconditionally and `ProjectileController._compute_damage_for()` derefs a victim it is never given.

## Goals / Non-Goals

**Goals**

- Ctrl+Left-click issues an attack against a ground cell, ally, own entity, neutral, or terrain; without Ctrl the ground path is byte-identical to today.
- A ground engagement behaves like an entity engagement: approach to range, fire on cooldown, repeat until a player move, Stop, or the shooter's death.
- One cell of damage resolution on impact, with warhead-gated cell overlays.
- Force-fire ground targeting allowed through fog, refused through shroud.
- Guard acquires only what the owning player can see.
- Stop reverts an engaged unit to idle while leaving guard free to run.

**Non-Goals**

- Area-of-effect damage: no 9-cell sweep, no `Spread` falloff, no wiring of `splash_radius`. Deferred to its own change.
- Terrain objects becoming legal targets *without* force-fire (`TreeTargeting` / `LegalTarget` semantics).
- Wall-overlay damage (needs an `EntityData` flag that does not exist) and tree damage (`can_damage_wood`).
- Bridge strength tuning and the repair hut (#250).
- An attack line rendered to a ground point (`SelectComponent` draws its line from `get_target()`).
- Passing `end_level` on the chase path, so approaching a *deck* target paths at ground level — identical to today's attacks on entities standing on bridges.

## Decisions

### D1 — Position-first engagement, not a proxy node

**Chosen:** `CombatComponent._target_pos: Vector3` becomes the source of truth; `_target: Node3D` becomes optional. `set_ground_target(pos, hold_ground := false)` shares a private `_begin_engagement()` with `set_target()`.

**Alternative considered — a `GroundTarget` proxy `Node3D`** spawned at the fire cell and passed to `set_target()`. Range, facing, turret slew, chase and `GuardComponent._is_blocked()` would all work untouched, and the inert-node risk is low (SpatialHash, Fog, Power, Veterancy and Radar `node_added` handlers are all group- or type-guarded, so a bare `Node3D` is invisible to them). Rejected because it hides a non-entity in the entity slot with lifetime rules someone has to reconstruct at 3am, does nothing for the detonation path (which needs occupant resolution either way), and is not how the original models it: the engine stores a target as *cell-or-object* (`RTTI_CELL = 11`, `RTTI_ABSTRACT` "marks a stored target that names an object rather than a cell").

**Consequence:** ~15 `_target` guard sites in `CombatComponent` and 12 in `ProjectileController` must be re-keyed. The funnel is already there — `_effective_target_pos()` and `_horizontal_distance()` are the only places range, facing and turret aim read the target from.

### D2 — Resolve terrain at impact, not at the pick

**Chosen:** no new raycast pass, no cell-occupant lookup during cursor/order resolution. A bridge is reached because the shot lands in its cell and occupant resolution finds it there.

**Alternative considered — promote the cell's bridge/ice entity to `target` inside `OrderSystem`** so the cursor and order both see a real entity. Rejected: it needs `MOD_TARGET_LEVEL` threaded through the hover path (the click path has it, the hover path does not), it drags terrain through the entity fog and bounds gates, and it changes the plain-click behaviour of a bridge — which today is a move onto the deck and must stay that way.

**Consequence:** `MouseHandler`'s targeting code needs no changes at all. Its only edit is the Stop fix (D8).

### D3 — Two disjoint passes over one cell

**Chosen:** at impact, one cell, two passes, split by `entity_type` so nothing is hit twice:

- **Occupant pass** — entries with a `HealthComponent` whose `entity_type` is `INFANTRY`, `VEHICLE`, `AIRCRAFT` or `BUILDING`. Closest in 3D to the impact point; the shooter is excluded; **allies are not**. A building is indexed in the grid only at its centre cell, so when the cell holds no grid entry the pass falls back to the building-footprint registry — otherwise force-firing an edge cell of a large structure would damage nothing. `register_building_cells()` therefore records the owning entity alongside the cell.
- **Overlay pass** — bridge (`bridge_kind == LOW` and not `bridge_end`), ice (`breakable_surface` and the `breakable_ice` feature), tiberium (`resource_category == "tiberium"`), each gated on its warhead flag.

TERRAIN and OVERLAY entities are excluded from the occupant pass by construction, which is what keeps a bridge from being damaged twice and keeps trees, rocks and other terrain out without extra predicates.

**Rationale for including allies:** OpenTS damages everything in the blast except the object credited with the shot. Excluding allies would silently soften force-fire into a melee, and the user asked for it explicitly.

**Rationale for the flag gates:** `can_damage_walls` is our `WarheadType.Wall=yes`, which in OpenTS gates *both* bridge spans (`DestroyableBridges=yes` and `Wall=yes`) and ice cracking (`Wall=yes` or `Fire=yes`). One flag covers both, per the user. `can_damage_tiberium` is our `Tiberium` crystal flag. Neither has a reader today.

### D4 — Shroud gate reuses modifier stripping

**Chosen:** a gate beside `_fog_filter_target()` that, for `target == null`, strips `MOD_FORCE_ATTACK` when `not ShroudSystem.is_explored(local, target_cell)` and `ShroudSystem.is_shroud_enabled()`. Both `get_cursor()` and `get_orders()` already call through the same funnel, so cursor and order cannot disagree.

**Why not change `_fog_filter_target()`:** that gate's *entity* clause is on visibility and is correct — fog legitimately hides entities while leaving terrain targetable, and hover (`MouseHandler._is_fog_visible()`) already prevents pointing at a fogged entity, making it a second line of defence. Splitting the requirement keeps the two tests where they belong.

**Behavioural difference recorded:** a cell that is explored but not currently visible is targetable; a cell that has never been explored degrades to a plain move, mirroring OpenTS's `MoveToShroud` key ("an attack click onto shrouded ground sends the object there rather than making it fire").

### D5 — Cursor falls out of the order fix, and only under Ctrl

**Chosen:** `UnitOrderGenerator` runs `resolve_all()` / `resolve_single()` for a null target **only when `MOD_FORCE_ATTACK` is held**.

`UnitOrderGenerator.get_cursor()` already derives the entity cursor from `resolve_single(...).cursor`; only the ground branch short-circuits to MOVE. So the cursor fix is the order fix.

Restricting it to Ctrl is deliberate: without it, the ground branch would start resolving for everyone and the existing undeploy-vs-move tie (both priority 5, decided by child iteration order) could flip. Under Ctrl the new combat order has priority 30 and wins unambiguously, which is correct — a deployed, armed unit should fire rather than undeploy.

### D6 — Guard: gate acquisition on visibility, never drop

**Chosen:** `ShroudSystem.is_visible(_stats.player_id, cell)` filters candidates in `_find_nearest_enemy()` (the call already performs allied union), and **no maintain/drop gate is added**. `_is_blocked()` changes from `get_target() != null` to `_combat.is_engaged()` so guard cannot steal a ground engagement.

**Rejected — dropping the target when it leaves visibility.** Reverse of the user's final decision: once acquired, an engagement persists even if the target moves into pitch black. Consequence accepted: the unit keeps firing at an entity whose mesh is fog-culled, because the node stays in the tree and gameplay is not fog-paused. This matches #446's "player-ordered force-attack behavior unchanged" in spirit — the visibility test governs *acquisition*, not *maintenance*.

**Player-ordered attacks are untouched** — they persist into fog by the existing rule.

### D7 — Tiberium lookup short-circuits on the existing index

Tiberium entities are `entity_type = OVERLAY` with `foundation = (1,1)`, so `EntityFactory` never adds them to the `entities` group and `SpatialHash.get_entries()` cannot return them. They live in the `resources` group, with only a boolean `_resource_cells` index.

**Chosen:** check `SpatialHash.has_resource_cell(cell)` first (one dictionary lookup, so the common empty-cell shot stays O(1)), and only then scan `get_nodes_in_group("resources")` filtered to that cell. Precedent at `HarvestComponent.gd:314`.

**Alternative considered — extend `_resource_cells` to hold node references.** Cleaner long-term, but widens a core system's data shape for one consumer. Defer.

### D8 — Stop clears the engagement at the hotkey

**Chosen:** `MouseHandler.apply_selection_hotkey(is_stop)` also calls `combat.clear_target()`.

`MovementController.stop()` returns immediately when `_state == State.IDLE`, and a unit firing at a fixed point *is* idle, so no movement signal ever fires. Combat already clears on `movement_started`, so player moves need nothing. Putting the fix in the hotkey makes it fire exactly once per player command and repairs `stop-command`'s `Stop during combat` scenario for entity attacks as well — the root cause is shared, so the fix is shared.

`clear_target()` is sufficient for "revert to idle but keep auto-fire": it resets `_attack_active`, leaving `GuardComponent._is_blocked()` false so the next scan may re-acquire.

### D9 — Spec deltas

| Capability | Operation | Why |
|---|---|---|
| `order-system` | MODIFIED `Fog-gated target filtering` | Its ground clause moves from a visibility test to a shroud test; scenarios added for the force-fire order itself |
| `guard-auto-engage` | MODIFIED `Idle armed entity auto-acquires nearest enemy already in weapon range` | Adds the visibility gate and rewords "no active target" to "no active engagement" |
| `combat-firing` | ADDED ×3 | Ground engagement, cell-occupant damage, overlay damage — new concerns, existing requirements unchanged |
| `bridges` | ADDED ×1 | Vulnerability of a LOW span is a new requirement; the destructibility split is satisfied, not changed |
| `ice-drowning` | ADDED ×1 | Warhead damage is new; the `breakable_ice` gate is reused |

`stop-command` needs no delta — its requirement already states the desired behaviour.

## Risks / Trade-offs

- **[Friendly fire is now real]** A force-fire at your own infantry damages it, and an in-flight shot can kill an ally standing in the impact cell. → Accepted; matches the original and was requested. Existing `_is_valid_victim()` still governs *collateral along the flight path* and is deliberately left alone, so only the impact cell changes.
- **[Bridge destruction becomes reachable]** `health_zero → _on_destroyed → leave "bridge" group` already exists but nothing could damage a bridge. → Gated on `bridge_kind == LOW && !bridge_end`, which is exactly what `bridges` already declares indestructible for the rest. #250's strength tuning and repair hut remain open.
- **[Ice killed with the feature off]** `HealthComponent` is attached to ice regardless of `breakable_ice`, so a shot could zero it without `IceComponent` present to drown occupants. → The overlay pass requires the feature, so the entity is simply not a victim.
- **[Guard holds a target it cannot see]** Intentional (D6). Mitigation is the target's own death or a player order; the guard scan resumes the moment the engagement ends.
- **[Ground engagements never self-terminate]** A position is never "invalid" and never reaches zero health, so the only exits are move, Stop, and death. → That is the specified behaviour; `_physics_process` must therefore distinguish "entity target vanished" from "no entity target" or it will clear every tick.
- **[Resolver cost on a hot path]** Occupant resolution runs per shot. → One `get_entries()` on a single cell; the tiberium branch is behind an O(1) dictionary probe.
- **[Priority-30 ground order outranks undeploy]** Ctrl+click on a deployed armed unit fires instead of undeploying. → Intended; plain click still undeploys.

## Migration Plan

No data migration, no scene or schema changes, no `.tres` edits — nothing to convert and nothing to roll back beyond reverting the commit. Existing tests must stay green; the entity fog gate, bounds gate, undeploy-on-ground-click and bridge-deck move are the regression surfaces.

## Open Questions

None blocking. Two recorded as accepted limitations rather than questions: chase does not pass `end_level` (deck-level approach), and `MouseHandler._is_hovering_shrouded()` still uses the fog test — it affects hover decoration only and never reaches order resolution.
