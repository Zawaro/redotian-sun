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
