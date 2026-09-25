## MODIFIED Requirements

### Requirement: weapon_fired signal
CombatComponent SHALL emit `weapon_fired(weapon: WeaponData, target: Node3D)` after each successful weapon dispatch, whether the weapon spawned a projectile or applied fallback hitscan damage. For an entity engagement `target` SHALL be that entity; for a ground engagement `target` SHALL be `null`. Listeners MUST tolerate a null target.

#### Scenario: Signal emitted on fire
- **WHEN** CombatComponent fires a weapon
- **THEN** `weapon_fired` is emitted with the weapon data and target reference

#### Scenario: Signal emitted on projectile dispatch
- **WHEN** a weapon dispatches a projectile instead of applying fallback damage
- **THEN** `weapon_fired` is still emitted exactly once

#### Scenario: Signal emitted with a null target on ground engagement
- **WHEN** CombatComponent fires while engaged with a ground position rather than an entity
- **THEN** `weapon_fired` is emitted once with the weapon data and a null target, without error

## ADDED Requirements

### Requirement: Force-fire order generation
When `OrderResult.MOD_FORCE_ATTACK` is held and the entity has at least one weapon, `CombatComponent.get_order_for_target()` SHALL return an ATTACK `OrderResult` regardless of the target's ownership or presence: an allied entity, an own entity, a neutral entity (`player_id < 0`), an entity with no `StatsComponent`, and an absent entity target (ground) are all accepted. Without the modifier, an ATTACK `OrderResult` SHALL be produced only for a hostile entity (`player_id >= 0` and `PlayerManager.is_enemy`). An entity with no weapons SHALL produce no order under either case.

#### Scenario: Ground target under force-fire
- **WHEN** an armed entity resolves a null target with `MOD_FORCE_ATTACK` held
- **THEN** `CombatComponent` SHALL return an ATTACK `OrderResult` carrying the requested ground position

#### Scenario: Ground target without force-fire
- **WHEN** an armed entity resolves a null target without `MOD_FORCE_ATTACK`
- **THEN** `CombatComponent` SHALL return no order

#### Scenario: Allied entity under force-fire
- **WHEN** an armed entity resolves an allied or own entity with `MOD_FORCE_ATTACK` held
- **THEN** `CombatComponent` SHALL return an ATTACK `OrderResult` on that entity

#### Scenario: Allied entity without force-fire
- **WHEN** an armed entity resolves an allied or own entity without `MOD_FORCE_ATTACK`
- **THEN** `CombatComponent` SHALL return no order

#### Scenario: Neutral entity under force-fire
- **WHEN** an armed entity resolves a neutral entity (`player_id < 0`) with `MOD_FORCE_ATTACK` held
- **THEN** `CombatComponent` SHALL return an ATTACK `OrderResult` on that entity

#### Scenario: Hostile entity without force-fire is unchanged
- **WHEN** an armed entity resolves a hostile entity without `MOD_FORCE_ATTACK`
- **THEN** `CombatComponent` SHALL return an ATTACK `OrderResult`, exactly as before this change

#### Scenario: Unarmed entity never force-fires
- **WHEN** an entity with an empty `weapons` array resolves any target with `MOD_FORCE_ATTACK` held
- **THEN** `CombatComponent` SHALL return no order

### Requirement: Ground engagement
`CombatComponent` SHALL support an engagement keyed to a world position with no entity target, entered via a ground-target setter alongside `set_target()`. The position SHALL be the source of truth for range, body facing, turret slew, and approach: `_effective_target_pos()` SHALL return the ordered position when no entity target is held, and the entity's foundation-nearest point otherwise. The engagement SHALL be entered in the same state as an entity engagement (stop current move, approach if out of range) and SHALL fire on every cooldown while in range, repeating without being re-issued. It SHALL NOT self-terminate: a position never becomes invalid and never reaches zero health, so the only exits are a player move, the Stop command, or the shooter's death. `is_engaged()` SHALL report true for both an entity engagement and a ground engagement.

#### Scenario: Ground engagement fires in range
- **WHEN** an entity with a ground engagement is within weapon range, facing is aligned and cooldown has elapsed
- **THEN** the entity SHALL fire at the ordered position

#### Scenario: Ground engagement repeats without re-issue
- **WHEN** a ground engagement stays in range across several cooldown periods with no further player input
- **THEN** the entity SHALL fire again on each elapsed cooldown, the engagement still being active

#### Scenario: Ground engagement approaches when out of range
- **WHEN** a ground engagement is ordered at a position beyond weapon range
- **THEN** the entity SHALL issue an approach move and fire once the ordered position enters range

#### Scenario: Ground engagement survives arbitrary ticks
- **WHEN** no player order has been issued for many `_physics_process` ticks during a ground engagement
- **THEN** the engagement SHALL remain active and `is_engaged()` SHALL remain true

#### Scenario: Player move ends the ground engagement
- **WHEN** a ground engagement is active and `MovementController` emits `movement_started` from a player-initiated move
- **THEN** `CombatComponent` SHALL clear the engagement and stop firing, per the existing player-move-cancels-attack requirement

#### Scenario: Stop ends the ground engagement
- **WHEN** a ground engagement is active and the player issues the Stop command
- **THEN** `CombatComponent` SHALL clear the engagement, the entity SHALL become idle, and `GuardComponent` SHALL be free to acquire on its next scan

#### Scenario: is_engaged is true without an entity target
- **WHEN** a ground engagement is active and `_target` is null
- **THEN** `is_engaged()` SHALL return true while `get_target()` returns null

### Requirement: Cell occupant damage without an entity target
When a shot resolves with **no** entity target — a ground engagement's hitscan fallback or projectile detonation — the system SHALL resolve the occupant of the impact cell: the entity nearest the impact point in three dimensions that has a `HealthComponent` and whose `entity_type` is `INFANTRY`, `VEHICLE`, `AIRCRAFT` or `BUILDING`. Candidates SHALL come from the impact cell's `SpatialHash` grid entries, falling back to the building-footprint registry when the cell holds none — a building is indexed in the grid only at its centre cell, so an edge cell of a large structure must still resolve its occupant. The shooter SHALL be excluded. Allied and neutral occupants SHALL be eligible — only the shooter is exempt. When no such occupant exists, no entity damage SHALL be applied. Shots that do have an entity target SHALL apply damage exactly as before this change: the target's `HealthComponent`, or a skip when it has none.

A ground shot with no victim SHALL resolve both the occupant and the cell overlays at one point — the ordered position — so a projectile that overshoots by a frame can never damage an entity in one cell and a bridge, ice sheet or tiberium in the next.

#### Scenario: Enemy walks into the cell after the order
- **WHEN** a force-fire shot is ordered at an empty cell and an enemy occupies that cell before impact
- **THEN** that enemy SHALL take the weapon's damage

#### Scenario: Ally in the cell takes the hit
- **WHEN** a force-fire shot resolves over a cell occupied by an allied entity
- **THEN** the allied entity SHALL take the weapon's damage

#### Scenario: Shooter is exempt
- **WHEN** a force-fire shot resolves over the cell the shooter itself occupies and no other qualifying occupant is present
- **THEN** the shooter SHALL take no damage

#### Scenario: Empty cell applies no entity damage
- **WHEN** a force-fire shot resolves over a cell with no qualifying occupant
- **THEN** no entity SHALL take damage from the shot

#### Scenario: Edge cell of a large building resolves its occupant
- **WHEN** a force-fire shot resolves over a footprint cell of a building whose centre lies in a different cell
- **THEN** that building SHALL take the weapon's damage

#### Scenario: Terrain and overlay entities are never occupants
- **WHEN** a force-fire shot resolves over a cell occupied only by a bridge or ice entity
- **THEN** the occupant pass SHALL apply no entity damage; bridge and ice are handled by the cell-overlay pass

#### Scenario: Entity-targeted shots are unchanged
- **WHEN** a shot resolves with an entity target that has no `HealthComponent`
- **THEN** the damage call SHALL be skipped without error and no occupant SHALL be substituted

### Requirement: Cell overlay damage
Whenever a shot resolves at a position — entity target or ground — the system SHALL apply the warhead's cell-overlay damage to overlays standing in the impact cell, each gated on its own flag:

- a **bridge span** SHALL take damage only when `WarheadData.can_damage_walls` is set and the span is a destructible LOW normal piece; end pieces and every high-bridge cell SHALL take no damage from any warhead;
- **ice** SHALL take damage only when `WarheadData.can_damage_walls` is set and the game declares the `breakable_ice` feature; without the feature ice SHALL take no warhead damage;
- **tiberium** SHALL take damage only when `WarheadData.can_damage_tiberium` is set.

Overlays failing their gate SHALL take no damage. An overlay that is itself the shot's entity target SHALL be damaged exactly once.

#### Scenario: Tiberium damaged under its warhead flag
- **WHEN** a shot resolves over a tiberium cell with a warhead whose `can_damage_tiberium` is set
- **THEN** the tiberium SHALL take damage

#### Scenario: Tiberium untouched without its warhead flag
- **WHEN** a shot resolves over a tiberium cell with a warhead whose `can_damage_tiberium` is clear
- **THEN** the tiberium SHALL take no damage

#### Scenario: Bridge collateral under an entity-targeted shot
- **WHEN** a shot with an entity target detonates over a cell holding a destructible LOW bridge span, with a warhead whose `can_damage_walls` is set
- **THEN** the span SHALL take damage in addition to the entity target

#### Scenario: Ice untouched when the feature is off
- **WHEN** a shot resolves over an ice cell with a warhead whose `can_damage_walls` is set but the game does not declare `breakable_ice`
- **THEN** the ice SHALL take no damage

#### Scenario: Overlay damaged exactly once when it is the target
- **WHEN** an overlay entity is itself the shot's entity target and its warhead gate passes
- **THEN** its health SHALL decrease by a single hit, not two
