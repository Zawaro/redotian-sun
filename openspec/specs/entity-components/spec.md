## MODIFIED Requirements

### Requirement: Components declare order targeters
Each component that can issue player-initiated orders SHALL implement `get_order_for_target(target: Node3D, target_cell: Vector2i, target_pos: Vector3, modifiers: Dictionary) -> OrderResult`. The method SHALL return null if the component cannot act on the given target. Components without this method SHALL be silently skipped during order resolution.

#### Scenario: Component with no targeter
- **WHEN** a component does not implement `get_order_for_target()`
- **THEN** OrderResolver SHALL skip it without error

#### Scenario: Component returns null
- **WHEN** `get_order_for_target()` returns null
- **THEN** OrderResolver SHALL skip it and try other components

#### Scenario: Component returns OrderResult
- **WHEN** `get_order_for_target()` returns a non-null OrderResult
- **THEN** OrderResolver SHALL consider it for priority comparison

## ADDED Requirements

### Requirement: CombatComponent fires weapons at targets
CombatComponent SHALL implement a `_physics_process(delta)` loop that: (1) validates target, (2) checks range, (3) issues move if out of range, (4) fires hitscan damage when in range and cooldown elapsed.

#### Scenario: Full engagement cycle
- **WHEN** an attack order is issued on a valid enemy target
- **THEN** CombatComponent SHALL move toward target if out of range, fire when in range, and continue firing on cooldown until target dies or is cleared

#### Scenario: No-op when no target
- **WHEN** `_target` is null
- **THEN** `_physics_process` SHALL do nothing (no errors, no moves, no fires)

### Requirement: CombatComponent exposes weapon_fired signal
CombatComponent SHALL declare `signal weapon_fired(weapon: WeaponData, target: Node3D)` that emits after each hitscan damage application.

#### Scenario: Signal wiring
- **WHEN** any node connects to `weapon_fired`
- **THEN** the signal SHALL fire with the WeaponData and target Node3D on each shot
