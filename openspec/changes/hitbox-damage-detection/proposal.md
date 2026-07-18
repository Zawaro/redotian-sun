## Why

HitboxComponent creates a collision shape but detects nothing. A hitbox that no projectile can hit is decorative. The combat loop (weapon → projectile → hitbox → health) has no entry point — damage can't reach HealthComponent from the physics layer. This blocks all combat interactions (issue #29).

## What Changes

- HitboxComponent connects `area_entered`/`body_entered` signals and forwards damage to HealthComponent via a `get_damage_info()` protocol
- HealthComponent `take_damage()` gains a `damage_type: String` parameter for future armor calculation
- Collision layer constants defined on HitboxComponent (ground, air, building hitboxes + projectile layer)
- EntityFactory sets collision layer/mask per entity type on hitbox instantiation

## Capabilities

### New Capabilities

_None — this extends existing component behavior._

### Modified Capabilities

- `entity-components`: HitboxComponent requirements expand from size-only to include damage detection and forwarding. HealthComponent `take_damage()` signature gains `damage_type`.

## Impact

- **Files modified**: `scripts/components/HitboxComponent.gd`, `scripts/components/HealthComponent.gd`, `scripts/entities/EntityFactory.gd`
- **Scenes**: `scenes/components/HitboxComponent.tscn` (unchanged — already an Area3D with CollisionShape3D)
- **Backward compatible**: `take_damage(damage, damage_type="")` — existing callers (MapEditor, ResourceComponent) unaffected
- **Depends on**: #22 (Entity System), #24 (HealthComponent — `take_damage` signature)
- **Blocks**: All combat interactions, projectile system implementation
