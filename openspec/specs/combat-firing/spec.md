## ADDED Requirements

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
CombatComponent SHALL check if the target is within firing range before firing. Range SHALL be calculated as `weapon.attack_range * CellUtil.CELL_SIZE` world units.

#### Scenario: Target in range
- **WHEN** the target's distance is less than or equal to `attack_range * CELL_SIZE`
- **THEN** CombatComponent MAY fire (subject to cooldown)

#### Scenario: Target out of range
- **WHEN** the target's distance exceeds `attack_range * CELL_SIZE`
- **THEN** CombatComponent SHALL issue a move command toward the target position instead of firing

### Requirement: Hitscan damage application
When firing, CombatComponent SHALL compute the damage dealt to the target as the weapon's base damage multiplied by the weapon's warhead armor multiplier for the target's armor type, clamped to GlobalRules `[min_damage, max_damage]`, then call `target.get_node("HealthComponent").take_damage(final_damage, weapon.warhead)` directly (hitscan). No projectile node is spawned.

#### Scenario: Damage applied with armor
- **WHEN** a weapon with `damage = 100` and warhead "SA" fires at a target with `armor = "heavy"` (SA multiplier 0.25)
- **THEN** the target's HealthComponent SHALL receive `take_damage(25, "SA")`

#### Scenario: Armor-piercing vs heavy
- **WHEN** a weapon with `damage = 100` and warhead "AP" fires at a target with `armor = "heavy"` (AP multiplier 1.00)
- **THEN** the target's HealthComponent SHALL receive `take_damage(100, "AP")`

#### Scenario: Minimum damage floor
- **WHEN** the computed damage would be below `min_damage` (1)
- **THEN** the applied damage SHALL be clamped to 1

#### Scenario: Maximum damage cap
- **WHEN** the computed damage would exceed `max_damage` (1000)
- **THEN** the applied damage SHALL be clamped to 1000

#### Scenario: Zero-damage armor pairing
- **WHEN** a warhead's multiplier for the target's armor is 0.0
- **THEN** the target's HealthComponent SHALL receive `take_damage(0, warhead)` and take no damage

#### Scenario: Unknown warhead
- **WHEN** the weapon's warhead id is not in the GlobalRules warhead registry
- **THEN** damage SHALL be applied unmodified (full multiplier 1.0)

#### Scenario: Unknown target armor
- **WHEN** the target's armor id is not in the GlobalRules armor type registry
- **THEN** damage SHALL be applied with full multiplier 1.0

#### Scenario: Target has no HealthComponent
- **WHEN** the target entity has no HealthComponent child
- **THEN** CombatComponent SHALL skip the damage call without error

### Requirement: weapon_fired signal
CombatComponent SHALL emit `weapon_fired(weapon: WeaponData, target: Node3D)` after each successful hitscan damage application.

#### Scenario: Signal emitted on fire
- **WHEN** CombatComponent fires a weapon
- **THEN** `weapon_fired` SHALL be emitted with the weapon data and target reference

### Requirement: Movement integration
CombatComponent SHALL connect to `MovementController.arrived` signal on first attack engagement. When `arrived` fires, the next `_physics_process` tick SHALL re-evaluate range and fire if in range.

#### Scenario: Unit moves toward target
- **WHEN** target is out of range and MC is idle
- **THEN** CombatComponent SHALL compute a stop position at `weapon.attack_range * CELL_SIZE` distance from the target, at the angle from the target to the unit (atan2), and call `mc.set_target_position(stop_pos)`

#### Scenario: Multiple units spread around target
- **WHEN** 3 units attack the same target from different angles
- **THEN** each unit SHALL compute a unique stop position at its own angle from the target, spreading naturally around the target perimeter

#### Scenario: Unit already moving
- **WHEN** MC is already moving (`is_moving() == true`)
- **THEN** CombatComponent SHALL NOT issue another move command

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
