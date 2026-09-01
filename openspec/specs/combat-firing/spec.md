## Purpose

CombatComponent resolves enemy targets into attack orders, tracks the current target, enforces per-weapon cooldowns, measures engagement range, applies hitscan damage through warhead armor multipliers, and coordinates movement toward out-of-range targets.
## Requirements
### Requirement: CombatComponent tracks attack target
CombatComponent SHALL maintain a `_target: Node3D` reference set via `set_target(entity)`. The target SHALL persist across `_physics_process` ticks until explicitly cleared via `clear_target()` or the target becomes invalid.

#### Scenario: Set target
- **WHEN** `set_target(entity)` is called with a valid enemy entity
- **THEN** `_target` SHALL reference that entity

#### Scenario: Target becomes invalid
- **WHEN** `_target` is no longer a valid instance (freed node)
- **THEN** CombatComponent SHALL clear `_target` and stop attacking

#### Scenario: Target dies (health reaches zero)
- **WHEN** the target's HealthComponent emits `health_zero`
- **THEN** CombatComponent SHALL clear `_target` and stop attacking

### Requirement: Fire rate cooldown per weapon
CombatComponent SHALL maintain a cooldown timer per weapon index. After firing, the timer SHALL be set to `60.0 / weapon.rate_of_fire` seconds. The weapon SHALL NOT fire while its cooldown timer is positive.

#### Scenario: Fire rate timing
- **WHEN** a weapon with `rate_of_fire = 20` fires
- **THEN** the next shot from that weapon SHALL be delayed by 3.0 seconds (60/20)

#### Scenario: Cooldown ticks down
- **WHEN** `_physics_process(delta)` runs with a positive cooldown
- **THEN** the cooldown SHALL decrease by `delta`

### Requirement: Range checking
CombatComponent SHALL check if the target is within firing range before firing. Range SHALL be calculated as `weapon.attack_range * CellUtil.CELL_SIZE` world units, measured on the horizontal (XZ) plane — the Y (altitude) component SHALL be ignored so hovering or elevated attackers are not pushed out of range by vertical separation.

#### Scenario: Target in range
- **WHEN** the target's horizontal distance (ignoring Y) is less than or equal to `attack_range * CELL_SIZE`
- **THEN** CombatComponent MAY fire (subject to cooldown)

#### Scenario: Target out of range
- **WHEN** the target's horizontal distance (ignoring Y) exceeds `attack_range * CELL_SIZE`
- **THEN** CombatComponent SHALL issue a move command toward the target position instead of firing

#### Scenario: Vertical separation ignored
- **WHEN** a unit hovers or flies at `4.08` world units above a target that is within `attack_range * CELL_SIZE` horizontally
- **THEN** CombatComponent SHALL treat the target as in range and fire

#### Scenario: Airborne attacker engages ground target
- **WHEN** a jumpjet hovering at its flight altitude attacks a ground target within horizontal range
- **THEN** the target is in range regardless of the altitude difference

### Requirement: Weapon dispatch and damage
When firing, CombatComponent SHALL first resolve `weapon.projectile` through the GlobalRules projectile registry. If the id resolves to a `ProjectileData`, CombatComponent SHALL instantiate `Projectile.tscn`, configure it with the projectile data, weapon, shooter, and target, spawn it at the shooter's position offset by `WeaponData.fire_offset`, parent it to the gameplay root, and SHALL NOT apply direct damage. If the id is empty or unresolvable, CombatComponent SHALL apply damage directly (legacy hitscan): the weapon's base damage multiplied by the warhead armor multiplier for the target's armor type, clamped to GlobalRules `[min_damage, max_damage]`, then call `target.get_node("HealthComponent").take_damage(final_damage, weapon.warhead)`.

#### Scenario: Resolvable projectile spawns instead of direct damage
- **WHEN** a weapon with `projectile = "Invisible"` fires at an enemy in range
- **THEN** a projectile node is spawned and configured, and the target's HealthComponent is not modified by CombatComponent directly

#### Scenario: Spawn at muzzle offset
- **WHEN** a projectile is spawned
- **THEN** its initial position is the shooter's position plus `WeaponData.fire_offset`

#### Scenario: Unresolvable projectile falls back to hitscan
- **WHEN** a weapon's projectile id does not resolve in the registry (or is empty)
- **THEN** damage is applied directly with the full legacy math

#### Scenario: Fallback damage applied with armor
- **WHEN** a weapon with `damage = 100` and warhead "SA" fires via the fallback at a target with `armor = "heavy"` (SA multiplier 0.25)
- **THEN** the target's HealthComponent receives `take_damage(25, "SA")`

#### Scenario: Armor-piercing vs heavy
- **WHEN** a weapon with `damage = 100` and warhead "AP" fires at a target with `armor = "heavy"` (AP multiplier 1.00)
- **THEN** the target's HealthComponent SHALL receive `take_damage(100, "AP")`

#### Scenario: Fallback minimum damage floor
- **WHEN** the fallback-computed damage would be below `min_damage` (1)
- **THEN** the applied damage is clamped to 1

#### Scenario: Fallback maximum damage cap
- **WHEN** the fallback-computed damage would exceed `max_damage` (1000)
- **THEN** the applied damage is clamped to 1000

#### Scenario: Fallback zero-damage armor pairing
- **WHEN** a warhead's multiplier for the target's armor is 0.0
- **THEN** the target's HealthComponent receives `take_damage(0, warhead)` and takes no damage

#### Scenario: Fallback unknown warhead or armor
- **WHEN** the weapon's warhead id or the target's armor id is not in the GlobalRules registries
- **THEN** fallback damage is applied with full multiplier 1.0

#### Scenario: Fallback target has no HealthComponent
- **WHEN** the target entity has no HealthComponent child
- **THEN** CombatComponent skips the damage call without error

### Requirement: weapon_fired signal
CombatComponent SHALL emit `weapon_fired(weapon: WeaponData, target: Node3D)` after each successful weapon dispatch, whether the weapon spawned a projectile or applied fallback hitscan damage.

#### Scenario: Signal emitted on fire
- **WHEN** CombatComponent fires a weapon
- **THEN** `weapon_fired` is emitted with the weapon data and target reference

#### Scenario: Signal emitted on projectile dispatch
- **WHEN** a weapon dispatches a projectile instead of applying fallback damage
- **THEN** `weapon_fired` is still emitted exactly once

### Requirement: Movement integration
CombatComponent SHALL connect to `MovementController.arrived` signal on first attack engagement. When `arrived` fires, the next `_physics_process` tick SHALL re-evaluate range and fire if in range.

#### Scenario: Unit moves toward target
- **WHEN** target is out of range and MC is idle, or the current move was just superseded by a fresh attack order
- **THEN** CombatComponent SHALL compute a stop position at `weapon.attack_range * CELL_SIZE` distance from the target, at the angle from the target to the unit (atan2), and call `mc.set_target_position(stop_pos)`

#### Scenario: Multiple units spread around target
- **WHEN** 3 units attack the same target from different angles
- **THEN** each unit SHALL compute a unique stop position at its own angle from the target, spreading naturally around the target perimeter

#### Scenario: Unit already moving on an approach
- **WHEN** MC is already moving (`is_moving() == true`) on a previously issued combat approach
- **THEN** the per-frame `_physics_process` re-check SHALL NOT issue another move command

#### Scenario: Arrival triggers re-check
- **WHEN** MovementController emits `arrived` signal
- **THEN** CombatComponent SHALL re-check range on next `_physics_process` tick

### Requirement: Player move cancels attack
CombatComponent SHALL clear its attack target and stop attacking when the player issues a move command. Combat-initiated moves (closing distance to target) SHALL NOT clear the attack target.

#### Scenario: Player move clears attack
- **WHEN** CombatComponent has an active target and MovementController emits `movement_started` from a player-initiated move
- **THEN** CombatComponent SHALL clear `_target`, set `_attack_active = false`, and stop firing

#### Scenario: Combat move preserves attack
- **WHEN** CombatComponent issues a move to close distance to target (sets `_combat_move = true` before calling `mc.set_target_position()`)
- **THEN** MovementController emits `movement_started`, CombatComponent SHALL detect `_combat_move`, skip clearing attack state, and continue attacking after arrival

### Requirement: Attack cancels player move
Issuing an attack order SHALL cancel a ground unit's in-progress player move and engage the target. A ground unit SHALL halt via `MovementController.stop()` (a no-op when already idle); an airborne jumpjet SHALL keep its air zone via `cancel_move_retain_vertical()`. When the target is out of range, the old move destination SHALL be dropped immediately and a new approach path issued in the same frame, so the unit starts moving toward the target without finishing the old move.

#### Scenario: Moving ground unit attacks in-range target
- **WHEN** a ground unit is moving on a player move order and receives an attack order on a target already within weapon range
- **THEN** the unit SHALL stop (settle to its sub-slot) and fire from its current position instead of continuing along the old move path

#### Scenario: Moving ground unit attacks out-of-range target
- **WHEN** a ground unit is moving on a player move order and receives an attack order on a target outside weapon range
- **THEN** the old move destination SHALL be abandoned and the unit SHALL move along a fresh approach path to within weapon range of the target, starting in the same frame as the attack order

#### Scenario: Idle unit receives attack order
- **WHEN** an idle unit receives an attack order
- **THEN** `MovementController.stop()` is a no-op and behavior SHALL be unchanged (fire if in range, approach otherwise)

#### Scenario: Airborne jumpjet attack interrupts move
- **WHEN** an airborne jumpjet moving on a player move order receives an attack order
- **THEN** the in-flight move SHALL be cancelled via `cancel_move_retain_vertical()` and the jumpjet SHALL attack from its air zone (no change to existing airborne behavior)

### Requirement: movement_started signal on MovementController
MovementController SHALL emit `signal movement_started` at the beginning of `set_target_position()`, before any pathfinding or movement begins.

#### Scenario: Signal emitted on move
- **WHEN** `set_target_position()` is called with a valid position
- **THEN** `movement_started` SHALL be emitted before movement begins

### Requirement: is_moving getter on MovementController
MovementController SHALL expose `func is_moving() -> bool` that returns `true` when `_state != State.IDLE`.

#### Scenario: Unit is idle
- **WHEN** MovementController `_state` is `IDLE`
- **THEN** `is_moving()` SHALL return `false`

#### Scenario: Unit is moving
- **WHEN** MovementController `_state` is `MOVING` or `ROTATING`
- **THEN** `is_moving()` SHALL return `true`

### Requirement: Weapon fire sound
On each shot in `_fire_weapon`, CombatComponent SHALL play one audio id chosen at random from `WeaponData.sound_report` (a comma-separated list) at the firing unit's world position via `AudioManager.play_sound`. An empty `sound_report` SHALL play nothing. A missing or unknown id SHALL log a warning and remain silent (graceful failure).

#### Scenario: Fire plays a report sound
- **WHEN** a weapon with `sound_report = "INFGUN3,GOSTGUN1"` fires
- **THEN** one of the listed ids SHALL be played at the firing unit's position

#### Scenario: Empty report is silent
- **WHEN** a weapon with an empty `sound_report` fires
- **THEN** no sound SHALL play

#### Scenario: Missing id is silent
- **WHEN** the chosen report id is not in the audio cache
- **THEN** a warning SHALL be logged and no sound SHALL play


### Requirement: Powered-down structures do not fire
CombatComponent SHALL NOT acquire targets or fire while its entity's `PowerComponent` reports offline (`is_online == false`). The check SHALL be a local gate in the combat processing tick and SHALL NOT interfere with existing target-state handling: the current target SHALL be retained so power restoration resumes engagement. Entities without a `PowerComponent` SHALL be unaffected.

#### Scenario: Offline structure holds fire
- **WHEN** a `powered = true` defense structure is offline and an enemy is in range
- **THEN** CombatComponent fires no weapon and issues no approach move

#### Scenario: Power restoration resumes engagement
- **WHEN** the structure comes back online while a target is still set
- **THEN** CombatComponent resumes normal range/cooldown evaluation against that target

#### Scenario: Units without PowerComponent unaffected
- **WHEN** a combat entity has no `PowerComponent`
- **THEN** firing behavior is identical to the pre-change behavior
