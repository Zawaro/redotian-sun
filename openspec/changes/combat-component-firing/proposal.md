## Why

CombatComponent is a data container with zero combat logic. It stores weapons, turret info, and threat, but `_attack()` is an empty stub. Additionally, no entity .tres file in the codebase references any weapon — the 44 weapon .tres files exist but aren't wired to entities. This means EntityFactory never creates a CombatComponent, and no unit can fight. This blocks the First Blood milestone (issue #84).

## What Changes

- Add weapon references to infantry .tres files so EntityFactory creates CombatComponent
- Implement firing logic in CombatComponent: fire rate timer, range checking, hitscan damage application
- Add `is_moving()` getter to MovementController for combat-movement coordination
- Add `weapon_fired` signal for future projectile system integration

## Capabilities

### New Capabilities
- `combat-firing`: CombatComponent target tracking, range checking, cooldown timers, and hitscan damage application

### Modified Capabilities
- `entity-components`: CombatComponent gains `_physics_process` loop, target state, and `weapon_fired` signal
- `entity-data`: Infantry .tres files gain weapon references (weapons array populated)

## Impact

- `scripts/components/CombatComponent.gd` — core firing logic
- `scripts/components/MovementController.gd` — add `is_moving()` getter
- `resources/entities/infantry/gdi_light_infantry.tres` — add weapons
- `resources/entities/infantry/nod_light_infantry.tres` — add weapons
- `test/unit/test_combat_component.gd` — firing logic tests
